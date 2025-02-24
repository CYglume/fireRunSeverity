# ------------------------------------------------------------------------------
# Description: analysis of fire severity with fire runs (main task)
# 
# Input: idcs_DataDir <- r"(data/GEE)"
# ------------------------------------------------------------------------------
source("R/EnvSetup.R", echo = TRUE)
source("R/fun/run_Extract_severity.R")
if (file.exists(file.path(stats_DataDir, "sevExtract.RData"))){
  load(file.path(stats_DataDir, "sevExtract.RData"))
}

AreaList <- basename(list.dirs(file.path(run_DataDir), recursive = F))
buffer_m <- 100 #meter

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
  for (i in ids_lst){
    i_sub <- strsplit(i, "--")[[1]][1]
    ids = rbind(ids, data.frame(name = i_sub, loc = paste0(aoi_idcs, "/", i)))
  }
  message(cli::col_blue(" -- get Indices list"))
  print(ids)
  message(cli::col_blue(" -------------------"))
  
  
  ## Load raster data and stack rasters together
  if (exists("ras_idcs")){rm(ras_idcs)}
  for (i in 1:nrow(ids)){
    ras <- rast(ids$loc[i])
    if (!exists("ras_idcs")){
      ras_idcs <- rast(ids$loc[i])
    }else{
      ras_idcs <- c(ras_idcs, rast(ids$loc[i]))
    }
  }
  
  
  # Get vector FireRuns -----------------------------------------------------
  vect_Run <- fetch_fireRun(AreaName, "FullWind")
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
  
  runs_buffer <- buffer(vect_Run, width=buffer_m)
  
  message(cli::col_blue(" -- Running Indices Extraction..."))
  tp_StatsLst <- run_Extract_severity(aoi_Name        = AreaName,
                                      fire_Perimeters = vect_Peri, 
                                      run_Polygons    = runs_buffer, 
                                      raster_Indices  = ras_idcs, 
                                      wind_Table      = windTbl)
  
  if (!exists("all_StatsLst")){
    all_StatsLst = tp_StatsLst
  }else{
    all_StatsLst$Run <- rbind(all_StatsLst$Run, tp_StatsLst$Run)
    all_StatsLst$OutRun <- rbind(all_StatsLst$OutRun, tp_StatsLst$OutRun)
  }
  message(paste("Finished table combination"))
  message(paste("----------------------------------------------"))
}
save(all_StatsLst, file = file.path(stats_DataDir, "sevExtract.RData"))

