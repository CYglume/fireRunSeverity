# Description -------------------------------------------------------------
## Functions utilizing `FireRuns` to process project files
## Considering the folder structure created by `EnvSetup.R`
# -------------------------------------------------------------------------

# Functions ---------------------------------------------------------------
fetch_firePeri <- function(AreaName){
  # Get fire fronts shp file
  path <- file.path(root_folder, dataDir, AreaName)
  shpIn <- fs::dir_ls(file.path(path, "input"), glob = "*.shp")
  if (length(shpIn) != 1){
    stop(paste0("No input shp or having more than 1 shp in input folder!\n  Get shp:\n", paste(shpIn, collapse = "\n")))
  }
  vFireIn <- vect(shpIn)
  message(paste0("Fetch fire propagation data:\n  ./data/input", basename(shpIn)))
  return(vFireIn)
}

fetch_fireRun <- function(AreaName, RunType = "Pol"){
  if (!RunType %in% c("Pol", "Wind", "AllPol")){
    stop("Select correct RunType! (Pol, Wind, AllPol)")
  }
  
  # Find
  setwd(file.path(root_folder, dataDir, AreaName))
  if (RunType == "Pol"){
    # Run FireRun Algorithm for Polygon only
    if (!file.exists("outputs/RunsPol.shp")) {
      stop("Found no RunsPol.shp!\nRun area_process() and try again!")
    } else {
      message("-- Found RunsPol.shp --")
      vRuns <- vect("outputs/RunsPol.shp")
    }
  } else if (RunType == "Wind") {
    # Run FireRun Algorithm with Wind data
    if (!file.exists("outputs/RunsWind.shp")) {
      stop("Found no RunsWind.shp!\nRun area_process() and try again!")
    } else {
      message("-- Found RunsWind.shp --")
      vRuns <- vect("outputs/RunsWind.shp")
    }
  } else {
    stop("`AllPol` not supported  yet!")
  }
  setwd(root_folder)
  return(vRuns)
}

plot_FireRun <- function(vfire, vrun, nameFeho_i = "FeHo"){
  n_categories <- length(unique(vfire[[nameFeho_i]][[1]]))
  custom_colors <- colorRampPalette(c("lightyellow", "yellow", "red"))(n_categories)
  
  # Plot Runs with Fire Fronts map
  PolRun <- ggplot() +
    geom_spatvector(aes(fill = factor(.data[[nameFeho_i]])), vfire)+
    # scale_fill_brewer(palette = "OrRd")+
    scale_fill_manual(values = custom_colors)+
    geom_spatvector(data = vrun, color = "blue", linewidth = 1,
                    arrow = arrow(angle = 45,
                                  ends = "last",
                                  type = "open",
                                  length = unit(0.2, "cm")))
  
  return(PolRun)
}

area_process <- function(AreaName,  nameID_i = "OBJECTID", nameFeho_i = "FeHo"){
  setwd(file.path(root_folder, dataDir, AreaName))
  # Fetch Fire Propagation polygons
  vFireIn <- fetch_firePeri(AreaName)
  
  # Clean SharedFrontLines file
  f_frontline <- fs::dir_ls(glob = "*SharedFrontLines.*")
  if (length(f_frontline) > 0) {
    message("-- Deleting SharedFrontLines")
    for (i in f_frontline) {
      file.remove(f_frontline)
    }
  }
  rm(f_frontline)
  
  # Run FireRun Algorithm for Polygon only
  if (!file.exists("outputs/RunsPol.shp")) {
    message("-- Producing RunsPol.shp:")
    Runs(vFireIn, nameID = nameID_i, nameFeho = nameFeho_i, CreateSharedFrontLines = T)
  } else {
    message("-- Found RunsPol.shp --")
  }
  vRunsPol <- vect("outputs/RunsPol.shp")
  
  # Run FireRun Algorithm with Wind data
  if (!file.exists("outputs/RunsWind.shp")) {
    message("-- Producing RunsWind.shp:")
    WTabHr <- read.csv("./input/TesaureWind.csv", header = T)
    if (!"codi_hora" %in% names(WTabHr)) {stop("Read csv error!\n  Check read option and sep args.")}
    Runs(vFireIn, nameID = nameID_i, nameFeho = nameFeho_i, WindTablexHour=WTabHr,
         flagRuns='wind' , CreateSharedFrontLines = T)
  } else {
    message("-- Found RunsWind.shp --")
  }
  vRunsWind <- vect("outputs/RunsWind.shp")
  
  
  # Plot Runs with Fire Fronts map
  message("-- Plot Fire Runs --")
  PolRun  <- plot_FireRun(vFireIn, vRunsPol, nameFeho_i)
  WindRun <- plot_FireRun(vFireIn, vRunsWind, nameFeho_i)
  
  p_all <- ggarrange(PolRun, WindRun,
                     labels = c("Pol", "Wind"),
                     ncol = 1, nrow = 2, common.legend = TRUE, legend = "right")
  
  plot(p_all)
  # Back to root folder
  setwd(root_folder)
}

