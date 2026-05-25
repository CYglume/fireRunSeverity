# Description -------------------------------------------------------------
## Function for extracting severity indices to tables for AOI input
## Needed data:
## 1. AOI name, e.g. "GIF14_Au"
## 2. spatVector of fire perimeters
## 3. spatVector of fire runs
## 4. spatRaster of severity indices (can be stacked)
## 5. data.frame of wind table
## 6. data.frame of vpd table
## 5. spatRaster of land cover type map
##
## ! Turn `quiet = on` to mute the progress output !
# -------------------------------------------------------------------------
source("R/fun/wind_Oper_Function.R", echo = FALSE)
source("R/fun/Data_Function.R", echo = FALSE)
run_Extract_severity_Peri <- function(aoi_Name, fire_Perimeters, run_Polygons, 
                                 raster_Indices, env_Indices, spei_Indices,
                                 wind_Table,  vpd_Table, land_CV, quiet = F){
  #Pre-set variables
  buffer_width = 30 #meter
  
  # Get list of valid OBJECTID with runs
  periIDLst <- run_Polygons$ID
  for (objID in periIDLst){
    if (!quiet){
      message("------------------------")
      message(paste(" --- OBJECTID:", objID))
    }
    
    # -------------------------------------------------------------------------
    ###########################################################
    # Modify vectors for extraction:                          #
    # 1. get fire perimeters by ID                            #
    # 2. get buffered runs by ID -> crop by fire perimeters   #
    # Output:                                                 #
    # Run_i, Peri_i, linePoints_i                             #
    ###########################################################
    
    Peri_i <- fire_Perimeters %>% filter(OBJECTID == objID)
    if (expanse(Peri_i)/10000 < 1){ # Skip loop if perimeter polygon is smaller than 1 ha
      message(paste("!--- Skipping for low polygon area:", 
                    round(expanse(Peri_i)/10000, 3), "ha"))
      next
    }
    
    Run_i <- run_Polygons %>% filter(ID == objID)
    linePoints_i <- as.points(Run_i)
    
    # Check where the run is
    run_crd <- project(Run_i, "epsg:4326") %>% crds()
    if(sum(run_crd[,2] >= 0) == 2){
      # The run is on north hemisphere (equator on south)
      equa_ref = 180
    }else if(sum(run_crd[,2] <= 0) == 2){
      # The run is on south hemisphere (equator on north)
      equa_ref = 0
    }else{
      # The run is across the equator
      equa_ref = NA
    }
    
    # Buffer runs for pixel extraction
    Run_i        <- buffer(Run_i, buffer_width) #Set up buffer as pre-set value
    linePoints_i <- buffer(linePoints_i, buffer_width+5) # to avoid makeing path run multipart
    
    if (!quiet){message(paste(" --- Hour:", Run_i$Hour))}
    # -------------------------------------------------------------------------  
    #############################################################
    # Extract Rasters for calculation:                          #
    # 1. extract values to linePoints_i                         #
    # 1. extract values to Peri_i                               #
    #                                                           #
    # Output:                                                   #
    # env_onTip, peri_idcs, env_onPeri, landcv_onPeri           #
    #                                                           #
    #############################################################
    # 1. Extract directoinal value
    env_onTip  <- terra::extract(env_Indices, linePoints_i, cells = T) %>% na.omit()
    
    # 2. extract all for whole perimeters
    ##
    if (!quiet){message(cli::col_blue(" ----- Extracting indices for fire perimeters"))}
    peri_idcs <- terra::extract(raster_Indices, Peri_i,
                               touches = T, cells = T) %>% na.omit()
    peri_spei <- terra::extract(spei_Indices, Peri_i,
                               touches = T, cells = T) %>% na.omit()
    env_onPeri <- terra::extract(env_Indices, Peri_i, cells = T) %>% na.omit()
    
    message(cli::col_blue(" ------- Land Cover"))
    landcv_onPeri <- terra::extract(land_CV, Peri_i, cells = T) %>% 
      select(ID, lccs_class, cell) %>% na.omit()
    # -------------------------------------------------------------------------  
    #################################################################
    # Calculate statistics as table:                                #
    # 1. statistics: Mean, Sd                                       #
    # 2. calculate run speed by FeHo -> duration, distance -> speed #
    # 3. make table list (peri, null) and store as list()           #
    # Output:                                                       #
    # RUN_idcs (Peri ver.), OUTOF_RUN_idcs (Null)                   #
    #                                                               #
    #################################################################
    
    # Calculate Duration
    if(Run_i$Hour == 1){
      i_duration <- 2*60*60
    }else{
      i_time     <- Run_i$FeHo %>% as.POSIXct(format = "%Y/%m/%d_%H%M")
      i_pre_time <- wind_Table$FeHo_W[wind_Table$codi_hora == Run_i$Hour - 1] %>% as.POSIXct(format = "%Y/%m/%d_%H%M")
      i_duration = as.numeric(difftime(i_time, i_pre_time, units = "secs"))
    }
    # collect input fire information
    fire_Vars <- data.frame(fire     = aoi_Name,
                            OBJECTID = objID,
                            FeHo     = Run_i$FeHo,
                            Dur      = i_duration,
                            Dir      = Run_i$DirectionD,
                            speed    = Run_i$Distance/i_duration,
                            wind_Dir = wind_Table$Wind[wind_Table$codi_hora == Run_i$Hour],
                            wind_spd = wind_Table$wind_speed[wind_Table$codi_hora == Run_i$Hour],
                            vpd_kPa  = vpd_Table$VPD_kPa[vpd_Table$codi_hora == Run_i$Hour],
                            tp       = vpd_Table$tp[vpd_Table$codi_hora == Run_i$Hour])
    
    ########################
    # Stats for environmental factors
    # 1. two point slop 2. mean aspect on path 3. mean path elevation  
    two_point_slop <- env_onTip %>% group_by(ID) %>% 
      summarise(mean_elev = mean(env_elevation)) %>% 
      pivot_wider(names_from = ID,
                  names_prefix = "P",
                  values_from = mean_elev) %>% 
      mutate(elev_drop      = P2 - P1,
             elev_slope     = elev_drop/Run_i$Distance)
    mean_Peri_env <- env_onPeri %>% 
      summarise(asp_mean  = dirAngle_mean(env_aspect),
                elev_mean = mean(env_elevation)) %>% 
      mutate(asp_match    = cos((Run_i$DirectionD - asp_mean) * pi / 180),
             asp_face_equa = ifelse(is.na(equa_ref), 0, cos((equa_ref - asp_mean) * pi / 180)))
    
    env_Vars <- cbind(two_point_slop[,-(1:2)],
                      mean_Peri_env) %>% 
      rename_with( ~ paste0("env_", .x))
    ########################
    
    ########################
    # Stats for run extract
    if (!quiet){message(cli::col_blue(" ----- Combining stats table"))}
    i_run_idcs <- pixel_summary(peri_idcs)
    i_run_spei <- pixel_summary(peri_spei)
    
    # Stats for Perimeter extract
    i_peri_landcv <- fct_pixel_summary(landcv_onPeri)
    ########################
    
    
    # Combine stats of indices array together
    i_run_idcs       <- cbind(fire_Vars, env_Vars, i_run_spei, i_peri_landcv, i_run_idcs) %>% as_tibble()
    
    # for pixels under fire run
    if(!exists("RUN_idcs")){
      RUN_idcs <- i_run_idcs
    }else{
      RUN_idcs <- rbind(RUN_idcs, i_run_idcs) 
    }
  }
  
  gc()
  return(list(Run = RUN_idcs, OutRun = NULL))
} 