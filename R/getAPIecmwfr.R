root_folder <- rprojroot::find_rstudio_root_file()
source(file.path(root_folder, "R/EnvSetup.R"), echo = FALSE)
source("R/fun/wind_Oper_Function.R", echo = FALSE)

# ----------------------------------------------
#############################
# Setup:                    #
# set a key to the keychain #
#############################

if (file.exists("R/.credential.R")){
  source(file.path(root_folder, "R/.credential.R"), echo = FALSE)
  wf_set_key(key = ecmwfAPIKey)
} else {
  message("'.credential.R' required for API tokens!")
  # Input your login info with an interactive request
  wf_set_key()
}

# you can retrieve the key using
# wf_get_key()
# ----------------------------------------------


# -------------------------------------------------------------------------
###############################################
# Input:                                      #
# Manually Set up Input Control Parameters    #
# Parse the data folders to get a list of AOI #
# Variable in Loop: AreaName = "GIF14_Au"     #
############################################### 

AreaList <- basename(list.dirs(file.path(run_DataDir), recursive = F))

# -------------------------------------------------------------------------


# -------------------------------------------------------------------------
######################################################################################
# Algorithm                                                                          #
# Run Algorithm to get Wind data from ERA5-Land hourly Wind data                     #
# Refer to API link: https://cds.climate.copernicus.eu/datasets/reanalysis-era5-land #
######################################################################################

