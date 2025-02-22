# ------------------------------------------------------------------------------
# Try to run FireRun on sample data
# 
# Input: data/FirstWildfires/
# ------------------------------------------------------------------------------
source("R/EnvSetup.R", echo = TRUE)
source("R/fun/Runs_AllArrows.R", echo = FALSE)

# area_process("GIF14_Au")
# area_process("LaJonquera", nameID = "ObjectID")
# area_process("LC1", nameID = "ObjectID")
# area_process("StLlorenc", nameFeho_i = "FeHo_2")

AreaList <- basename(list.dirs(file.path(run_DataDir), recursive = F))
for (aa in AreaList){
  area_process_allArrow(aa)
}


#------ CSV 
wind_csv_Check("GIF14_Au", to_save = F)
wind_csv_Check("LaJonquera", to_save = F)
wind_csv_Check("LC1", to_save = F)
wind_csv_Check("StLlorenc", to_save = F)





