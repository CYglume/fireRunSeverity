# Environment Set Up ------------------------------------------------------
rm(list = ls())
root_folder <- rprojroot::find_rstudio_root_file()
dataDir <- r"(data/fireruns)"


# Load Packages -----------------------------------------------------------
# Install needed packages
# require(devtools)
# install_github("AndreaDuane/FireRuns")
# install.packages('tidyterra')
# install.packages("ggpubr")
# install.packages("ecmwfr")
library(ecmwfr)
library(FireRuns)
library(sf)
library(ggplot2)
library(tidyterra)
library(ggpubr)
library(tidyverse)
source("R/fun/Runs_AllArrows.R", echo = FALSE)
source("R/fun/Data_Function.R", echo = FALSE)



#---- Create Data folder ------
if (FALSE) {
  dt_folder <- c("data/fireruns",
                 "data/ER5",
                 "data/GEE")
  # Create project directories
  for (dir in dt_folder) {
    dir_path <- file.path(root_folder, dir)
    if (!dir.exists(dir_path)) {
      dir.create(dir_path, recursive = TRUE)
      message(paste("Created folder:", dir))
    } else {
      message(cli::col_blue(paste("Folder exists:", dir)))
    }
  }
  
  # Create sub folders for fire runs
  dt_folder <- list.dirs("src/fireRaw", recursive = F)
  for (dir in dt_folder) {
    dir_path <- file.path(root_folder, dir)
    if (!dir.exists(dir_path)) {
      dir.create(dir_path, recursive = TRUE)
      message(paste("Created folder:", dir))
    } else {
      message(cli::col_blue(paste("Folder exists:", dir)))
    }
  }
}
#------------------------------

