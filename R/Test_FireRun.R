# ------------------------------------------------------------------------------
# Try to run FireRun on sample data
# 
# Input: data/FirstWildfires/
rm(list = ls())
root_folder <- rprojroot::find_rstudio_root_file()
dataDir <- r"(data\FirstWildfires)"
source(file.path(root_folder, "R/EnvSetup.R"), echo = TRUE)

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
  # Get fire fronts shp file
  setwd(file.path(root_folder, dataDir, AreaName))
  shpIn <- fs::dir_ls("./input", glob = "*.shp")
  vFireIn <- vect(shpIn)
  
  
  
  # Run FireRun Algorithm for Polygon only
  if (!file.exists("outputs/RunsPol.shp")) {
    Runs(vFireIn, nameID = nameID_i, nameFeho = nameFeho_i, CreateSharedFrontLines = T)
  }
  vRunsPol <- vect("outputs/RunsPol.shp")
  
  # Run FireRun Algorithm with Wind data
  if (!file.exists("outputs/RunsWind.shp")) {
    WTabHr <- read.csv2("./input/TesaureWind.csv", header = T, dec = ".")
    Runs(vFireIn, nameID = nameID_i, nameFeho = nameFeho_i, WindTablexHour=WTabHr,
         flagRuns='wind' , CreateSharedFrontLines = T)
  }
  vRunsWind <- vect("outputs/RunsWind.shp")
  
  
  # Plot Runs with Fire Fronts map
  PolRun  <- plot_FireRun(vFireIn, vRunsPol, nameFeho_i)
  WindRun <- plot_FireRun(vFireIn, vRunsWind, nameFeho_i)
  
  # WindRun <- ggplot() +
  #   geom_spatvector(aes(fill = OBJECTID), vFireIn)+
  #   scale_fill_gradientn(colours = c("lightyellow","yellow","red"))+
  #   geom_spatvector(data = vRuns, color = "blue", linewidth = 1,
  #                   arrow = arrow(angle = 45,
  #                                 ends = "last",
  #                                 type = "open",
  #                                 length = unit(0.2, "cm")))
  
  p_all <- ggarrange(PolRun, WindRun,
            labels = c("Pol", "Wind"),
            ncol = 1, nrow = 2, common.legend = TRUE, legend = "right")
  
  plot(p_all)
  # Back to root folder
  setwd(root_folder)
}

area_process("GIF14_Au")
area_process("LaJonquera", nameID = "ObjectID")
area_process("LC1", nameID = "ObjectID")

area_process("StLlorenc", nameFeho_i = "FeHo_2")





#--------------------------------------#
shp_na <- fs::dir_ls(file.path(dataDir, "GIF14_Au", "input"), glob = "*.shp")
a <- vect(shp_na)
plot(a, col = "#32CD32")
range(a$ACQ_DATE)


vFireIn <- vect(shpIn)
WTabHr <- read.csv2("input/TesaureWind.csv", header = T, dec = ".")

wind_csv_Check <- function(AreaName){
  setwd(file.path(root_folder, dataDir, AreaName))
  csv_i <- fs::dir_ls("./input", glob = "*.csv")
  if (length(csv_i) == 1){
    WTabHr <- read.csv2("input/TesaureWind.csv", header = T, dec = ".")
    # print(WTabHr)
    if(WTabHr[['codi_hora']][1] != 1) {
      print("!-- codi_hora modified --!")
      WTabHr[['codi_hora']] = WTabHr[['codi_hora']] - 1
      # write.csv2()
    }
    print(WTabHr)
  }
}

wind_csv_Check("LaJonquera")
wind_csv_Check("LC1")
wind_csv_Check("StLlorenc")


# v_GIF14_Au <- st_read(file.path(root_folder, "data/FirstWildfires/GIF14_Au"))
# crs(v_GIF14_Au)
# v2 <- Runs(v_GIF14_Au, nameID = "OBJECTID", nameFeho = "FeHo", CreateSharedFrontLines = F)

v2 <- vect(file.path(root_folder, "outputs/RunsPol.shp"))
# v2 <- st_read(file.path(root_folder, "outputs/RunsPol.shp"))
terra::plot(v_GIF14_Au[1:10])
par(new = T)
plot(v2)




