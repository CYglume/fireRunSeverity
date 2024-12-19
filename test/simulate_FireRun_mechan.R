# Try to test the manipulation of FireRun with its mechanism
# test with Terra
# For test only
# 

#Libaray
library(terra)

# Example with SpatRaster
r <- rast(nrows=10, ncols=10)
lines_r <- as.lines(r)
plot(lines_r)

# Example with SpatVector (e.g., polygons to lines)
v <- vect(system.file("ex/lux.shp", package="terra"))
lines_v <- as.lines(v)
v$ID_1

# Plotting the lines
plot(v)
plot(lines_v, col = "blue")

plot(buffer(v[v$ID_2 == 1,], width = 1), col = "lightgrey",
     xlim = c(5.85,6.1), ylim = c(49.95, 50.2))
par(new = T)
plot(buffer(lines_v[v$ID_2 == 1,], width = 1))

summary(geom(lines_v))
head(geom(as.points(lines_v)))

q = FireRuns::Edges(v, 3)
plot(v, xlim = c(ext(v)[1:2]), ylim = c(ext(v)[3:4]))
par(new = T)
plot(q,xlim = c(ext(v)[1:2]), ylim = c(ext(v)[3:4]), col = "blue")


nameFeho = "ID_2"
Polbuf <- buffer(v, width = 10)
plot(Polbuf, xlim = ext(Polbuf)[1:2], ylim = ext(Polbuf)[3:4])
Polbuf2 <- buffer(Polbuf, width = 0) 
plot(Polbuf2, xlim = ext(Polbuf)[1:2], ylim = ext(Polbuf)[3:4])
qq = v[2]
# par(new = T)
# plot(qq, xlim = ext(Polbuf)[1:2], ylim = ext(Polbuf)[3:4], col = "blue")
qq <- terra::as.lines(qq)
lines <- terra::intersect(qq, 
                          Polbuf[5, ])
plot(lines, xlim = ext(Polbuf)[1:2], ylim = ext(Polbuf)[3:4], col = "blue")
exists("lines")
# finalLines <- lines
finalLines <- rbind(finalLines, lines)

qq = v[2]
# par(new = T)
# plot(qq, xlim = ext(Polbuf)[1:2], ylim = ext(Polbuf)[3:4], col = "blue")
qq <- terra::as.lines(qq)
par(new = T)
plot(qq, xlim = ext(Polbuf)[1:2], ylim = ext(Polbuf)[3:4], col = "blue")
lines <- terra::intersect(qq, Polbuf[9, ])
lines
