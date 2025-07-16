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


# -------------------------------------------------------------------------
# Check output runs
library(patchwork)

AreaList <- list_fireRuns()
peri = fetch_firePeri(AreaList[1])
runP = fetch_fireRun(AreaList[1], RunType = "FullPol") %>% filter(Distance > 0)
runW = fetch_fireRun(AreaList[1], RunType = "FullWind") %>% filter(Distance > 0)

peri <- peri %>% 
  mutate(Feho_n = as.POSIXct(FeHo))

p1 = ggplot()+
    geom_sf(data = peri, aes(fill = Feho_n))+
    geom_sf(data = runP, color = "red",linewidth = 1,
            arrow = arrow(type = "open", length = unit(0.2, "cm")))+
    scale_fill_datetime(low = "#2972b6",
                        high = "#ffbf00",
                        name = "",
                        date_labels = "%d%b %Y %H:%M")+
    labs(title = "Pol runs")+
    theme_bw(base_size = 16, base_family = "serif")+
    theme(legend.position = "top",
          legend.key.width = unit(3, "cm"),
          axis.text.x = element_text(angle = 20, vjust = 1, hjust=1))
p2 = ggplot()+
  geom_sf(data = peri, aes(fill = Feho_n))+
  geom_sf(data = runW, color = "lightblue",linewidth = 1,
          arrow = arrow(type = "open", length = unit(0.2, "cm")))+
  scale_fill_datetime(low = "#2972b6",
                      high = "#ffbf00",
                      name = "",
                      date_labels = "%d%b%Y %H:%M")+
  labs(title = "Wind runs")+
  theme_bw(base_size = 16, base_family = "serif")+
  theme(legend.position = "top",
        legend.key.width = unit(3, "cm"),
        axis.text.x = element_text(angle = 20, vjust = 1, hjust=1))

plot_out <- ggarrange(p1, p2, ncol=2, nrow=1, common.legend = TRUE)
ggsave("man/figures/fireruns.svg",plot = plot_out, device = "svg",
       width = unit(10, "inch"),height = unit(4.8, 'inch'))
