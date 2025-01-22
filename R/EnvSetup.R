# Environment Set Up ------------------------------------------------------
rm(list = ls())
root_folder <- rprojroot::find_rstudio_root_file()
run_DataDir  <- r"(data/fireruns)"
idcs_DataDir <- r"(data/GEE)"
er5_DataDir  <- r"(data/ER5)"


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
dt_folder <- c(run_DataDir, 
               idcs_DataDir, 
               er5_DataDir,
               "src/fireRaw")

if (any(!dir.exists(dt_folder))) {
  # Create project directories
  for (di in dt_folder) {
    dir_path <- file.path(root_folder, di)
    if (!dir.exists(dir_path)) {
      dir.create(dir_path, recursive = TRUE)
      message(paste("Created folder:", di))
    } else {
      message(cli::col_blue(paste("Folder exists:", di)))
    }
  }
}

# Create sub folders for fire runs
dt_folder <- list.dirs("src/fireRaw", recursive = F)
if (length(dt_folder) != 0) {
  for (di in dt_folder) {
    di <- basename(di)
    dir_path <- file.path(root_folder, run_DataDir, di, "input")
    if (!dir.exists(dir_path)) {
      dir.create(dir_path, recursive = TRUE)
      message(paste("Created folder:", di))
    } else {
      message(cli::col_blue(paste("Folder exists:", di)))
    }
  }
}
rm(di, dt_folder, dir_path)
#------------------------------

