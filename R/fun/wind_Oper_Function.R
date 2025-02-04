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

dirAngle_mean <- function(angles) {
  # Convert angles from degrees to radians
  radians <- angles * pi / 180
  
  # Convert to Cartesian coordinates
  x <- cos(radians)
  y <- sin(radians)
  
  # Compute mean x and y
  mean_x <- mean(x)
  mean_y <- mean(y)
  
  # Compute the average angle in radians
  avg_radians <- atan2(mean_y, mean_x)
  
  # Convert back to degrees
  avg_degrees <- avg_radians * 180 / pi
  
  # Ensure the angle is in the range [0, 360)
  if (avg_degrees < 0) {
    avg_degrees <- avg_degrees + 360
  }
  
  return(avg_degrees)
}