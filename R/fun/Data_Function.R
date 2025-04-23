# Description -------------------------------------------------------------
## Functions utilizing `FireRuns` to process project files
## Considering the folder structure created by `EnvSetup.R`
# -------------------------------------------------------------------------

# Fire run Functions ---------------------------------------------------------------
list_fireRuns <- function(){
  lst <- list.dirs(file.path(root_folder, run_DataDir),
            full.names = FALSE, recursive = FALSE)
  for (name in lst) {
    print(name)
  }
}

fetch_firePeri <- function(AreaName){
  # Get fire fronts shp file
  path <- file.path(root_folder, run_DataDir, AreaName)
  shpIn <- fs::dir_ls(file.path(path, "input"), glob = "*.shp")
  if (length(shpIn) != 1){
    stop(paste0("No input shp or having more than 1 shp in input folder!\n  Get shp:\n", paste(shpIn, collapse = "\n")))
  }
  vFireIn <- vect(shpIn)
  message(paste0("Fetch fire propagation data:\n  ./data/input/", AreaName, "/", basename(shpIn)))
  return(vFireIn)
}

fetch_fireRun <- function(AreaName, RunType = "Pol"){
  if (!RunType %in% c("Pol", "Wind", "FullPol", "FullWind")){
    stop("Select correct RunType! (Pol, Wind, FullPol, FullWind)")
  }
  
  # Find
  setwd(file.path(root_folder, run_DataDir, AreaName))
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
  } else if (RunType == "FullPol"){
    # Run FireRun Algorithm with Wind data
    if (!file.exists("outputs/FullRunsPol.shp")) {
      stop("Found no FullRunsPol.shp!\nRun area_process_allArrow() and try again!")
    } else {
      message("-- Found FullRunsPol.shp --")
      vRuns <- vect("outputs/FullRunsPol.shp")
    }
  } else if (RunType == "FullWind"){
    # Run FireRun Algorithm with Wind data
    if (!file.exists("outputs/FullRunsWind.shp")) {
      stop("Found no FullRunsWind.shp!\nRun area_process_allArrow() and try again!")
    } else {
      message("-- Found FullRunsWind.shp --")
      vRuns <- vect("outputs/FullRunsWind.shp")
    } 
  } else {
    stop("Input `RunType` error!")
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
    geom_spatvector(data = vrun %>% 
                      filter(Distance != 0), 
                    color = "blue", linewidth = 1,
                    arrow = arrow(angle = 45,
                                  ends = "last",
                                  type = "open",
                                  length = unit(0.2, "cm")))
  
  return(PolRun)
}

clear_Sharedfronline <- function(){
  root_length <- length(strsplit(root_folder, "/")[[1]])
  rel_fld_name <- strsplit(getwd(), "/")[[1]]
  rel_fld_name <- paste(rel_fld_name[root_length:length(rel_fld_name)], collapse = "/")
  
  # Clean SharedFrontLines file
  f_frontline <- fs::dir_ls(glob = "*SharedFrontLines.*")
  if (length(f_frontline) > 0) {
    message("Searching SharedFrontLines......")
    message(paste0("(Folder: ", rel_fld_name, ")"))
    message("-- Deleting SharedFrontLines")
    file.remove(f_frontline)
  }
  rm(f_frontline)
}

area_process <- function(AreaName,  nameID_i = "OBJECTID", nameFeho_i = "FeHo", do_plot = F){
  setwd(file.path(root_folder, run_DataDir, AreaName))
  # Fetch Fire Propagation polygons
  vFireIn <- fetch_firePeri(AreaName)
  
  # Run FireRun Algorithm for Polygon only
  if (!file.exists("outputs/RunsPol.shp")) {
    message("-- Producing RunsPol.shp:")
    # Clean SharedFrontLines file
    clear_Sharedfronline()
    Runs(vFireIn, nameID = nameID_i, nameFeho = nameFeho_i, CreateSharedFrontLines = T)
  } else {
    message("-- Found RunsPol.shp --")
  }
  
  # Run FireRun Algorithm with Wind data
  if (!file.exists("outputs/RunsWind.shp")) {
    message("-- Producing RunsWind.shp:")
    WTabHr <- read.csv("./input/TesaureWind.csv", header = T)
    if (!"codi_hora" %in% names(WTabHr)) {stop("Read csv error!\n  Check read option and sep args.")}
    # Clean SharedFrontLines file
    clear_Sharedfronline()
    Runs(vFireIn, nameID = nameID_i, nameFeho = nameFeho_i, WindTablexHour=WTabHr,
         flagRuns='wind' , CreateSharedFrontLines = T)
  } else {
    message("-- Found RunsWind.shp --")
  }
  
  
  if (do_plot){
    # Plot Runs with Fire Fronts map
    vRunsPol <- vect("outputs/RunsPol.shp")
    vRunsWind <- vect("outputs/RunsWind.shp")
    message("-- Plot Fire Runs --")
    PolRun  <- plot_FireRun(vFireIn, vRunsPol, nameFeho_i)
    WindRun <- plot_FireRun(vFireIn, vRunsWind, nameFeho_i)
    
    p_all <- ggarrange(PolRun, WindRun,
                       labels = c("Pol", "Wind"),
                       ncol = 1, nrow = 2, common.legend = TRUE, legend = "right")
    
    plot(p_all)
  }
  
  # Back to root folder
  setwd(root_folder)
}

