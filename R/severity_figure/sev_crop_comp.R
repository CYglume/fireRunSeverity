source("R/EnvSetup.R", echo = TRUE)

arealst = list_fireRuns()
aa = arealst[6]

all_idcs_table = data.frame()
for (aa in arealst){
  id_dir = file.path(idcs_DataDir, aa)
  fire_peri = fetch_firePeri(aa)
  
  idNames = list.files(id_dir, pattern = ".tif$")
  ids = data.frame()
  env_ids = data.frame()
  for (i in idNames){
    i_sub <- strsplit(i, "--")[[1]][1]
    if (strsplit(i_sub, "_")[[1]][2] == "env"){
      env_ids = rbind(env_ids,
                      data.frame(name = i_sub, 
                                 loc = paste0(id_dir, "/", i)))
    }else{
      ids     = rbind(ids, 
                      data.frame(name = i_sub, 
                                 loc = paste0(id_dir, "/", i)))
    }
  }
  
  if (exists('ras_idcs')) rm(ras_idcs)
  for (i in 1:nrow(ids)){
    if (!exists("ras_idcs")){
      ras_idcs <- rast(ids$loc[i])
    }else{
      ras_idcs <- c(ras_idcs, rast(ids$loc[i]))
    }
  }
  
  peri_mask <- terra::aggregate(fire_peri) %>% project("EPSG:4326")
  ras_idcs <- crop(ras_idcs, peri_mask, mask = TRUE)
  ras_tbl  <- ras_idcs %>% as.data.frame()
  ras_tbl_sum <- ras_tbl %>% 
    summarise(across(
      everything(),
      .fns = list(
        Mean = ~mean(.x,na.rm = T),
        SE   = se,
        Max10p  = max_Mean_p10,
        Min10p  = min_Mean_p10
      ),
      .names = "{.col}_{.fn}"
    )) %>% 
    pivot_longer(
      cols = everything(),
      names_sep = "_",
      names_to = c("composite", "idcs", "stats"),
      values_to = "value"
    ) %>% 
    pivot_wider(
      names_from = c("composite", "idcs"),
      names_sep = "_",
      values_from = "value"
    ) %>% 
    mutate(fire = {{aa}},.before = stats)
  
  all_idcs_table <- rbind(all_idcs_table, ras_tbl_sum)
  gc()
}
all_idcs_table %>% write.csv(file.path(stats_DataDir, "all_id_table.csv"))



# ras_idcs %>% 
#   select(M_RdNBR) %>%
#   writeRaster(file.path("QGIS_content/data", "StL_M_RdNBR.tif"),overwrite=TRUE)
