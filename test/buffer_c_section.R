# Load required libraries
library(terra)
library(ggplot2)

# Create a sample line feature
line_coords <- cbind(c(0, 1), c(0, 1))
line <- vect(line_coords, type="lines", crs="epsg:3857")

# Create a full buffer around the line
full_buffer <- buffer(line, width = 0.5)

# Create a mask for the sector
# We'll create a polygon that represents the sector we want to keep
# This example creates a sector in the northeast direction

# Function to create sector polygon
create_sector <- function(angle_start = 0, angle_end = 90) {
  # Create points for the sector
  angles <- seq(angle_start, angle_end, length.out = 100)
  radius <- 2  # Make larger than buffer width to ensure coverage
  
  # Calculate points on arc
  x <- c(0, radius * cos(angles * pi/180), 0)
  y <- c(0, radius * sin(angles * pi/180), 0)
  
  # Create polygon
  sector <- vect(cbind(x, y), type="polygons", crs="epsg:3857")
  # Move sector to cover the line
  sector <- shift(sector, dx=0, dy=0)
  
  return(sector)
}

# Create sectors for different angles
sectors <- list(
  create_sector(0, 90),    # Northeast sector
  create_sector(90, 180),  # Northwest sector
  create_sector(180, 270), # Southwest sector
  create_sector(270, 360)  # Southeast sector
)

# Create masked buffers
masked_buffers <- list()
for(i in seq_along(sectors)) {
  masked_buffers[[i]] <- crop(full_buffer, sectors[[i]])
}

# Convert to data frames for plotting
plot_data <- data.frame()
directions <- c("Northeast (0-90°)", "Northwest (90-180°)", 
                "Southwest (180-270°)", "Southeast (270-360°)")

for(i in seq_along(masked_buffers)) {
  if(!is.null(masked_buffers[[i]])) {
    coords <- crds(as.lines(masked_buffers[[i]]))
    df <- as.data.frame(coords)
    df$direction <- directions[i]
    plot_data <- rbind(plot_data, df)
  }
}

# Add line coordinates for plotting
line_df <- as.data.frame(line_coords)
names(line_df) <- c("x", "y")

# Create plot
ggplot() +
  geom_path(data = plot_data, aes(x = x, y = y)) +
  geom_line(data = line_df, aes(x = x, y = y), 
            color = "red", size = 1) +
  facet_wrap(~direction, ncol = 2) +
  coord_fixed() +
  theme_minimal() +
  labs(title = "Directional Sector Buffers Around Line Feature",
       subtitle = "Red line shows the original line feature",
       x = "X coordinate",
       y = "Y coordinate") +
  theme(panel.grid.minor = element_blank())
