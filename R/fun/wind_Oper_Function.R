# Description -------------------------------------------------------------
## Functions for calculating and converting directional values
## operation between Cartesian coordinates and directional angles
## Considering the folder structure created by `EnvSetup.R`
# -------------------------------------------------------------------------

# Functions ---------------------------------------------------------------
cart_angle_toWindDir <- function(x) {
  # convert Cartesian angle (from vectors) to Azimuth
  x = 90 - x
  if (x < 0) {
    x = x + 360
  }
  
  #wind direction to -> wind direction from
  x = 180 + x
  if (x >= 360) {
    x = x - 360
  }
  
  return(x)
}

windCome_to_windTowards <- function(x){
  x = 180 + x
  x <- ifelse(x >= 360, x %% 360, x)
  return(x)
}

dirAngle_mean <- function(angles) {
  # Convert angles from degrees to radians
  radians <- angles * pi / 180
  
  # Compute mean x and y
  mean_x <- mean(cos(radians))
  mean_y <- mean(sin(radians))
  
  if (mean_x == 0 && mean_y == 0) {
    return(NA_real_)  # Ambiguous average (e.g. [0, 180])
  }
  
  # Compute the average angle in radians
  avg_radians <- atan2(mean_y, mean_x)
  
  # Convert back to degrees
  avg_degrees <- (avg_radians * 180 / pi) %% 360
  
  if (abs(avg_degrees - 360) < 1e-6) avg_degrees <- 0
  
  return(avg_degrees)
}