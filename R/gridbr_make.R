#' Make standardized square grid.
#'
#' Make standardized square grid covering (\code{input}).
#' @param input object of class sf, sfc or sfg.
#' @param cellsize integer, in meters. Target cell size must be greater than 1.
#' @param equal_area logical. Set to TRUE if you want to use the original grid CRS, with an equal area projection.
#' @return standardized square grid
#' @export

gridbr_make <- function(input, cellsize, equal_area = FALSE) {

  # error: input class
  if (!any(class(input) %in% c("sf", "sfc", "sfg"))) stop("input must be of class simple features (sf)")

  # error: cell size
  if (cellsize < 1 & cellsize%%1==0) stop('cell size must be an integer and greater than 1.')

  # import gridbr crs
  gridbr_crs <- gridbr::gridbr_crs

  # save input crs
  input_crs <- sf::st_crs(input)

  # change input crs
  input <- sf::st_transform(input, crs = gridbr_crs)

  # error: input coverage
  if (sf::st_bbox(input)[[1]] < 2800000 |
      sf::st_bbox(input)[[2]] < 7350000 |
      sf::st_bbox(input)[[3]] > 2800000 + (10 * 500000) |
      sf::st_bbox(input)[[4]] > 7350000 + (10 * 500000)) {
    stop("the input is outside IBGE Statistical Grid coverage.")
  }

  # get bbox of simple features
  input <- sf::st_bbox(input)

  # fix bbox to match IBGE grid
  input[1] <- 2800000 + (floor((input[1] - 2800000) / cellsize) * cellsize)
  input[2] <- 7350000 + (floor((input[2] - 7350000) / cellsize) * cellsize)
  input[3] <- 2800000 + (ceiling((input[3] - 2800000) / cellsize) * cellsize)
  input[4] <- 7350000 + (ceiling((input[4] - 7350000) / cellsize) * cellsize)

  # bbox class to sf class
  input <- sf::st_as_sfc(input)

  # make the grid
  grid <- sf::st_make_grid(
    x = input,
    cellsize = cellsize,
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

  grid$gid <- paste0(
    ifelse(cellsize >= 1000, cellsize/1000, cellsize),
    ifelse(cellsize >= 1000, "KM", "M"),
    "E",
    floor(gridc[, 1]),
    "N",
    floor(gridc[, 2])
  )

  if (cellsize %in% c(500000, 100000, 50000, 10000, 5000, 1000)) {

    # recreate IBGE id
    grid$id <- paste0(
      cellsize/1000,
      "KM",
      "E",
      as.numeric(substr(formatC((2800000 + (floor((gridc[, 1] - 2800000) / cellsize) * cellsize)), width = 7, format = "d", flag = "0"), start = 1, stop = 4)),
      "N",
      as.numeric(substr(formatC((7350000 + (floor((gridc[, 2] - 7350000) / cellsize) * cellsize)), width = 8, format = "d", flag = "0"), start = 1, stop = 5))
    )

  }

  if(cellsize == 200) {

    # recreate IBGE id
    grid$id <- paste0(
      "200M",
      "E",
      as.numeric(substr(formatC((2800000 + (floor((gridc[, 1] - 2800000) / 200) * 200)), width = 7, format = "d", flag = "0"), start = 1, stop = 5)),
      "N",
      as.numeric(substr(formatC((7350000 + (ceiling((gridc[, 2] - 7350000) / 200) * 200)), width = 8, format = "d", flag = "0"), start = 1, stop = 6))
    )

  }

  grid <- rbind(grid)

  ##### equal_area parameter ----
  if (equal_area == FALSE) {
    grid <- sf::st_transform(grid, input_crs)
  }

  ##### export final object ----
  return(grid)

}
