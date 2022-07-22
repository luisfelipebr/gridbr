#' Download IBGE statistical grid with population census data.
#'
#' Make IBGE statistical grid covering (\code{input}) and merge with population census data.
#' @param input object of class sf, sfc or sfg.
#' @param cellsize target cell size. Must be one of: "500KM", "100KM", "50KM", "10KM", "5KM", "1KM" and "200M".
#' @param census_data logical. Set to FALSE if you don't want to include population census data.
#' @param equal_area logical. Set to TRUE if you want to use the original grid CRS, with an equal area projection.
#' @return IBGE statistical grid
#' @export

gridbr_download <- function(input, cellsize, census_data = TRUE, equal_area = FALSE) {

  # error: input class
  if (!any(class(input) %in% c("sf", "sfc", "sfg"))) stop("input must be of class simple features (sf)")

  # message: internet connection
  if (suppressWarnings(tryCatch(
    {
      readLines("http://example.com/", n = 1)
    },
    error = function(e) FALSE
  )) == FALSE & "gridbr.data" %in% utils::installed.packages() == FALSE) {
    message("couldn't connect to the internet. Population census data will not be loaded.")
    census_data <- FALSE
  }

  # message: gridbr.data
  if ("gridbr.data" %in% utils::installed.packages() == FALSE) message("population census data can be loaded faster by installing the package 'gridbr.data'. See https://www.github.com/luisfelipebr/gridbr.data")

  # create cell sizes support vector
  cellsizes <- c("200M", "1KM", "5KM", "10KM", "50KM", "100KM", "500KM")

  # error: cell size
  if (!cellsize %in% cellsizes) stop('cell size must be equal to one of the following values: "500KM", "100KM", "50KM", "10KM", "5KM", "1KM" or "200M"')

  # import gridbr crs
  gridbr_crs <- gridbr::gridbr_crs

  # save input crs
  input_crs <- sf::st_crs(input)

  ##### MAIN FUNCTION - BUILD GRID ----

  # change input crs
  input <- sf::st_transform(input, crs = gridbr_crs)

  # error: input coverage
  if (sf::st_bbox(input)[[1]] < 2800000 |
    sf::st_bbox(input)[[2]] < 7350000 |
    sf::st_bbox(input)[[3]] > 2800000 + (10 * 500000) |
    sf::st_bbox(input)[[4]] > 7350000 + (10 * 500000)) {
    stop("the input is outside IBGE Statistical Grid coverage.")
  }

  if (cellsize == "200M") {
    ##### 200M cellsize rule ----

    ##### PART 1 - 200M ----

    # get bbox of simple features
    input1 <- sf::st_bbox(input)

    # standardize bbox
    input1[1] <- 2800000 + (floor((input1[1] - 2800000) / 1000) * 1000)
    input1[2] <- 7350000 + (floor((input1[2] - 7350000) / 1000) * 1000)
    input1[3] <- 2800000 + (ceiling((input1[3] - 2800000) / 1000) * 1000)
    input1[4] <- 7350000 + (ceiling((input1[4] - 7350000) / 1000) * 1000)

    # bbox class to sf class
    input1 <- sf::st_as_sfc(input1)

    # make the grid
    grid1 <- sf::st_make_grid(
      x = input1,
      cellsize = 200,
      crs = gridbr_crs,
      what = "polygons",
      square = TRUE,
      flat_topped = FALSE
    )

    # create a support dataset, to create id
    grid1c <- sf::st_coordinates(suppressWarnings(sf::st_centroid(grid1)))

    # grid class to sf (again)
    grid1 <- sf::st_as_sf(grid1)

    # rename geometry to geom
    sf::st_geometry(grid1) <- "geom"

    # recreate the IBGE id
    grid1$id <- paste0(
      "200M",
      "E",
      as.numeric(substr(formatC((2800000 + (floor((grid1c[, 1] - 2800000) / 200) * 200)), width = 7, format = "d", flag = "0"), start = 1, stop = 5)),
      "N",
      as.numeric(substr(formatC((7350000 + (ceiling((grid1c[, 2] - 7350000) / 200) * 200)), width = 8, format = "d", flag = "0"), start = 1, stop = 6))
    )

    grid1 <- grid1[grid1$id %in% gridbr::gridbr_urban, ]

    ##### PART 2 - 1KM ----

    # get bbox of simple features
    input2 <- sf::st_bbox(input)

    # fix bbox to match IBGE grid
    input2[1] <- 2800000 + (floor((input2[1] - 2800000) / 1000) * 1000)
    input2[2] <- 7350000 + (floor((input2[2] - 7350000) / 1000) * 1000)
    input2[3] <- 2800000 + (ceiling((input2[3] - 2800000) / 1000) * 1000)
    input2[4] <- 7350000 + (ceiling((input2[4] - 7350000) / 1000) * 1000)

    # bbox class to sf class
    input2 <- sf::st_as_sfc(input2)

    # make the grid
    grid2 <- sf::st_make_grid(
      x = input2,
      cellsize = 1000,
      crs = gridbr_crs,
      what = "polygons",
      square = TRUE,
      flat_topped = FALSE
    )

    # grid class to sf (again)
    grid2 <- sf::st_as_sf(grid2)

    # rename geometry to geom
    sf::st_geometry(grid2) <- "geom"

    # get only outside intersection
    inters <- lengths(sf::st_intersects(suppressWarnings(sf::st_centroid(grid2)), suppressWarnings(sf::st_centroid(grid1)))) > 0
    grid2 <- grid2[!inters, ]

    # create a support dataset, to create id
    grid2c <- sf::st_coordinates(suppressWarnings(sf::st_centroid(grid2)))

    # recreate the IBGE id
    grid2$id <- paste0(
      "1KM",
      "E",
      as.numeric(substr(formatC((2800000 + (floor((grid2c[, 1] - 2800000) / 1000) * 1000)), width = 7, format = "d", flag = "0"), start = 1, stop = 4)),
      "N",
      as.numeric(substr(formatC((7350000 + (floor((grid2c[, 2] - 7350000) / 1000) * 1000)), width = 8, format = "d", flag = "0"), start = 1, stop = 5))
    )

    grid <- rbind(grid1, grid2)
  } else {

    #### KM cellsize rule ----

    # create support cell size object (numeric)
    cellsize2 <- as.numeric(gsub(
      pattern = "KM",
      replacement = "000",
      x = cellsize
    ))

    # get bbox of simple features
    input <- sf::st_bbox(input)

    # fix bbox to match IBGE grid
    input[1] <- 2800000 + (floor((input[1] - 2800000) / cellsize2) * cellsize2)
    input[2] <- 7350000 + (floor((input[2] - 7350000) / cellsize2) * cellsize2)
    input[3] <- 2800000 + (ceiling((input[3] - 2800000) / cellsize2) * cellsize2)
    input[4] <- 7350000 + (ceiling((input[4] - 7350000) / cellsize2) * cellsize2)

    # bbox class to sf class
    input <- sf::st_as_sfc(input)

    # make the grid
    grid <- sf::st_make_grid(
      x = input,
      cellsize = cellsize2,
      crs = gridbr_crs,
      what = "polygons",
      square = TRUE,
      flat_topped = FALSE
    )

    # create a support dataset, to create id
    gridc <- sf::st_coordinates(suppressWarnings(sf::st_centroid(grid)))

    # grid class to sf (again)
    grid <- sf::st_as_sf(grid)

    # rename geometry to geom
    sf::st_geometry(grid) <- "geom"

    # recreate IBGE id
    grid$id <- paste0(
      cellsize,
        "E",
        as.numeric(substr(formatC((2800000 + (floor((gridc[, 1] - 2800000) / cellsize2) * cellsize2)), width = 7, format = "d", flag = "0"), start = 1, stop = 4)),
        "N",
        as.numeric(substr(formatC((7350000 + (floor((gridc[, 2] - 7350000) / cellsize2) * cellsize2)), width = 8, format = "d", flag = "0"), start = 1, stop = 5))
      )

    grid <- rbind(grid)
  }

  ##### census_data parameter ----
  if (census_data == TRUE) {
    j <- 1

    data <- list()

    for (i in cellsizes) {
      cs <- any(grepl(pattern = i, x = grid$id))

      if (cs == TRUE) {

        # download or get from package, IBGE census data
        if (requireNamespace("gridbr.data", quietly = TRUE)) {
          assign(paste0("gridbr_", i), eval(parse(text = paste0("gridbr.data::gridbr_", i))))
        } else {
          utils::download.file(paste0("https://github.com/luisfelipebr/gridbr.data/raw/master/data/gridbr_", i, ".rda"), "inst/Temp")
          load("inst/Temp")
        }

        data[j] <- mget(paste0("gridbr_", i))

        j <- j + 1
      }
    }

    data <- do.call(rbind, data)

    # merge data with grid
    grid <- base::merge(grid, data, by = "id", all.x = TRUE)

    # remove na's
    grid$MASC <- ifelse(is.na(grid$MASC), 0, grid$MASC)
    grid$FEM <- ifelse(is.na(grid$FEM), 0, grid$FEM)
    grid$POP <- ifelse(is.na(grid$POP), 0, grid$POP)
    grid$DOM_OCU <- ifelse(is.na(grid$DOM_OCU), 0, grid$DOM_OCU)
  }

  ##### equal_area parameter ----
  if (equal_area == FALSE) {
    grid <- sf::st_transform(grid, input_crs)
  }

  ##### export final object ----
  return(grid)
}
