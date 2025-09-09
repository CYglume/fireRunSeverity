source("R/EnvSetup.R", echo = TRUE)

SPEI_dir = r"(D:\_Work2025\SPEI)"
# SPEI_dir = r"(D:\DATA\SPEIBase)"
SPEI_dir

# Get Fire perimeter data
AreaList <- basename(list.dirs(file.path(run_DataDir), recursive = F))
# AreaName = AreaList[5]
AreaName = AreaList[5]
AreaName
fPeri <- fetch_firePeri(AreaName)
cropBox <- ext(fPeri) %>% vect(crs = crs(fPeri)) %>%  project("EPSG:4326")


# Get SPEI (locally provided)
in_spei_list = list.files(SPEI_dir)
yr = fPeri$FeHo %>% parse_date_time(orders = c("%y/%m/%d_%H%M")) %>% year() %>% unique()
mn = fPeri$FeHo %>% parse_date_time(orders = c("%y/%m/%d_%H%M")) %>% month() %>% unique()

# Process and output SPEI
outfld = file.path(idcs_DataDir, AreaName)
var_name_lst = c("SPEI_03_month", "SPEI_06_month", "SPEI_09_month", "SPEI_12_month")
process_time = format.Date(Sys.time(), format = "%d%m%Y_%H%M")
for (fsp in in_spei_list){
  spei_number = str_extract(fsp, "[0-9][0-9]")
  vname = var_name_lst[str_extract(var_name_lst, "[0-9][0-9]") == spei_number]
  out_Name = paste0("S2_SPEI_", spei_number, "_month--", 
                    process_time, ".tif")
  
  fsp = file.path(SPEI_dir, fsp)
  
  i_SPEI = rast(fsp)
  filt_i_SPEI = i_SPEI[[year(time(i_SPEI)) == yr]]
  filt_i_SPEI = filt_i_SPEI[[month(time(filt_i_SPEI)) == mn]]
  crop_i_SPEI = crop(filt_i_SPEI, cropBox) %>% rename(!!vname := 1)

  writeRaster(crop_i_SPEI, file.path(outfld, out_Name))
}


# Verify cropping results
ggplot() +
  geom_spatraster(data = crop_i_SPEI, aes(fill = .data[[vname]]))+
  geom_sf(data = fPeri)

# Verify written files
a = rast(file.path(outfld, out_Name))
