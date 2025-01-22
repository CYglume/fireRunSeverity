Runs2 <- function(AllPols, CRSproject=terra::crs(AllPols), nameID, nameFeho, WindTablexHour=NULL, flagRuns='both', CreateSharedFrontLines='T') {
  # Create an hourID code in WindTable
  if (!is.null(WindTablexHour)) {
    HourID <- data.frame(names(table(AllPols[[nameFeho]])))
    names(HourID)[1] <- nameFeho
    HourID$codi_hora_T <- seq(from = 1, to = (nrow(HourID)))
    WindTablexHour <- merge(WindTablexHour, HourID, by.x = "codi_hora", by.y = "codi_hora_T")
  }

  # if no wind table, create a fake one to continue, but only create pols runs
  if (is.null(WindTablexHour)) {
    HourID <- data.frame(names(table(AllPols[[nameFeho]])))
    names(HourID)[1] <- nameFeho
    HourID$codi_hora_T <- seq(from = 1, to = (nrow(HourID)))
    WindTablexHour <- cbind(HourID, Wind = c(0))
    names(WindTablexHour) <- c(nameFeho, "codi_hora", "Wind")
    flagRuns <- "pols"
  }

  # Add HourID to AllPols
  AllPolsWithHours <- merge(AllPols, WindTablexHour, by.x = paste(nameFeho), by.y = paste(nameFeho))
  AllPolsWithHours$codi_hora <- as.numeric(as.character(AllPolsWithHours$codi_hora))
  AllPolsWithHours <- terra::buffer(AllPolsWithHours, width = 0) # to help topology

  # Create or read file with fronts
  if (CreateSharedFrontLines == T) {
    SharedFrontLines <- Edges(AllPolsWithHours, nameFeho)
    SharedFrontLines$MinCode <- as.numeric(as.character(SharedFrontLines$codi_hora_1)) # assign the "from" hour to the front
    SharedFrontLines <- SharedFrontLines[, which(names(SharedFrontLines) %in% "MinCode")] # select only MinCode column
    terra::writeVector(SharedFrontLines, filename = "SharedFrontLines.shp", filetype = "ESRI Shapefile", overwrite = TRUE)
  }
  if (CreateSharedFrontLines == F) {
    SharedFrontLines <- terra::vect("SharedFrontLines.shp")
  }

  # Perform the algorithm per hour
  Nameslist <- list() # prepare empty file before the loop
  Nameslist_pol <- list() # prepare empty file before the loop
  for (i in 1:max(terra::na.omit(AllPolsWithHours$codi_hora))) {
    print(paste0("hour=", i))

    # get wind direction and + - 5
    DirWind <- WindTablexHour$Wind[which(WindTablexHour$codi_hora == i)]
    DirWindRun <- ifelse(DirWind - 180 < 0, DirWind + 180, DirWind - 180) # convert the "from" type of wind direction to "to" type
    DirWindLow <- ifelse(DirWindRun - 5 < 0, 360 - abs(DirWindRun - 5), DirWindRun - 5)
    DirWindHigh <- ifelse(DirWindRun + 5 > 360, abs(360 - (DirWindRun + 5)), DirWindRun + 5)

    # get poligons in that hour
    PolsHour <- AllPolsWithHours[which(AllPolsWithHours$codi_hora == i), ]
    Polsbuf <- terra::buffer(PolsHour, width = 5) # make a 5 meter buffer to ensure intersections

    # Get fronts that touch the polygons in that hour
    IntersectingFronts <- terra::intersect(SharedFrontLines, Polsbuf)

    # test whether the polygon is an isolated polygon or sequential one
    if (all(terra::na.omit(unique(IntersectingFronts$MinCode)) >= i)) {
      Isolated <- T
    } else {
      Isolated <- F
    }

    # perform the algorithm for the isolated polygon
    if (Isolated == T) {
      # Transform polygons to lines so we obtain the edge of polygon (current front)
      Pols2lines <- terra::as.lines(PolsHour)
      # prepare and perform loop for each polygon
      PerPoligonMaxims_wind <- c() # prepare empty file before the loop
      PerPoligonMaxims_pol <- c() # prepare empty file before the loop
      getFIDS <- PolsHour[[nameID, drop = T]] # get unique IDs
      for (j in unique(getFIDS)) {
        print(paste0("pol=", j))

        # MinFront represent all numbers of previous fronts. In this case the same as the front because there is no previous front
        MinFront <- i

        # get pols with corresponding ID
        pol_id <- Pols2lines[which(Pols2lines[[nameID]] == j), ]
        pol_idpol <- PolsHour[which(PolsHour[[nameID]] == j), ]
        area_pol <- sum(terra::expanse(pol_idpol) / 10000) # get area of the polygon, in hectares
        DistFront <- 0.001 # get the distance of previous front. In this case, since there is not previous front, this is tiny, 1 meter

        # To evaluate runs intersection with the pol, a wider (5m) polygon without holes is created
        pol_idbuff <- terra::buffer(pol_idpol, width = 5)
        Noholes <- terra::fillHoles(pol_idbuff)

        # convert polygon to points
        p <- terra::as.points(pol_id)
        # calculate distances between all points
        dist <- terra::distance(p, pairs = T)
        # create DF and calculate direction of the runs. two directions because there is no "to from'
        distCoord <- merge(dist, terra::geom(p)[, c(1, 3, 4)], by.x = "from", by.y = "geom")
        distCoord <- merge(distCoord, terra::geom(p)[, c(1, 3, 4)], by.x = "to", by.y = "geom")
        distCoord$Deg1 <- DegreesFireRun(distCoord$x.x, distCoord$x.y, distCoord$y.x, distCoord$y.y)
        distCoord$Deg2 <- DegreesFireRun(distCoord$x.y, distCoord$x.x, distCoord$y.y, distCoord$y.x)

        if (flagRuns %in% c("both", "wind")) {

          # select runs in wind direction +-5.
          if (DirWindLow >= 355 | DirWindHigh <= 5) {
            RunsWindDir <- distCoord[which((distCoord$Deg1 >= DirWindLow | distCoord$Deg1 <= DirWindHigh |
                                              distCoord$Deg2 >= DirWindLow | distCoord$Deg2 <= DirWindLow)), ]
          } else {
            RunsWindDir <- distCoord[which((distCoord$Deg1 >= DirWindLow & distCoord$Deg1 <= DirWindHigh) |
                                             (distCoord$Deg2 >= DirWindLow & distCoord$Deg2 <= DirWindHigh)), ]
          }

          # Select maximum distance that does not intersect with the polygon (while loop)
          condition <- T
          # first stop if there are no runs in wind direction
          if (nrow(RunsWindDir) == 0) {
            condition <- F
          }
          while (condition == T & nrow(RunsWindDir) > 0) {
            # calculate maximum distance in the wind direction. In case there is more than one, select the first
            MaximumDistance <- RunsWindDir[which(RunsWindDir$value == max(RunsWindDir$value)), ][1, ]

            # obtain coordinates for that point and create line
            Inner <- MaximumDistance[, c("x.x", "y.x")]
            names(Inner) <- c("x", "y")
            Outer <- MaximumDistance[, c("x.y", "y.y")]
            names(Outer) <- c("x", "y")
            xy <- as.matrix(rbind(Inner, Outer))
            LinXY <- terra::vect(xy, "lines", crs = CRSproject)

            # check if the run is within the polygon or intersects
            Relation <- terra::relate(LinXY, Noholes, relation = "within")

            # if it is not fully within remove from table and continue while
            if (all(Relation == F)) {
              condition <- T
              RunsWindDir <- RunsWindDir[which(!(RunsWindDir$to %in% MaximumDistance$to &
                                                   RunsWindDir$from %in% MaximumDistance$from)), ]
            }

            # if it is fully within stop while and create new table
            if (any(Relation == T)) {
              condition <- F
              # We want only one 'degree' column. Here we select the appropiate:
              Degs <- ifelse(MaximumDistance$Deg1 <= DirWindHigh & MaximumDistance$Deg1 >= DirWindLow, "Deg2", "Deg1")
              MaximumDistance <- MaximumDistance[, !(names(MaximumDistance) %in% Degs)]
              MakeTable <- data.frame(cbind(i, j, OrgFrnt = MinFront[1], MaximumDistance, area_pol, DistFront))
              names(MakeTable) <- c(
                "Hour", "ID", "OriginFront", "PointTo", "PointFrom", "Distance", "CoordXFrom", "CoordYFrom",
                "CoordXTo", "CoordYTo", "DirectionDegrees", "Area_ha", "DistFront"
              )
            }
          } # end while
          # in case there is no minimum table, create empty one
          if (!exists("MakeTable")) {
            MakeTable <- data.frame(cbind(i, j,
                                          OrgFrnt = MinFront[1], Var2 = 0, Var1 = 0,
                                          value = 0, x.x = 0, y.x = 0, x.y = 0, y.y = 0, Deg = 0, area_pol, DistFront
            ))
            names(MakeTable) <- c(
              "Hour", "ID", "OriginFront", "PointTo", "PointFrom", "Distance", "CoordXFrom", "CoordYFrom",
              "CoordXTo", "CoordYTo", "DirectionDegrees", "Area_ha", "DistFront"
            )
          }

          # stick each run from the different polygons within an hour
          PerPoligonMaxims_wind <- rbind(PerPoligonMaxims_wind, MakeTable)
          rm(MakeTable)
        } # end wind section

        if (flagRuns %in% c("both", "pols")) {
          # Select maximum distance that does not intersect with the polygon (while loop)
          condition_pol <- T
          while (condition_pol == T) {
            # calculate maximum distance from outer to inner point in the whole polygon
            MaximumDistance_pol <- distCoord[which(distCoord$value == max(distCoord$value)), ][1, ]

            # obtain coordinates for that point and create line
            Inner <- MaximumDistance_pol[, c("x.x", "y.x")]
            names(Inner) <- c("x", "y")
            Outer <- MaximumDistance_pol[, c("x.y", "y.y")]
            names(Outer) <- c("x", "y")
            xy <- as.matrix(rbind(Inner, Outer))
            LinXY <- terra::vect(xy, "lines", crs = CRSproject)

            # check if the run is within the polygon or intersects
            Relation <- terra::relate(LinXY, Noholes, relation = "within")

            # if it is not fully within remove from table and continue while
            if (all(Relation == F)) {
              condition_pol <- T
              distCoord <- distCoord[which(!(distCoord$to %in% MaximumDistance_pol$to &
                                               distCoord$from %in% MaximumDistance_pol$from)), ]
            }

            # if it is fully within stop while and create new table
            if (any(Relation == T)) {
              condition_pol <- F
              Degs <- "Deg1" ## no sense to select one direction or the other, so arbitrary we select the first one
              MaximumDistance_pol <- MaximumDistance_pol[, !(names(MaximumDistance_pol) %in% Degs)]
              MakeTable_pol <- data.frame(cbind(i, j, OrgFrnt = MinFront[1], MaximumDistance_pol, area_pol, DistFront))
              names(MakeTable_pol) <- c(
                "Hour", "ID", "OriginFront", "PointTo", "PointFrom", "Distance", "CoordXFrom", "CoordYFrom",
                "CoordXTo", "CoordYTo", "DirectionDegrees", "Area_ha", "DistFront"
              )
            }
          } # end while

          PerPoligonMaxims_pol <- rbind(PerPoligonMaxims_pol, MakeTable_pol)
          rm(MakeTable_pol)
        } # end pol section
      } # end per polygon loop
    } # end isolated polygon

    # if it is a non-isolated polygon
    if (Isolated == F) {
      # Get MinFronts. Whatever previous front that touches that polygon
      MinFront <- unique(IntersectingFronts$MinCode)[which(unique(IntersectingFronts$MinCode) < i)]
      # select fronts in contact with the polygon (buffered one)
      IntersectingFrontsMinFront <- terra::intersect(SharedFrontLines[which(SharedFrontLines$MinCode < i)], Polsbuf)
      # convert polygons to lines to get info from the polygon edge
      Pols2lines <- terra::as.lines(PolsHour)

      # prepare and perform loop for each polygon
      PerPoligonMaxims_wind <- c() # prepare empty file before the loop
      PerPoligonMaxims_pol <- c() # prepare empty file before the loop
      getFIDS <- PolsHour[[nameID, drop = T]] # get unique IDs
      for (j in unique(getFIDS)) {
        print(paste0("pol=", j))

        # get the polygon-line and polygon with that ID
        Pols2lines_id <- Pols2lines[which(Pols2lines[[nameID]] == j), ]
        Pols_id <- PolsHour[which(PolsHour[[nameID]] == j), ]
        area_pol <- sum(terra::expanse(Pols_id) / 10000) # obtain area of the pol in hectares

        # in case there is a line-front touching that polygon continue, if not do not calculate anything else
        if (j %in% IntersectingFrontsMinFront[[nameID, drop = T]]) {
          # get lines touching that polygon
          line_id <- IntersectingFrontsMinFront[which(IntersectingFrontsMinFront[[nameID]] == j), ]
          DistFront <- sum(terra::perim(line_id) / 1000) # obtain length of previous front in km

          # Prepare Noholes polygon (buffer of 5 meters) to intersect with runs
          # First, check whether the front is lateral or completely within the polygon. If it is within, the hole will be kept
          NoholesFrontInside <- terra::fillHoles(Pols_id)
          if (all(terra::relate(NoholesFrontInside, line_id, relation = "contains"))) {
            NoholesFrontInside <- terra::buffer(NoholesFrontInside, width = 5)
            NoholesFrontInside <- remove.holes.withinFront(NoholesFrontInside, line_id)
          } else {
            NoholesFrontInside <- terra::buffer(NoholesFrontInside, width = 5)
          }

          # obtain points for the front and the previous front. remove coincident points of the polygon, so only 'front' points are kept
          p2 <- terra::as.points(line_id)
          p3 <- terra::as.points(Pols2lines_id)
          Geomp2 <- signif(as.data.frame(terra::geom(p2)), digits = 8)
          Geomp3 <- signif(as.data.frame(terra::geom(p3)), digits = 8)
          Covered <- Geomp3[!(Geomp3$x %in% Geomp2$x & Geomp3$y %in% Geomp2$y), ]
          CoveredLine <- terra::vect(as.matrix(Covered[, c(3, 4)]), "points", crs = CRSproject)

          # in case there is a points continue, if not do not calculate anything else
          if (nrow(Geomp2) >= 1 & nrow(Geomp3) >= 1 & nrow(Covered)>=1) {
            # calculate distances between front points and previous front points
            dist <- as.data.frame(terra::distance(p2, CoveredLine))
            row.names(dist) <- 1:length(p2)
            names(dist) <- 1:length(CoveredLine)
            MeltedDist <- reshape2::melt(as.matrix(dist))

            # build DF with coordinates and calculate direction of the runs
            distCoord <- merge(MeltedDist, geom(p2)[, c(1, 3, 4)], by.x = "Var1", by.y = "geom")
            GeometriesCovered<-data.frame(rbind(geom(CoveredLine)[, c(1, 3, 4)])); GeometriesCovered$geom<-as.integer(GeometriesCovered$geom)
            distCoord <- merge(distCoord, GeometriesCovered, by.x = "Var2", by.y = "geom")
            distCoord$Deg <- DegreesFireRun(distCoord$x.x, distCoord$x.y, distCoord$y.x, distCoord$y.y)

            if (flagRuns %in% c("both", "wind")) {
              # select runs in wind direction +-5
              if (DirWindLow >= 355 | DirWindHigh <= 5) {
                RunsWindDir <- distCoord[which(distCoord$Deg >= DirWindLow | distCoord$Deg <= DirWindHigh), ]
              } else {
                RunsWindDir <- distCoord[which(distCoord$Deg >= DirWindLow & distCoord$Deg <= DirWindHigh), ]
              }

              # Select maximum distance that does not intersect with the polygon (while loop)
              condition <- T
              # first stop if there are no runs in wind direction
              if (nrow(RunsWindDir) == 0) {
                condition <- F
              } # in case no runs in wind direction
              while (condition == T & nrow(RunsWindDir) > 0) {
                # calculate maximum distance in the wind direction. In case more than one select the first
                MaximumDistance <- RunsWindDir[which(RunsWindDir$value == max(RunsWindDir$value)), ][1, ]

                # obtain coordinates for that point and create line
                Inner <- MaximumDistance[, c("x.x", "y.x")]
                names(Inner) <- c("x", "y")
                Outer <- MaximumDistance[, c("x.y", "y.y")]
                names(Outer) <- c("x", "y")
                xy <- as.matrix(rbind(Inner, Outer))
                LinXY <- terra::vect(xy, "lines", crs = CRSproject)

                # check if the run is within the polygon or intersects
                Relation <- terra::relate(LinXY, NoholesFrontInside, relation = "within")

                # if it is not fully within remove from table and continue while
                if (all(Relation == F)) {
                  condition <- T
                  RunsWindDir <- RunsWindDir[which(!(RunsWindDir$Var2 %in% MaximumDistance$Var2 &
                                                       RunsWindDir$Var1 %in% MaximumDistance$Var1)), ]
                }
                if (any(Relation == T)) {
                  condition <- F
                  MakeTable <- data.frame(cbind(i, j, OrgFrnt = MinFront[1], MaximumDistance, area_pol, DistFront))
                  names(MakeTable) <- c(
                    "Hour", "ID", "OriginFront", "PointTo", "PointFrom", "Distance", "CoordXFrom", "CoordYFrom",
                    "CoordXTo", "CoordYTo", "DirectionDegrees", "Area_ha", "DistFront"
                  )
                }
              } # end while
              # in case there is no minimum table, create empty one
              if (!exists("MakeTable")) {
                MakeTable <- data.frame(cbind(i, j,
                                              OrgFrnt = MinFront[1], Var2 = 0, Var1 = 0,
                                              value = 0, x.x = 0, y.x = 0, x.y = 0, y.y = 0, Deg = 0, area_pol, DistFront
                ))
                names(MakeTable) <- c(
                  "Hour", "ID", "OriginFront", "PointTo", "PointFrom", "Distance", "CoordXFrom", "CoordYFrom",
                  "CoordXTo", "CoordYTo", "DirectionDegrees", "Area_ha", "DistFront"
                )
              }
              # stick each run from the different polygons within an hour
              PerPoligonMaxims_wind <- rbind(PerPoligonMaxims_wind, MakeTable)
              rm(MakeTable)
            } # end wind section

            if (flagRuns %in% c("both", "pols")) {
              # select the previous front point that is closest to the front point
              MinDFperOuter <- c() # prepare empty file before the loop
              for (k in unique(MeltedDist$Var2)) { # per front point
                DFperOuter <- distCoord[which(distCoord$Var2 == k), ]

                # Select maximum distance that does not intersect with the polygon (while loop)
                condition_pol <- T
                while (condition_pol == T & nrow(DFperOuter) > 0) {
                  # calculate maximum distance from outer to inner point in the whole polygon
                  MaximumDistance_pol <- DFperOuter[which(DFperOuter$value == min(DFperOuter$value)), ][1, ]

                  # obtain coordinates for that point and create line
                  Inner <- MaximumDistance_pol[, c("x.x", "y.x")]
                  names(Inner) <- c("x", "y")
                  Outer <- MaximumDistance_pol[, c("x.y", "y.y")]
                  names(Outer) <- c("x", "y")
                  xy <- as.matrix(rbind(Inner, Outer))
                  LinXY <- terra::vect(xy, "lines", crs = CRSproject)

                  # check if the run is within the polygon or intersects
                  Relation <- terra::relate(LinXY, NoholesFrontInside, relation = "within")

                  # if it is not fully within remove from table and continue while
                  if (all(Relation == F)) {
                    condition_pol <- T
                    DFperOuter <- DFperOuter[which(!(DFperOuter$Var1 %in% MaximumDistance_pol$Var1 &
                                                       DFperOuter$Var2 %in% MaximumDistance_pol$Var2)), ]
                  }

                  # if it is fully within stop while
                  if (any(Relation == T)) {
                    condition_pol <- F
                    MakeTable_pol <- data.frame(cbind(i, j, OrgFrnt = MinFront[1], MaximumDistance_pol, area_pol, DistFront))
                    names(MakeTable_pol) <- c(
                      "Hour", "ID", "OriginFront", "PointTo", "PointFrom", "Distance", "CoordXFrom", "CoordYFrom",
                      "CoordXTo", "CoordYTo", "DirectionDegrees", "Area_ha", "DistFront"
                    )
                  }
                } # end while
                # in case there is no minimum table, create empty one
                if (!exists("MakeTable_pol")) {
                  MakeTable_pol <- data.frame(cbind(i, j,
                                                    OrgFrnt = MinFront[1], Var2 = k, Var1 = 0,
                                                    value = 0, x.x = 0, y.x = 0, x.y = 0, y.y = 0, Deg = 0, area_pol, DistFront
                  ))
                  names(MakeTable_pol) <- c(
                    "Hour", "ID", "OriginFront", "PointTo", "PointFrom", "Distance", "CoordXFrom", "CoordYFrom",
                    "CoordXTo", "CoordYTo", "DirectionDegrees", "Area_ha", "DistFront"
                  )
                }
                # stick each front run in a common DF
                MinDFperOuter <- rbind(MinDFperOuter, MakeTable_pol)
                rm(MakeTable_pol)
              } # end for front point
              # select maximum run, if there is more than one, only the first
              PerOuterMaximum <- MinDFperOuter[which(MinDFperOuter$Distance == max(MinDFperOuter$Distance)), ][1, ]
              # stick maximum runs of all pols in a single DF
              PerPoligonMaxims_pol <- rbind(PerPoligonMaxims_pol, PerOuterMaximum)
            } # end pol section
          } # end if points exists
        } # if end line and pols intersect
      } # end per polygon loop
    } # end non-isolated hour-polygon


    # Within the hour, select the maximum run, create a line and store the line in a list
    # for the wind runs
    if (flagRuns %in% c("both", "wind")) {
      if (!is.null(nrow(PerPoligonMaxims_wind))) { # continue only if there is a Run, if not stop
        for (polygon in 1:nrow(PerPoligonMaxims_wind)){
          # Createline
          Inner <- PerPoligonMaxims_wind[polygon, c("CoordXFrom", "CoordYFrom")]
          names(Inner) <- c("x", "y")
          Outer <- PerPoligonMaxims_wind[polygon, c("CoordXTo", "CoordYTo")]
          names(Outer) <- c("x", "y")
          xy <- as.matrix(rbind(Inner, Outer))
          LinXY <- terra::vect(xy, "lines", crs = CRSproject, atts = PerPoligonMaxims_wind[polygon, c(1, 2, 3, 6, 11, 12, 13)])
          Nameslist[[length(Nameslist) + 1]] <- LinXY
        }#end create wind lines
      } # end if there is a run
    } # end wind

    # for the pols run
    if (flagRuns %in% c("both", "pols")) {
      if (!is.null(nrow(PerPoligonMaxims_pol))) { # continue only if there is a Run, if not stop
        # Select Maximum Run in all polygons. The first if there is more than one.
        for (polygon in 1:nrow(PerPoligonMaxims_pol)){
          # Createline
          Inner <- PerPoligonMaxims_pol[polygon, c("CoordXFrom", "CoordYFrom")]
          names(Inner) <- c("x", "y")
          Outer <- PerPoligonMaxims_pol[polygon, c("CoordXTo", "CoordYTo")]
          names(Outer) <- c("x", "y")
          xy <- as.matrix(rbind(Inner, Outer))
          LinXY_pol <- terra::vect(xy, "lines", crs = CRSproject, atts = PerPoligonMaxims_pol[polygon, c(1, 2, 3, 6, 11, 12, 13)])
          Nameslist_pol[[length(Nameslist_pol) + 1]] <- LinXY_pol
        } #end create polygon lines
      } # end if there is a run
    } # end runspol
  } # end loop per hour


  DirOutputs <- "outputs/"
  # check if sub directory exists
  if (!file.exists(DirOutputs)) {
    dir.create(file.path(DirOutputs), showWarnings = FALSE)
  }

  # finally write shapefiles
  if (flagRuns %in% c("both", "wind")) {
    Nameslist[sapply(Nameslist, is.null)] <- NULL
    TotLinesWind <- do.call(rbind, Nameslist)
    terra::writeVector(TotLinesWind, filename = "outputs/FullRunsWind.shp", filetype = "ESRI shapefile", overwrite = T)
  }

  if (flagRuns %in% c("both", "pols")) {
    Nameslist_pol[sapply(Nameslist_pol, is.null)] <- NULL
    TotLinesPol <- do.call(rbind, Nameslist_pol)
    terra::writeVector(TotLinesPol, filename = "outputs/FullRunsPol.shp", filetype = "ESRI shapefile", overwrite = T)
  }
}


