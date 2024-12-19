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



