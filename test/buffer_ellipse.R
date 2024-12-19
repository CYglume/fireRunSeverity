# Load required libraries
library(terra)
library(ggplot2)

# Function to create an elliptical buffer along a line
create_elliptical_buffer <- function(line_coords, 
                                     major_axis = 1, 
                                     minor_axis = 0.3, 
                                     points = 100) {
  
  # Calculate line angle and length
  dx <- diff(line_coords[,1])
  dy <- diff(line_coords[,2])
  angle <- atan2(dy, dx)
  
  # Create ellipse points
  t <- seq(0, 2*pi, length.out = points)
  
  # Base ellipse coordinates
  x_base <- major_axis * cos(t)
  y_base <- minor_axis * sin(t)
  
  # Rotate and translate ellipse
  x_rot <- x_base * cos(angle) - y_base * sin(angle)
  y_rot <- x_base * sin(angle) + y_base * cos(angle)
  
  # Center the ellipse on the line midpoint
  mid_x <- mean(line_coords[,1])
  mid_y <- mean(line_coords[,2])
  
  x_final <- x_rot + mid_x
  y_final <- y_rot + mid_y
  
  # Create polygon
  ellipse_coords <- cbind(x_final, y_final)
  ellipse <- vect(ellipse_coords, type="polygons", crs="epsg:3857")
  
  return(ellipse)
}

# Create sample line features at different angles
lines <- list(
  cbind(c(0, 1), c(0, 0)),      # Horizontal
  cbind(c(0, 0), c(0, 1)),      # Vertical
  cbind(c(0, 1), c(0, 1)),      # 45 degrees
  cbind(c(0, 1), c(0, -1))      # -45 degrees
)

# Create elliptical buffers for each line
buffers <- list()
for(i in seq_along(lines)) {
  buffers[[i]] <- create_elliptical_buffer(lines[[i]], 
                                           major_axis = 0.8, 
                                           minor_axis = 0.2)
}

# Convert to dataframes for plotting
plot_data <- data.frame()
line_data <- data.frame()
orientations <- c("Horizontal", "Vertical", "45 degrees", "-45 degrees")

for(i in seq_along(buffers)) {
  # Buffer coordinates
  coords <- crds(as.lines(buffers[[i]]))
  df <- as.data.frame(coords)
  df$orientation <- orientations[i]
  plot_data <- rbind(plot_data, df)
  
  # Line coordinates
  line_df <- as.data.frame(lines[[i]])
  names(line_df) <- c("x", "y")
  line_df$orientation <- orientations[i]
  line_data <- rbind(line_data, line_df)
}

# Create plot
ggplot() +
  geom_path(data = plot_data, aes(x = x, y = y)) +
  geom_line(data = line_data, aes(x = x, y = y), 
            color = "red", size = 1) +
  facet_wrap(~orientation, ncol = 2) +
  coord_fixed() +
  theme_minimal() +
  labs(title = "Elliptical Buffers Along Line Features",
       subtitle = "Red lines show the original line features",
       x = "X coordinate",
       y = "Y coordinate") +
  theme(panel.grid.minor = element_blank())
