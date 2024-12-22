root_folder <- rprojroot::find_rstudio_root_file()
source(file.path(root_folder, "R/EnvSetup.R"), echo = FALSE)

#----------------------------------------------
# set a key to the keychain
if (file.exists("R/.credential.R")){
  source(file.path(root_folder, "R/.credential.R"), echo = FALSE)
  wf_set_key(key = ecmwfAPIKey)
} else {
  message("Error: '.credential.R' required for API tokens!")
  # Input your login info with an interactive request
  wf_set_key()
}

# you can retrieve the key using
# wf_get_key()
#----------------------------------------------

AreaName = "GIF14_Au"
# Get fire fronts shp file
setwd(file.path(root_folder, dataDir, AreaName))
shpIn <- fs::dir_ls("./input", glob = "*.shp")
vFireIn <- vect(shpIn)

# Filter ti,e
FeHo_tbl <- vFireIn %>% 
  group_by(FeHo) %>% 
  summarise(n = n()) %>% 
  as_tibble()

for (i in 1:2) {
  fhGet = FeHo_tbl$FeHo[i]
  fhGet2 = FeHo_tbl$FeHo[i+1]
  fhTime = as.POSIXct(fhGet, format = "%Y/%m/%d_%H%M")
  fhTime2 = as.POSIXct(fhGet2, format = "%Y/%m/%d_%H%M")
  yy = format(fhTime, "%Y")
  mm = format(fhTime, "%m")
  dd = format(fhTime, "%d")
  tt = format(fhTime, "%H:%M")
  stmp_tt = format(fhTime, "%H%M")
  
  centroids(v)
  
  feat_fh <- vFireIn %>% 
    filter(FeHo == {{fhGet}})
    
  ext_org <- ext(feat_fh)
  crs_org <- crs(feat_fh)
  
  extent_object <- rast(extent = ext_org, crs = crs_org)
  transformed_extent <- project(extent_object, "EPSG:4326")
  # Get the new extent in longitude and latitude
  lon_lat_extent <- ext(transformed_extent)
  #North (ymax, 4), West (xmin, 1), South (ymin, 3), East (xmax, 2)
  coorAPI <- c(lon_lat_extent[4], lon_lat_extent[1], lon_lat_extent[3], lon_lat_extent[2])
  
  # Write request for API
  time_stp <- paste0(yy,mm,dd,stmp_tt)
  temp <- paste0("/data/ER5/era5-land-wind-", time_stp,".nc")
  print(paste("Store to ...", temp))
  if (!file.exists(paste0(root_folder, temp))){
    request <- list(
      dataset_short_name = "reanalysis-era5-land",
      data_format = "grib",
      download_format = "unarchived",
      variable = c("10m_u_component_of_wind", "10m_v_component_of_wind"),
      year = yy,
      month = mm,
      day = dd,
      time = tt,
      area = coorAPI,
      target = temp 
    )
  
    # If you have stored your user login information
    # in the keyring by calling cds_set_key you can
    # call:
    file <- wf_request(
      request  = request,  # the request
      transfer = TRUE,     # download the file
      path     = root_folder       # store data in current working directory
    )
  } else {
    file = paste0(root_folder, temp)
  }
  
  # (trap read error on mac - if gdal netcdf support is missing)
  r <- terra::rast(file)
  terra::plot(r)
}





# Run FireRun Algorithm for Polygon only
if (!file.exists("outputs/RunsPol.shp")) {
  Runs(vFireIn, nameID = nameID_i, nameFeho = nameFeho_i, CreateSharedFrontLines = T)
}




# Open NetCDF file and plot the data