for (AreaName in AreaList){
  wind_tbl_path <- file.path(run_DataDir,
                             AreaName, "input", "TesaureWind.csv")
  
  # Check if wind table already exists
  if (file.exists(wind_tbl_path)){
    message(cli::col_blue(paste("\nWind CSV File exists:\n", wind_tbl_path)))
    next
  }
  message(paste0("\n-- Ceating Wind table for AOI: ", AreaName))
  wind_tbl_path <- file.path(root_folder, wind_tbl_path)
  
  
  # Get fire fronts shp file
  setwd(file.path(root_folder, run_DataDir, AreaName))
  shpIn <- fs::dir_ls("./input", glob = "*.shp")
  vFireIn <- vect(shpIn)
  setwd(root_folder)
  
  # Get a table for FeHo hours
  FeHo_tbl <- vFireIn %>% 
    group_by(FeHo) %>% 
    summarise(n = n()) %>% 
    as_tibble()
  
  
  # Create data folder for ER5 download
  dir_path = paste(root_folder, er5_DataDir, AreaName, sep = "/")
  if (!dir.exists(dir_path)) {
    dir.create(dir_path, recursive = TRUE)
    message(paste("Created folder:", dir_path))
  } else {
    message(cli::col_blue(paste("Folder exists:", dir_path)))
  }
  
  
  #Find the correct time zone for Fire polygons
  tzName <- ext(vFireIn) %>% 
    as.polygons(crs = crs(vFireIn)) %>% 
    centroids() %>% 
    st_as_sf() %>% 
    tz_lookup(method = "accurate")
  message(paste0("Time zone found by coordinates: ", tzName))
  
  # Fetch Wind data from ER5 and produce dataframe per Feho
  wind_Feho = data.frame()
  for (i in 1:nrow(FeHo_tbl)) {
    fhGet = FeHo_tbl$FeHo[i]
    message(paste0("FeHo ", i, ":", fhGet))
    fhTime = as.POSIXct(fhGet, format = "%Y/%m/%d_%H%M", tz = tzName)
    stmp_tt = format(fhTime, "%Y%m%d_%H%M")
    stmp_tt = paste("FeHo", stmp_tt, sep = "_")
    
    # Calculate time range for retrieving ER5 wind data
    # Round the previous FeHo time to generate time series ON THE HOUR
    if (i == 1){
      fhTime_pre  = fhTime - 2*60*60
      fhTime_pre  = floor_date(fhTime_pre, unit = "hour")
      stmp_tt = paste(stmp_tt, "first", sep = "_")
    } else {
      fhGet_pre = FeHo_tbl$FeHo[i-1]
      fhTime_pre = as.POSIXct(fhGet_pre, format = "%Y/%m/%d_%H%M", tz = tzName)
      fhTime_pre = floor_date(fhTime_pre, unit = "hour")
    }
    
    # Produce API time list
    fh_Lst <- seq.POSIXt(fhTime_pre, fhTime, by = "hour")
    fh_Lst <- with_tz(fh_Lst, "UTC")
    yy = unique(format(fh_Lst, "%Y"))
    mm = unique(format(fh_Lst, "%m"))
    dd = unique(format(fh_Lst, "%d"))
    tt = unique(format(fh_Lst, "%H:%M"))
    message(cli::col_blue("Get hours:"))
    message(cli::col_blue(paste0(tt, collapse = ", ")))
    
    # Get the desired extent for raster wind
    feat_fh <- vFireIn %>% 
      filter(FeHo == {{fhGet}})
    if (length(unique(geom(feat_fh)[,1])) > 1){
      del_id <- which(expanse(feat_fh) < 10)
      if (length(del_id) > 0) {
        feat_fh <- feat_fh[-del_id]
      }
    }
    message(paste0("-- geometry count: ", length(unique(geom(feat_fh)[,1]))))
      
    ext_org <- ext(feat_fh)
    crs_org <- crs(feat_fh)
    
    extent_object <- as.polygons(ext_org, crs = crs_org)
    transformed_extent <- project(extent_object, "EPSG:4326")
    # Enlarge entent to ensure enough pixels in retrieving ER5 data
    transformed_extent_buffer <- buffer(transformed_extent, width = 10000)
    
    # Get the new extent in longitude and latitude
    lon_lat_extent <- ext(transformed_extent_buffer)
    #North (ymax, 4), West (xmin, 1), South (ymin, 3), East (xmax, 2)
    coorAPI <- c(lon_lat_extent[4], lon_lat_extent[1], lon_lat_extent[3], lon_lat_extent[2])
    message("Get AOI range for API fetch: ")
    message("North (ymax, 4), West (xmin, 1), South (ymin, 3), East (xmax, 2)")
    message(paste0(round(coorAPI, 5), collapse = "  "))
    
    # Write request for API
    temp <- paste0("era5-land-wind-", stmp_tt,".nc")
    if (!file.exists(paste(dir_path, temp, sep = "/"))){
      message(paste("Store to ...", temp))
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
    
      # Calling the requesting function
      file <- wf_request(
        request  = request,  # the request
        transfer = TRUE,     # download the file
        path     = dir_path  # store data in AOI directory
      )
      r <- terra::rast(file)
    } else {
      message(paste("Found file:", temp))
      file = paste(dir_path, temp, sep = "/")
      r <- terra::rast(file)
    }
    
    # process wind data
    r = project(r, crs(feat_fh))
    Feho_wind_extract = data.frame()
    for (ti in 1:(nlyr(r)/2)){
      # Skip run for times not in FeHo list 
      # or Not match each other (u v must be at the same hour)
      if (!terra::time(r[[ti*2-1]]) %in% fh_Lst |
          !terra::time(r[[ti*2]]) %in% fh_Lst |
          terra::time(r[[ti*2-1]]) != terra::time(r[[ti*2]])){
        next
      }
      
      # Calculate Wind direction and speed from vectors u & v
      u <- r[[ti*2 - 1]]
      v <- r[[ti*2]]
      wind_spd <- sqrt(u^2 + v^2)
      wind_Dir <- atan_2(v, u)/pi*180
      wind_Dir <- as.data.frame(wind_Dir, xy = TRUE) %>% 
          rename(value = 3) %>% 
          mutate(windComeDeg = sapply(value, cart_angle_toWindDir)) 
        
      # 1. Use centroid only
      cent_wind_extract <- terra::extract(rast(wind_Dir), centroids(feat_fh))
      cent_wSpeed_extract <- terra::extract(wind_spd, centroids(feat_fh))
      # 2. Use polygon and get touched pixels
      # cent_wind_extract <- terra::extract(rast(wind_Dir), feat_fh, touches = T, cells = T)
      
      # Modify FeHo wind
      cent_wind_extract <- na.omit(cent_wind_extract)
      mean_spd <- na.omit(cent_wSpeed_extract) %>% pull(2) %>% mean()
      cent_wind_extract <- cent_wind_extract %>% 
        mutate(wind_speed = mean_spd,
               Feho = terra::time(r[[ti*2-1]]))
      
      Feho_wind_extract <- rbind(Feho_wind_extract,
                                 cent_wind_extract)
    }
    print(Feho_wind_extract)
    tp_feho <- data.frame(Wind = dirAngle_mean(Feho_wind_extract$windComeDeg),
                          wind_speed = mean(Feho_wind_extract$wind_speed),
                          FeHo_W = fhGet)
    wind_Feho <- rbind(wind_Feho, tp_feho)
    rm(tp_feho)
    
    message("---- END ----\n")
    # ggplot() +
      # geom_sf(data = vFireIn[21])
      # geom_tile(data = r, aes(x=x, y=y, fill=lyr.1))
      # geom_sf(data = feat_fh)+
      # geom_point(data = wind_Dir, aes(x=x, y=y))
      # geom_sf(data = centroids(feat_fh))
    # print(p1)
  }
  
  # Add codi_hora for process in FireRuns algorithm
  wind_Feho <- wind_Feho %>% 
    mutate(codi_hora = seq(nrow(wind_Feho)), .before = 1)
  write.csv(wind_Feho,
            file = wind_tbl_path,
            row.names = FALSE)
  message(paste0("\n-- END of Writing Wind table for AOI: ", AreaName, "-------- \n"))
}

# -------------------------------------------------------------------------