area_process_allArrow <- function(AreaName,  nameID_i = "OBJECTID", nameFeho_i = "FeHo", do_plot = F){
  setwd(file.path(root_folder, run_DataDir, AreaName))
  # Fetch Fire Propagation polygons
  vFireIn <- fetch_firePeri(AreaName)
  
  # Run FireRun Algorithm for Polygon only
  if (!file.exists("outputs/FullRunsPol.shp")) {
    message("-- Producing FullRunsPol.shp:")
    # Clean SharedFrontLines file
    clear_Sharedfronline()
    Runs2(vFireIn, nameID = nameID_i, nameFeho = nameFeho_i, CreateSharedFrontLines = T)
  } else {
    message("-- Found FullRunsPol.shp --")
  }
  
  
  # Run FireRun Algorithm with Wind data
  if (!file.exists("outputs/FullRunsWind.shp")) {
    message("-- Producing FullRunsWind.shp:")
    WTabHr <- read.csv("./input/TesaureWind.csv", header = T)
    if (!"codi_hora" %in% names(WTabHr)) {stop("Read csv error!\n  Check read option and sep args.")}
    # Clean SharedFrontLines file
    clear_Sharedfronline()
    Runs2(vFireIn, nameID = nameID_i, nameFeho = nameFeho_i, WindTablexHour=WTabHr,
         flagRuns='wind' , CreateSharedFrontLines = T)
  } else {
    message("-- Found FullRunsWind.shp --")
  }
  
  
  if (do_plot){
    # Plot Runs with Fire Fronts map
    vRunsPol <- vect("outputs/FullRunsPol.shp")
    vRunsWind <- vect("outputs/FullRunsWind.shp")
    message("-- Plot Fire Runs --")
    PolRun  <- plot_FireRun(vFireIn, vRunsPol, nameFeho_i)
    WindRun <- plot_FireRun(vFireIn, vRunsWind, nameFeho_i)
    
    p_all <- ggarrange(PolRun, WindRun,
                       labels = c("Pol", "Wind"),
                       ncol = 1, nrow = 2, common.legend = TRUE, legend = "right")
    
    plot(p_all)
  }
  # Back to root folder
  setwd(root_folder)
}

wind_csv_Check <- function(AreaName, to_save = F){
  setwd(file.path(root_folder, run_DataDir, AreaName))
  csv_i <- fs::dir_ls("./input", glob = "*.csv")
  if (file.exists("input/TesaureWind.csv")){
    WTabHr <- read.csv("input/TesaureWind.csv", header = T)
    message("Wind data get:")
    print(WTabHr)
    if(WTabHr[['codi_hora']][1] != 1) {
      message("!-- codi_hora modified --!")
      WTabHr[['codi_hora']] = WTabHr[['codi_hora']] - 1
    }
    
  } else {
    setwd(root_folder)
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


# Stats functions ---------------------------------------------------------

mode_fn <- function(x) {
  ux <- unique(x)
  return(ux[which.max(tabulate(match(x, ux)))])
}

se <- function(x){
  sd(x, na.rm = TRUE) / sqrt(length(na.omit(x)))
}

idcs_longer <- function(df){
  df %>% 
    pivot_longer(starts_with(c("M_", "Cl_")),
                 # names_to      = c("timeCollapse", "idcs"),
                 # names_pattern = "([^_]*)_(.*)",
                 names_to      = c("timeCollapse", "idcs", "idStats"),
                 names_sep = "_",
                 values_to     = "severity") %>% 
    mutate(timeCollapse = case_match(timeCollapse,
                                     "Cl"~ "Mosaic",
                                     "M" ~ "StackMean",
                                     .default = timeCollapse))
}

max_Mean_p10 <- function(x){
  # Number of top 10% elements (at least one)
  n_top <- max(1, floor(0.10 * length(x)))
  
  # Get average of the top 10%
  return(mean(sort(x, decreasing = TRUE)[1:n_top]))
}

min_Mean_p10 <- function(x){
  # Number of top 10% elements (at least one)
  n_top <- max(1, floor(0.10 * length(x)))
  
  # Get average of the top 10%
  return(mean(sort(x, decreasing = FALSE)[1:n_top]))
}

normal_range <- function(df, col){
  c(mean(df[,col]) - 5 * sd(df[,col]),
    mean(df[,col]) + 5 * sd(df[,col]))
}
