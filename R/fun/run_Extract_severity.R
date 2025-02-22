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

run_Extract_severity <- function(aoi_Name, fire_Perimeters, run_Polygons, 
                                 raster_Indices, wind_Table, quiet = F){
  rm(RUN_idcs, OUTOF_RUN_idcs)
  
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
    Run_i <- run_Polygons %>% filter(ID == objID)
    
    # Perform the clipping
    clp_Run <- terra::intersect(Run_i, Peri_i)
    
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
                               na.rm=TRUE, touches = T, cells = T)
    
    
    # 3. use the cell numbers to remove raster values
    r = i_ras_idcs
    r[run_idcs$cell] <- NA
    
    
    # 4. random sample the pixels
    # Sample the valid cells in size of extracted cell counts
    valid_cells       <- which(!is.na(values(r[[1]])))
    sample_cells      <- sample(valid_cells, size=length(run_idcs$cell), replace=FALSE)
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
    
    # Stats for run extract
    if (!quiet){message(cli::col_blue(" ----- Combining stats table"))}
    i_run_idcs <- run_idcs %>% 
      as_tibble() %>% 
      select(!c(ID, cell)) %>% 
      summarise(across(
        everything(),
        list(
          Mean = mean,
          SE = se,
          Mode = mode_fn,
          Median = median,
          Min = min,
          Max = max
        ),
        .names = "{.col}_{.fn}"
      )) %>% 
      mutate(fire     = aoi_Name,
             OBJECTID = objID,
             FeHo     = Run_i$FeHo,
             Dur      = i_duration,
             speed    = Run_i$Distance/i_duration) %>% 
      select(last_col(4):last_col(), everything()) # Change the number if more variables need to be mutate()
    
    # Stats for other area extract
    i_OUTOF_run_idcs <- sampled_rest_area %>% as_tibble() %>% 
      select(!c(cell)) %>% 
      summarise(across(
        everything(),
        list(
          Mean = mean,
          SE = se,
          Mode = mode_fn,
          Median = median,
          Min = min,
          Max = max
        ),
        .names = "{.col}_{.fn}"
      )) %>% 
      mutate(fire     = aoi_Name,
             OBJECTID = objID,
             FeHo     = Run_i$FeHo,
             Dur      = i_duration,
             speed    = Run_i$Distance/i_duration) %>% 
      select(last_col(4):last_col(), everything()) # Change the number if more variables need to be mutate()
    
    
    # Combine stats of indices array together
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
  