area_process_allArrow <- function(AreaName,  nameID_i = "OBJECTID", nameFeho_i = "FeHo"){
  setwd(file.path(root_folder, dataDir, AreaName))
  # Fetch Fire Propagation polygons
  vFireIn <- fetch_firePeri(AreaName)
  
  # Clean SharedFrontLines file
  f_frontline <- fs::dir_ls(glob = "*SharedFrontLines.*")
  if (length(f_frontline) > 0) {
    message("-- Deleting SharedFrontLines")
    for (i in f_frontline) {
      file.remove(f_frontline)
    }
  }
  rm(f_frontline)
  
  # Run FireRun Algorithm for Polygon only
  if (!file.exists("outputs/RunsPol.shp")) {
    message("-- Producing RunsPol.shp:")
    Runs2(vFireIn, nameID = nameID_i, nameFeho = nameFeho_i, CreateSharedFrontLines = T)
  } else {
    message("-- Found RunsPol.shp --")
  }
  vRunsPol <- vect("outputs/FullRunsPol.shp")
  
  # Run FireRun Algorithm with Wind data
  if (!file.exists("outputs/RunsWind.shp")) {
    message("-- Producing RunsWind.shp:")
    WTabHr <- read.csv("./input/TesaureWind.csv", header = T)
    if (!"codi_hora" %in% names(WTabHr)) {stop("Read csv error!\n  Check read option and sep args.")}
    Runs2(vFireIn, nameID = nameID_i, nameFeho = nameFeho_i, WindTablexHour=WTabHr,
         flagRuns='wind' , CreateSharedFrontLines = T)
  } else {
    message("-- Found RunsWind.shp --")
  }
  vRunsWind <- vect("outputs/FullRunsWind.shp")
  
  
  # Plot Runs with Fire Fronts map
  message("-- Plot Fire Runs --")
  PolRun  <- plot_FireRun(vFireIn, vRunsPol, nameFeho_i)
  WindRun <- plot_FireRun(vFireIn, vRunsWind, nameFeho_i)
  
  p_all <- ggarrange(PolRun, WindRun,
                     labels = c("Pol", "Wind"),
                     ncol = 1, nrow = 2, common.legend = TRUE, legend = "right")
  
  plot(p_all)
  # Back to root folder
  setwd(root_folder)
}

wind_csv_Check <- function(AreaName, to_save = F){
  setwd(file.path(root_folder, dataDir, AreaName))
  csv_i <- fs::dir_ls("./input", glob = "*.csv")
  if (file.exists("input/TesaureWind.csv")){
    WTabHr <- read.csv("input/TesaureWind.csv", header = T, sep = ";")
    message("Wind data get:")
    print(WTabHr)
    if(WTabHr[['codi_hora']][1] != 1) {
      message("!-- codi_hora modified --!")
      WTabHr[['codi_hora']] = WTabHr[['codi_hora']] - 1
    }
    
  } else {
    stop("Can't find input/TesaureWind.csv!\nFetch wind data and try again!")
  }
  
  if (to_save) {
    write.csv(WTabHr, 
              file = "input/TesaureWind.csv", 
              row.names = FALSE)
  }
  setwd(root_folder)
  return(WTabHr)
}