# Environment Set Up ------------------------------------------------------
rm(list = ls())
root_folder <- rprojroot::find_rstudio_root_file()
run_DataDir  <- r"(data/fireruns)"
idcs_DataDir <- r"(data/GEE)"
er5_DataDir  <- r"(data/ER5)"
stats_DataDir  <- r"(data/Stats)"
setwd(root_folder)

# Load Packages -----------------------------------------------------------
# Install needed packages
# require(devtools)
# install_github("AndreaDuane/FireRuns")
library(FireRuns)


# Load required packages
packagesToLoad <- c("tidyverse", "tidyterra", "ggpubr", "ecmwfr", "sf", "lutz")
for (package in packagesToLoad) {
  if (!require(package, character.only = TRUE)) {
    install.packages(package)
    library(package, character.only = TRUE)
  }
}

# Load Project Source files
source("R/fun/Data_Function.R", echo = FALSE)


#---- Create Data folder ------
dt_folder <- c(run_DataDir, 
               idcs_DataDir, 
               er5_DataDir,
               stats_DataDir,
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
  # Run for each AOI folder in fireRaw
  for (di in dt_folder) {
    fname_list <- list.files(di, full.names = T)
    fname_list <- fname_list[!file.info(fname_list)$isdir]
    
    # Create new folder names in data folder
    di <- basename(di)
    dir_path <- file.path(root_folder, run_DataDir, di, "input")
    
    # Create data folder and copy files from fireRaw/AOI
    if (!dir.exists(dir_path)) {
      dir.create(dir_path, recursive = TRUE)
      #Copy files each by each
      for (path_f in fname_list){
        path_t = paste(dir_path, basename(path_f), sep="/")
        file.copy(from = path_f, to = path_t, recursive = F)
      }
      message(paste("Created folder:", di))
    } else {
      message(cli::col_blue(paste("Folder exists:", di)))
    }
  }
}

# Clear unused variable
rmLst <- c("di", "dt_folder", "dir_path", "fname_list", "path_f", "path_t")
rmLst <- rmLst[which(sapply(rmLst, exists))]
rm(list = c(rmLst, "rmLst"))
gc()
#------------------------------

