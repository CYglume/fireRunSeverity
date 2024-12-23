# ------------------------------------------------------------------------------
# Try to run FireRun on sample data
# 
# Input: data/FirstWildfires/
# ------------------------------------------------------------------------------
source("R/EnvSetup.R", echo = TRUE)


# area_process("GIF14_Au")
# area_process("LaJonquera", nameID = "ObjectID")
# area_process("LC1", nameID = "ObjectID")
# area_process("StLlorenc", nameFeho_i = "FeHo_2")

areaList = list(c(aoi = "GIF14_Au",   nameID = "OBJECTID", nameFeho_i = "FeHo"),
                c(aoi = "LaJonquera", nameID = "ObjectID", nameFeho_i = "FeHo"),
                c(aoi = "LC1",        nameID = "ObjectID", nameFeho_i = "FeHo"),
                c(aoi = "StLlorenc",  nameID = "OBJECTID", nameFeho_i = "FeHo_2")
                )
for (aa in areaList){
  area_process_allArrow(aa[['aoi']],  aa[['nameID']], aa[['nameFeho_i']])
}


#------ CSV 
wind_csv_Check("GIF14_Au", to_save = F)
wind_csv_Check("LaJonquera", to_save = F)
wind_csv_Check("LC1", to_save = F)
wind_csv_Check("StLlorenc", to_save = F)





