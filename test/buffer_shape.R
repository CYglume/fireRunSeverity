# Load required libraries
library(terra)
library(ggplot2)

# Create a sample point
pt <- vect(cbind(0, 0), crs="epsg:3857")

# Create buffers with different quadsegs values
buffers <- list()
quad_values <- c(1, 4, 8, 30)

for(q in quad_values) {
  buf <- buffer(pt, width = 1, quadsegs = q)
  buffers[[length(buffers) + 1]] <- buf
}

# Convert to dataframes for plotting
plot_data <- data.frame()
for(i in seq_along(buffers)) {
  # Extract coordinates
  coords <- crds(as.lines(buffers[[i]]))
  df <- as.data.frame(coords)
  df$quadsegs <- paste("quadsegs =", quad_values[i])
  plot_data <- rbind(plot_data, df)
}

# Create plot
ggplot(plot_data, aes(x = x, y = y)) +
  geom_path() +
  geom_point(data = data.frame(x = 0, y = 0), color = "red", size = 3) +
  facet_wrap(~quadsegs, ncol = 2) +
  coord_fixed() +
  theme_minimal() +
  labs(title = "Buffer Shapes with Different quadsegs Values",
       subtitle = "Red point shows the original point location",
       x = "X coordinate",
       y = "Y coordinate") +
  theme(panel.grid.minor = element_blank())
