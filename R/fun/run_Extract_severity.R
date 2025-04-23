# Description -------------------------------------------------------------
## Function for extracting severity indices to tables for AOI input
## Needed data:
## 1. AOI name, e.g. "GIF14_Au"
## 2. spatVector of fire perimeters
## 3. spatVector of fire runs
## 4. spatRaster of severity indices (can be stacked)
## 5. data.frame of wind table
##
## ! Turn `quiet = on` to mute the progress output !
# -------------------------------------------------------------------------
source("R/fun/wind_Oper_Function.R", echo = FALSE)
source("R/fun/Data_Function.R", echo = FALSE)
run_Extract_severity <- function(aoi_Name, fire_Perimeters, run_Polygons, 
                                 raster_Indices, env_Indices, wind_Table, quiet = F){
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
    
    Peri_i <- fire_Perimeters %>% filter(OBJECTID == objID)
    if (expanse(Peri_i)/10000 < 1){ # Skip loop if perimeter polygon is smaller than 1 ha
      message(paste("!--- Skipping for low polygon area:", 
                    round(expanse(Peri_i)/10000, 3), "ha"))
      next
    }
    
    Run_i <- run_Polygons %>% filter(ID == objID)
    linePoints_i <- as.points(Run_i)
    
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
    # run_idcs, sampled_rest_area                               #
    #                                                           #
    #############################################################
    # 1. cropping raster by i_th perimeter
    i_ras_idcs <- terra::crop(raster_Indices, Peri_i, mask=TRUE)
    
    # 2. extract values to i_th fire run (clipped by perimeter)
    ##
    if (!quiet){message(cli::col_blue(" ----- Extracting indices for fire run"))}
    run_idcs <- terra::extract(i_ras_idcs, clp_Run,
                               touches = T, cells = T) %>% na.omit()
    env_onPath <- terra::extract(env_Indices, clp_Run, cells = T) %>% na.omit()
    env_onTip  <- terra::extract(env_Indices, linePoints_i, cells = T) %>% na.omit()
    
    # 3. use the cell numbers to remove raster values
    r = i_ras_idcs
    r[run_idcs$cell] <- NA
    
    
    # 4. random sample the pixels
    # Sample the valid cells in size of extracted cell counts
    valid_cells   <- which(!is.na(values(r[[1]])))
    if (length(valid_cells) <= length(run_idcs$cell)){
      # If cells for run indices not less than the rest
      # Use all left cells
      message("!----- Pixels left for sample no more than already used!")
      sample_cells  <- valid_cells
    }else{
      # Sample cells at the same size as run indices
      sample_cells  <- sample(valid_cells, size = length(run_idcs$cell), replace=FALSE)
    }
    ##
    if (!quiet){message(cli::col_blue(" ----- Extracting indices for the rest of AOI"))}
    sampled_rest_area <- terra::extract(r, sample_cells) %>% data.frame(cell = sample_cells)
    
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
                            speed    = Run_i$Distance/i_duration)
    
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
                      mutate(asp_match    = cos((Run_i$DirectionD - asp_mean) * pi / 180))
    
    env_Vars <- cbind(two_point_slop[,-(1:2)],
                      mean_path_env) %>% 
                  rename_with( ~ paste0("env_", .x))
    ########################
    
    ########################
    # Build extraction function for inside/outside fireruns
    pixel_summary <- function(dt){
      dt %>% 
        as_tibble() %>% 
        select(-any_of(c('ID', 'cell'))) %>% 
        summarise(across(
          everything(),
          list(
            Mean = mean,
            SE = se,
            minP10 = min_Mean_p10,
            maxP10 = max_Mean_p10
          ),
          .names = "{.col}_{.fn}"
        ))
    }
    
    # Stats for run extract
    if (!quiet){message(cli::col_blue(" ----- Combining stats table"))}
    i_run_idcs <- pixel_summary(run_idcs)
    
    # Stats for other area extract
    i_OUTOF_run_idcs <- pixel_summary(sampled_rest_area)
    ########################

    
    # Combine stats of indices array together
    i_run_idcs       <- cbind(fire_Vars, env_Vars, i_run_idcs) %>% as_tibble()
    i_OUTOF_run_idcs <- cbind(fire_Vars, env_Vars, i_OUTOF_run_idcs) %>% as_tibble()
    
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
  
