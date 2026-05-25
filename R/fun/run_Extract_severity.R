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
run_Extract_severity <- function(aoi_Name, fire_Perimeters, run_Polygons, 
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
    # Peri_i, clp_run                                         #
    ###########################################################
    
    # Get i-th perimeter
    Peri_i <- fire_Perimeters %>% filter(OBJECTID == objID)
    ### Check feature validity
    if (!is.valid(Peri_i)){
      Peri_i <- makeValid(Peri_i)
    }
    ### Check Polygon size
    if (expanse(Peri_i)/10000 < 1){ # Skip loop if perimeter polygon is smaller than 1 ha
      message(paste("!--- Skipping for low polygon area:", 
                    round(expanse(Peri_i)/10000, 3), "ha"))
      next
    }
    
    # Get i-th fire run
    Run_i <- run_Polygons %>% filter(ID == objID)
    ### Check feature validity
    if (!is.valid(Run_i)){
      Run_i <- makeValid(Run_i)
    }
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
    
    # Perform the clipping
    clp_Run <- terra::intersect(Run_i, Peri_i)
    # clp_Run_midPath <- terra::erase(clp_Run, linePoints_i)
    
    if(nrow(clp_Run) != 1){
      stop(paste("The run:", objID, "clipped results in multi-part geometry!"))
    }
    if (!quiet){message(paste(" --- Hour:", Run_i$Hour))}
    # -------------------------------------------------------------------------  
    #############################################################
    # Extract Rasters for calculation:                          #
    # 1. crop raster by Peri_i                                  #
    # 2. extract values to clp_Run**                            #
    # 3. delete pixels used                                     #
    # 4. random sample the rest pixels**                        #
    #    Make sure the sum of valid cells and extracted cells   #
    #    matches                                                #
    #    the cells cropped by perimeter                         #
    #     --> "length(valid_cells) + nrow(run_idcs)"            #
    #     --> equals to                                         #
    #     --> "length(which(!is.na(values(i_ras_idcs[[1]]))))"  #
    # Output:                                                   #
    # run_idcs, sampled_rest_area_Severity,                     #
    # sampled_rest_area_SPEI                                    #
    #                                                           #
    #############################################################
    # 1. cropping raster by i_th perimeter
    i_ras_idcs <- terra::crop(raster_Indices, Peri_i, mask=TRUE)
    i_spei     <- terra::crop(spei_Indices, Peri_i, mask=TRUE)
    
    # 2. extract values to i_th fire run (clipped by perimeter)
    ##
    if (!quiet){message(cli::col_blue(" ----- Extracting indices for fire run"))}
    run_idcs <- terra::extract(i_ras_idcs, clp_Run,
                               touches = T, cells = T) %>% na.omit()
    run_spei <- terra::extract(i_spei, clp_Run,
                               touches = T, cells = T) %>% na.omit()
    env_onPath <- terra::extract(env_Indices, clp_Run, cells = T) %>% na.omit()
    env_onTip  <- terra::extract(env_Indices, linePoints_i, cells = T) %>% na.omit()
    
    # 3. use the cell numbers to remove raster values
    r_sev = i_ras_idcs
    r_spei = i_spei
    r_sev[run_idcs$cell] <- NA
    r_spei[run_spei$cell] <- NA
    
    # 4. random sample the pixels
    # Sample the valid cells in size of extracted cell counts
    # Sample Severity
    message(cli::col_blue(" ----- Extracting for the rest of AOI"))
    message(cli::col_blue(" ------- Severity"))
    sampled_rest_area_Severity = sample_outRuns(ras_filtered = r_sev, 
                                                run_extract_tbl = run_idcs)
    ### Sample SPEI
    message(cli::col_blue(" ------- SPEI"))
    sampled_rest_area_SPEI     = sample_outRuns(ras_filtered = r_spei, 
                                                run_extract_tbl = run_spei)
    
    # 5. extract all for whole perimeters
    message(cli::col_blue(" ----- Extracting for whole perimeter"))
    message(cli::col_blue(" ------- Land Cover"))
    landcv_onPeri <- terra::extract(land_CV, Peri_i, cells = T) %>% 
      select(ID, lccs_class, cell) %>% na.omit()
    # -------------------------------------------------------------------------  
    #################################################################
    # Calculate statistics as table:                                #
    # 1. statistics: Mean, Sd, Mode, Median, Min, Max               #
    # 2. calculate run speed by FeHo -> duration, distance -> speed #
    # 3. make two tables (run, peri) and store as list()            #
    # Output:                                                       #
    # RUN_idcs, OUTOF_RUN_idcs                                      #
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
    mean_path_env <- env_onPath %>% 
                      summarise(asp_mean  = dirAngle_mean(env_aspect),
                                elev_mean = mean(env_elevation)) %>% 
                      mutate(asp_match    = cos((Run_i$DirectionD - asp_mean) * pi / 180),
                             asp_face_equa = ifelse(is.na(equa_ref), 0, cos((equa_ref - asp_mean) * pi / 180)))
    
    env_Vars <- cbind(two_point_slop[,-(1:2)],
                      mean_path_env) %>% 
                  rename_with( ~ paste0("env_", .x))
    ########################
    
    ########################
    # Stats for run extract
    if (!quiet){message(cli::col_blue(" ----- Combining stats table"))}
    i_run_idcs <- pixel_summary(run_idcs)
    i_run_spei <- pixel_summary(run_spei)
    
    # Stats for other area extract
    i_OUTOF_run_idcs <- pixel_summary(sampled_rest_area_Severity)
    i_OUTOF_run_SPEI <- pixel_summary(sampled_rest_area_SPEI)
    
    # Stats for Perimeter extract
    i_peri_landcv <- fct_pixel_summary(landcv_onPeri)
    ########################

    
    # Combine stats of indices array together
    i_run_idcs       <- cbind(fire_Vars, env_Vars, i_run_spei, i_peri_landcv, i_run_idcs) %>% as_tibble()
    i_OUTOF_run_idcs <- cbind(fire_Vars, env_Vars, i_OUTOF_run_SPEI, i_peri_landcv, i_OUTOF_run_idcs) %>% as_tibble()
    
    # for pixels under fire run
    if(!exists("RUN_idcs")){
      RUN_idcs <- i_run_idcs
    }else{
      RUN_idcs <- rbind(RUN_idcs, i_run_idcs) 
    }
    
    # for pixels out of fire run, but within perimeter
    if(!exists("OUTOF_RUN_idcs")){
      OUTOF_RUN_idcs <- i_OUTOF_run_idcs
    }else{
      OUTOF_RUN_idcs <- rbind(OUTOF_RUN_idcs, i_run_idcs) 
    }
  }
  
  gc()
  return(list(Run = RUN_idcs, OutRun = OUTOF_RUN_idcs))
}  
  

