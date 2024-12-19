# Load required libraries
library(terra)
library(ggplot2)

# Function to create egg shape coordinates
create_egg <- function(a = 1, b = 0.7, points = 200) {
  t <- seq(0, 2*pi, length.out = points)
  
  # Modified equations for egg shape with one pointed end
  x <- a * cos(t)
  # This creates a point at one end and rounded at the other
  y <- b * sin(t) * (1 - 0.3*cos(t))
  
  return(cbind(x, y))
}

# Function to create egg-shaped buffer along a line
create_egg_buffer <- function(line_coords, 
                              length = 1, 
                              width = 0.7, 
                              points = 200) {
  
  # Calculate line angle
  dx <- diff(line_coords[,1])
  dy <- diff(line_coords[,2])
  angle <- atan2(dy, dx)
  
  # Create base egg shape
  egg_coords <- create_egg(a = length, b = width, points = points)
  
  # Rotate coordinates to align pointed end with line start
  # Add pi to angle to orient the point at the start of the line
  x_rot <- egg_coords[,1] * cos(angle + pi) - egg_coords[,2] * sin(angle + pi)
  y_rot <- egg_coords[,1] * sin(angle + pi) + egg_coords[,2] * cos(angle + pi)
  
  # Center on line midpoint
  mid_x <- mean(line_coords[,1])
  mid_y <- mean(line_coords[,2])
  
  x_final <- x_rot + mid_x
  y_final <- y_rot + mid_y
  
  # Create polygon
  egg <- vect(cbind(x_final, y_final), type="polygons", crs="epsg:3857")
  
  return(egg)
}

# Create sample lines at different angles
lines <- list(
  cbind(c(0, 1), c(0, 0)),      # Horizontal
  cbind(c(0, 0), c(0, 1)),      # Vertical
  cbind(c(0, 1), c(0, 1)),      # 45 degrees
  cbind(c(0, 1), c(0, -1))      # -45 degrees
)

# Create egg buffers for each line
buffers <- list()
orientations <- c("Horizontal", "Vertical", "45 degrees", "-45 degrees")

for(i in seq_along(lines)) {
  buffers[[i]] <- create_egg_buffer(lines[[i]], 
                                    length = 1.2, 
                                    width = 0.6)
}

# Convert to dataframes for plotting
plot_data <- data.frame()
line_data <- data.frame()

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
  # Add start point marker
  line_df$point_type <- c("Start", "End")
  line_data <- rbind(line_data, line_df)
}

# Create plot
ggplot() +
  geom_path(data = plot_data, aes(x = x, y = y)) +
  geom_line(data = line_data, aes(x = x, y = y), 
            color = "red", size = 1) +
  geom_point(data = subset(line_data, point_type == "Start"),
             aes(x = x, y = y), color = "blue", size = 3) +
  facet_wrap(~orientation, ncol = 2) +
  coord_fixed() +
  theme_minimal() +
  labs(title = "Egg-Shaped Buffer with Pointed End at Line Start",
       subtitle = "Red line shows the original line feature\nBlue point shows line start",
       x = "X coordinate",
       y = "Y coordinate") +
  theme(panel.grid.minor = element_blank())