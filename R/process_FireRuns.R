# ------------------------------------------------------------------------------
# Try to run FireRun on sample data
# 
# Input: data/FirstWildfires/
rm(list = ls())
root_folder <- rprojroot::find_rstudio_root_file()
dataDir <- r"(data\FirstWildfires)"
source(file.path(root_folder, "R/EnvSetup.R"), echo = TRUE)


area_process("GIF14_Au")
area_process("LaJonquera", nameID = "ObjectID")
area_process("LC1", nameID = "ObjectID")


area_process("StLlorenc", nameFeho_i = "FeHo_2")


fetch_firePeri("GIF14_Au")
fetch_fireRun("LC1", "Wind")

p    <- fetch_firePeri("LC1")
pRun <- fetch_fireRun("LC1", "Wind")
plot_FireRun(p, pRun)







#------ CSV 
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

wind_csv_Check("GIF14_Au", to_save = F)
wind_csv_Check("LaJonquera", to_save = F)
wind_csv_Check("LC1", to_save = F)
wind_csv_Check("StLlorenc", to_save = F)





