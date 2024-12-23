# Environment Set Up ------------------------------------------------------
rm(list = ls())
root_folder <- rprojroot::find_rstudio_root_file()
dataDir <- r"(data\FirstWildfires)"


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
source("R/fun/Runs_AllArrows.R", echo = TRUE)
source("R/fun/Process_Runs.R", echo = TRUE)



#---- Create Data folder ------




#------------------------------

