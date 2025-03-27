# ------------------------------------------------------------------------------
# Description: analysis of fire severity with fire runs 
# 1. Extract the pixel values to fire runs for further analysis
# 2. Fireruns: FullPol & FullWind (2 different scenarios)
# 3. Severity indices: dNBR, RBR, RdNBR
#
# Input : idcs_DataDir <- r"(data/GEE)"
# Output: all_StatsLst
# ------------------------------------------------------------------------------
source("R/EnvSetup.R", echo = TRUE)
source("R/fun/run_Extract_severity.R")
if (file.exists(file.path(stats_DataDir, "sevExtract.RData"))){
  load(file.path(stats_DataDir, "sevExtract.RData"))
}

AreaList <- basename(list.dirs(file.path(run_DataDir), recursive = F))

if (exists("all_StatsLst")){rm(all_StatsLst)}
for (AreaName in AreaList) {
  message(paste("\n----------------------------------------------"))
  message(paste("Processing AOI:", AreaName))
  dt_fld <- file.path(root_folder, run_DataDir, AreaName, "input")
  
  # Get raster indices ------------------------------------------------------
  # aoi_idcs <- paste(idcs_DataDir, AreaName, "old", sep = "/")
  aoi_idcs <- paste(idcs_DataDir, AreaName, sep = "/")
  ids_lst <- list.files(aoi_idcs, pattern = ".tif$")
  if(length(ids_lst) == 0){
    message(paste("\nNo severity map found in folder:", aoi_idcs, "!!"))
    message(paste("\n----------------------------------------------"))
    next
  }
  
  ids = data.frame()
  env_ids = data.frame()
  for (i in ids_lst){
    i_sub <- strsplit(i, "--")[[1]][1]
    if (strsplit(i_sub, "_")[[1]][2] == "env"){
      env_ids = rbind(env_ids,
                      data.frame(name = i_sub, 
                                 loc = paste0(aoi_idcs, "/", i)))
    }else{
      ids     = rbind(ids, 
                      data.frame(name = i_sub, 
                                 loc = paste0(aoi_idcs, "/", i)))
    }
  }
  message(cli::col_blue(" -- get Indices list"))
  print(ids)
  print(env_ids)
  message(cli::col_blue(" -------------------"))
  
  
  ## Load raster data and stack rasters together
  if (exists("ras_idcs")){rm(ras_idcs)}
  if (exists("ras_env_idcs")){rm(ras_env_idcs)}
  for (i in 1:nrow(ids)){
    if (!exists("ras_idcs")){
      ras_idcs <- rast(ids$loc[i])
    }else{
      ras_idcs <- c(ras_idcs, rast(ids$loc[i]))
    }
  }
  
  for (i in 1:nrow(env_ids)){
    if (!exists("ras_env_idcs")){
      ras_env_idcs <- rast(env_ids$loc[i])
    }else{
      ras_env_idcs <- c(ras_env_idcs, rast(env_ids$loc[i]))
    }
  }
  

# -------------------------------------------------------------------------
# Prepare fire runs for indices extraction 
  for (runType in c("FullWind", "FullPol")){
    message(cli::col_blue(paste0(" -- Extraction for FireRuns type: ", runType)))
    # Get vector FireRuns -----------------------------------------------------
    vect_Run <- fetch_fireRun(AreaName, runType)
    vect_Peri <- fetch_firePeri(AreaName)
    windTbl  <- read.csv(file.path(dt_fld, "TesaureWind.csv"), header = T)
    
    # Filter out zero length fire runs
    vect_Run <- vect_Run %>%
      filter(Distance > 0) %>% 
      left_join(vect_Peri %>% select(OBJECTID, FeHo) %>% as_tibble(),
                by = join_by(ID == OBJECTID))
    
    # Re-project fire runs and perimeter vectors to crs of raster indices (EPSG:4326)
    vect_Run  <- project(vect_Run, crs(ras_idcs))
    vect_Peri <- project(vect_Peri, crs(ras_idcs))
    
    
    message(cli::col_blue(" -- Running Indices Extraction..."))
    tp_StatsLst <- run_Extract_severity(aoi_Name        = AreaName,
                                        fire_Perimeters = vect_Peri,
                                        run_Polygons    = vect_Run,
                                        raster_Indices  = ras_idcs,
                                        env_Indices     = ras_env_idcs,
                                        wind_Table      = windTbl)

    # Add run type flag to the data table
    tp_StatsLst$Run$runType = runType
    tp_StatsLst$OutRun$runType = runType
    
    if (!exists("all_StatsLst")){
      all_StatsLst = tp_StatsLst
    }else{
      all_StatsLst$Run <- rbind(all_StatsLst$Run, tp_StatsLst$Run)
      all_StatsLst$OutRun <- rbind(all_StatsLst$OutRun, tp_StatsLst$OutRun)
    }
  }
  message(paste("Finished table combination"))
  message(paste("----------------------------------------------"))
}
save(all_StatsLst, file = file.path(stats_DataDir, "sevExtract.RData"))

