# -------------------------------------------------------------------------
# For checking Shapefile input of AOI,
# Two variables are important for the `FireRuns` algorithm
# Any operation regarding the shapefile will need the following variables:
# 1. check if `FeHo` exists for later data processing
# 2. check if unique `OBJECTID` exists
# -------------------------------------------------------------------------
root_folder <- rprojroot::find_rstudio_root_file()
source(file.path(root_folder, "R/EnvSetup.R"), echo = FALSE)

# -------------------------------------------------------------------------
########################################
# Get Shapefile input:                 #
# 1. search in AOI folder and get .shp #
########################################

AreaList <- basename(list.dirs(file.path(run_DataDir), recursive = F))


# -------------------------------------------------------------------------
AreaName = AreaList[6]
AreaName
# Get fire fronts shp file
setwd(file.path(root_folder, run_DataDir, AreaName))
shpIn <- fs::dir_ls("./input", glob = "*.shp")
vFireIn <- vect(shpIn)


# -------------------------------------------------------------------------

# -------------------------------------------------------------------------
############################################
# Check valid variables:                   #
# 1. check suitable columns for `FeHo`     #
# 2. check suitable columns for `OBJECTID` #
############################################

for (i in 1:ncol(vFireIn)){
  verify_DATE_head <- head(vFireIn[[i]]) %>% 
    pull() %>% 
    lubridate::parse_date_time(orders = c("Ymd HM", "dmY HM"),quiet = T) %>% 
    is.na()
  if(any(!verify_DATE_head)){
    message("Column name for FeHo:")
    print(i)
    print(names(vFireIn)[i])
  }
  if (length(unique(vFireIn[[i]][,1])) == nrow(vFireIn)) {
    # length(vFireIn[[i]][,1])
    message("Column name for OBJECTID:")
    print(i)
    print(names(vFireIn)[i])
  }
}
# -------------------------------------------------------------------------

# -------------------------------------------------------------------------
############################################################################
# Modify Shapefile:                                                        #
# 1. Need to set up manually!!                                             #
# 2. Not connected with previous part for safe operating file modification #
############################################################################
vFireIn <- vFireIn %>% 
  rename(FeHo = 4,                            # !!Variable to be modify
         OBJECTID = 2                         # !!Variable To be modify
         ) %>%       
  mutate(FeHo = as.POSIXct(FeHo)) %>%
  # mutate(FeHo = lubridate::parse_date_time(FeHo, orders = c("Ymd HM", "dmY HM"),quiet = T)) %>%
  na.omit("FeHo", geom = TRUE) %>%        # Deleting Geometry
  mutate(FeHo = format(FeHo, "%Y/%m/%d_%H%M"))

# If only to modify OBJECTID
# vFireIn <- vFireIn %>%
#   rename(OBJECTID = ObjectIDgo)

vFireIn$FeHo 
vFireIn$OBJECTID = 1:nrow(vFireIn)
unique(vFireIn$OBJECTID)



# !! Write Spatial vector into file !!
# writeVector(vFireIn, shpIn, overwrite = TRUE)
setwd(root_folder)
# -------------------------------------------------------------------------

# -------------------------------------------------------------------------
# Check complete separation of polygons
message("\n---- Checking polygon counts ----")
for (aa in AreaList){
  message(paste(" - AOI:", aa))
  # Get fire fronts shp file
  setwd(file.path(root_folder, run_DataDir, aa))
  shpIn <- fs::dir_ls("./input", glob = "*.shp")
  vFireIn <- vect(shpIn)
  
  ngeom <- vFireIn %>% disagg() %>% nrow()
  if (ngeom != nrow(vFireIn)){
    message(" -- Small non-separated geometries found!")
    message(paste(" -- ID count:", nrow(vFireIn), "Geom found:", ngeom))
    if ("OBJECTID" %in% names(vFireIn)){
      vFireIn <- vFireIn %>% 
        rename(OBJECTID_old = OBJECTID)
    }
    vFireIn <- vFireIn %>% 
      disagg() %>% 
      mutate(OBJECTID = row_number())
    # print(head(vFireIn))
    
    message("\n -- Writing modified SpatVector into shpIn...")
    # !! Write Spatial vector into file !!
    writeVector(vFireIn, shpIn, overwrite = TRUE)
  }else{
    message(" -- OBJECTID matched polygon counts.")
  }
  message(" ---\n")
  
  setwd(root_folder)
}
