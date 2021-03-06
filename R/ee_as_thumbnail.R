#' Create a stars object based on an EE thumbnail image
#'
#' Download EE thumbnail images and read them as star objects.
#' This function is a wrapper around \code{ee$Image()$getThumbURL()}.
#'
#' @param x EE Image object
#' @param region EE Geometry Rectangle (ee$Geometry$Rectangle). The
#' CRS needs to be the same as the x argument, otherwise, it will be
#' forced. If not specified, image bounds will be taken.
#' @param dimensions A number or pair of numbers in format XY.
#' @param vizparams A list that contains the visualization parameters.
#' @param geodesic Whether line segments of region should be interpreted as
#' spherical geodesics. If FALSE, indicates that line segments should be
#' interpreted as planar lines in the specified CRS. If not specified in
#' the geometry (region argument), defaults to TRUE if the CRS is geographic
#' (including the default EPSG:4326), or to FALSE if the CRS is projected.
#' @param evenOdd If TRUE, polygon interiors will be determined by
#' the even/odd rule, where a point is inside if it crosses an odd
#' number of edges to reach a point at infinity. Otherwise polygons
#' use the left-inside rule, where interiors are on the left side
#' of the shell's edges when walking the vertices in the given order.
#' If unspecified in the geometry (region argument) defaults to TRUE.
#' @param quiet logical; suppress info messages.
#' @details
#'
#' The argument dimensions will define the stars object parameters
#' "from" & "to". It must be a single numeric value or a two-element vector.
#' If not defined, 256 is taken by default as the dimension of x
#' (from 1 to 256), and y scales down proportionally. Large images
#' might cause plodding connections. See
#' \href{https://developers.google.com/earth-engine/client_server}{Client vs
#' Server} for more details.
#'
#' The vizparams set up the number of bands up. In `ee_as_thumbnail` just is
#' possible export only one (G) or three-band (RGB) images. Additional
#' parameters can be passed on to control color, intensity, the maximum and
#' minimum values, etc. The below table provides all the parameters that
#' admit `ee_as_thumbnail`.
#'
#' \tabular{lll}{
#' \strong{Parameter} \tab \strong{Description} \tab \strong{Type}\cr
#' \strong{bands}     \tab Comma-delimited list of
#' three band names to be mapped to RGB \tab  list \cr
#' \strong{min}       \tab  Value(s) to map to 0 \tab
#' number or list of three numbers, one for each band \cr
#' \strong{max}       \tab  Value(s) to map to 1 \tab
#' number or list of three numbers, one for each band \cr
#' \strong{gain}      \tab  Value(s) by which to multiply each pixel value \tab
#' number or list of three numbers, one for each band \cr
#' \strong{bias}      \tab  Value(s) to add to each Digital Number (DN)
#' value \tab number or list of three numbers, one for each band \cr
#' \strong{gamma}     \tab  Gamma correction factor(s) \tab
#' number or list of three numbers, one for each band \cr
#' \strong{palette}  \tab  List of CSS-style color strings
#' (single-band images only) \tab  comma-separated list of hex strings \cr
#' \strong{opacity}   \tab  The opacity of the layer
#' (0.0 is fully transparent and 1.0 is fully opaque) \tab
#' number \cr
#' }
#'
#' Use \code{ee$Image()$geometry()$projection()$crs()$getInfo()} for
#' getting the CRS of an Earth Engine Image.
#' @return
#' An \link[sf]{sf} object
#'
#' @importFrom stars st_set_dimensions st_as_stars write_stars
#' @importFrom sf st_crs<-
#' @importFrom reticulate py_to_r
#' @importFrom jpeg readJPEG
#' @importFrom dplyr slice
#' @importFrom utils download.file zip str
#' @importFrom png readPNG
#' @examples
#' \dontrun{
#' library(raster)
#' library(stars)
#' library(rgee)
#' ee_reattach() # reattach ee as a reserved word
#' ee_Initialize()
#' nc <- st_read(system.file("shp/arequipa.shp", package = "rgee"))
#' dem_palette <- c(
#'   "#008435", "#1CAC17", "#48D00C", "#B3E34B", "#F4E467",
#'   "#F4C84E", "#D59F3C", "#A36D2D", "#C6A889", "#FFFFFF"
#' )
#'
#' # DEM data -SRTM v4.0
#' image <- ee$Image("CGIAR/SRTM90_V4")
#' region <- nc %>%
#'   st_bbox() %>%
#'   st_as_sfc() %>%
#'   st_set_crs(4326) %>%
#'   sf_as_ee() %>%
#'   ee$FeatureCollection$geometry()
#'
#' ## world
#' world_dem <- ee_as_thumbnail(
#'   x = image,
#'   dimensions = 1024,
#'   geodesic = FALSE,
#'   evenOdd = TRUE,
#'   vizparams = list(min = 0, max = 5000)
#' )
#' world_dem[world_dem <= 0] <- NA
#' world_dem <- world_dem * 5000
#' plot(
#'   x = world_dem, col = dem_palette, breaks = "equal",
#'   reset = FALSE, main = "SRTM - World"
#' )
#'
#' ## Arequipa-Peru
#' arequipa_dem <- ee_as_thumbnail(
#'   x = image,
#'   dimensions = 512,
#'   region = region,
#'   vizparams = list(min = 0, max = 5000)
#' )
#' arequipa_dem <- arequipa_dem * 5000
#' plot(
#'   x = arequipa_dem[nc], col = dem_palette, breaks = "equal",
#'   reset = FALSE, main = "SRTM - Arequipa"
#' )
#' suppressWarnings(plot(
#'   x = nc, col = NA, border = "black", add = TRUE,
#'   lwd = 1.5
#' ))
#'
#' ## LANDSAT 8
#' img <- ee$Image("LANDSAT/LC08/C01/T1_SR/LC08_038029_20180810")$
#'   select(c("B4", "B3", "B2"))
#' Map$centerObject(img)
#' Map$addLayer(img, list(min = 0, max = 5000, gamma = 1.5))
#'
#' ## Teton Wilderness
#' l8_img <- ee_as_thumbnail(
#'   x = img,
#'   dimensions = 1024,
#'   evenOdd = TRUE,
#'   vizparams = list(
#'     min = 0,
#'     max = 5000,
#'     gamma = 1.5
#'   )
#' )
#' dev.off()
#' l8_img %>%
#'   as("Raster") %>%
#'   `names<-`(c("R", "G", "B")) %>%
#'   plotRGB(stretch = "lin")
#' }
#' @export
ee_as_thumbnail <- function(x, region, dimensions, vizparams = NULL,
                            geodesic = NULL, evenOdd = NULL, quiet = FALSE) {
  if (!any(class(x) %in% "ee.image.Image")) {
    stop("x argument is not an ee$image$Image")
  }
  region_generated <- FALSE
  if (missing(region)) {
    message("region is not defined ... taking the image bounds.")
    region <- x$geometry()
    region_generated <- TRUE
  }
  if (!any(class(region) %in% "ee.geometry.Geometry")) {
    stop("region argument is not an ee$geometry$Geometry")
  }
  # region testing
  prj_image <- x$projection()$getInfo()
  sf_image <- ee_as_sf(x$geometry())$geometry %>%
    st_transform(as.numeric(gsub("EPSG:", "", prj_image$crs)))
  sf_region <- ee_as_sf(region)$geometry %>%
    st_transform(as.numeric(gsub("EPSG:", "", prj_image$crs)))

  if (is.null(geodesic)) {
    if (region_generated) {
      is_geodesic <- st_is_longlat(sf_region)
    } else {
      is_geodesic <- region$geodesic()$getInfo()
    }
  } else {
    is_geodesic <- geodesic
  }
  if (is.null(evenOdd)) {
    query_params <- unlist(parse_json(region$serialize())$scope)
    is_evenodd <- as.logical(
      query_params[grepl("evenOdd", names(query_params))]
    )
    if (length(is_evenodd) == 0 | is.null(is_evenodd)) {
      is_evenodd <- TRUE
    }
  } else {
    is_evenodd <- evenOdd
  }

  if (!identical(st_crs(sf_image), st_crs(sf_region))) {
    stop(
      'The parameters region and x need to have the same crs\n',
      'EPSG region: ', st_crs(sf_region)$epsg,
      '\nEPSG x: ', st_crs(sf_image)$epsg
    )
  }
  ## region is a ee$Geometry$Rectangle?
  if (any(class(region) %in% "ee.geometry.Geometry")) {
    npoints <- nrow(st_coordinates(sf_region))
    if (npoints != 5) {
      message(
        "region argument needs to be a ee$Geometry$Rectangle. ",
        "Fixing it running region$bounds() ...\n"
      )
      region <- region$bounds()
      sf_region <- ee_as_sf(region)$geometry %>%
        st_transform(as.numeric(gsub("EPSG:", "", prj_image$crs)))
    }
  } else {
    stop("region needs to be a ee$Geometry$Rectangle.")
  }

  ## region is a world scene?
  if (any(st_bbox(sf_region) %in% c(180, -90))) {
    sf_region <- ee_fix_world_region(sf_image, sf_region, quiet)$geometry
  }

  if (missing(dimensions)) {
    dimensions <- 256L
    if (!quiet) {
      message("dimensions param is missing. Taken by default 256 pixels in X")
    }
  }
  if (max(dimensions) > 2048) {
    if (!quiet) {
      message(
        "For large image is preferible use rgee::ee_download_*(...)",
        "or rgee::ee_as_stars(...)"
      )
    }
  }

  # Getting image ID if it is exist
  image_id <- tryCatch(
    expr = parse_json(x$id()$serialize())$
      scope[[1]][[2]][["arguments"]][["id"]],
    error = function(e) "thumbnail"
  )

  # Fixing geometry if it is necessary
  init_offset <- ee_fix_offset(x, sf_region)
  ee_crs <- st_crs(sf_region)$epsg
  region_fixed <- sf_as_ee(
    x = sf_region,
    check_ring_dir = TRUE,
    evenOdd = is_evenodd,
    proj = ee_crs,
    geodesic = is_geodesic
  )
  if (!quiet) {
    cat(
      '- region parameters\n',
      '\rWKT      :', st_as_text(sf_region),
      '\nCRS      :', ee_crs,
      '\ngeodesic :', is_geodesic,
      '\nevenOdd  :', is_evenodd,
      '\n'
    )
  }
  # Preparing parameters
  new_params <- list(
    crs = paste0("EPSG:", ee_crs),
    dimensions = as.integer(dimensions),
    region = ee$Geometry(region_fixed$geometry())
  )

  viz_params_total <- c(new_params, vizparams)

  # Creating thumbnail as either jpg or png
  if (!quiet) {
    cat(
      "Getting the thumbnail image ... please wait\n"
    )
  }

  thumbnail_url <- x$getThumbURL(viz_params_total)
  z <- tempfile()
  download.file(thumbnail_url, z, mode = "wb", quiet = TRUE)

  # Handling problems with respect to the format
  # of the getTHumbURL (sometimes jpeg other png)
  error_message_I <- paste0(
    "Error arise after trying to download ",
    "the getThumbURL (it needs to be ",
    "either jpeg or png)"
  )

  raw_image <- tryCatch(
    tryCatch(readPNG(z),
      error = function(e) {
        pre_raw <- readJPEG(z)
        if (length(dim(pre_raw)) == 2) {
          dim(pre_raw) <- c(dim(pre_raw), 1)
        }
        pre_raw
      }
    ),
    error = function(e) stop(error_message_I)
  )

  # It is a RGB or gray image?
  if (dim(raw_image)[3] == 1) {
    # jpeg
    bands <- 1
  } else if (dim(raw_image)[3] == 2) {
    # png
    bands <- 1
  } else if (dim(raw_image)[3] == 3) {
    # png(color) or others
    bands <- 3
  } else if (dim(raw_image)[3] == 4) {
    bands <- 3
  }

  # Create a stars object for RGB images
  if (bands == 3) {
    band_name <- c("R", "G", "B")
    stars_png <- mapply(read_png_as_stars,
      seq_len(bands),
      band_name,
      SIMPLIFY = FALSE,
      MoreArgs = list(mtx = raw_image)
    )
    add <- function(x) Reduce(c, x)
    stars_png %>%
      add() %>%
      merge() %>%
      slice("X3", 1) %>%
      st_set_dimensions(names = c("x", "y", "bands")) -> stars_png
    names(stars_png) <- image_id
    attr_dim <- attr(stars_png, "dimensions")
    attr_dim$x$offset <- init_offset[1]
    attr_dim$y$offset <- init_offset[2]
    attr_dim$x$delta <- (init_offset[3] - init_offset[1]) / attr_dim$x$to
    attr_dim$y$delta <- (init_offset[4] - init_offset[2]) / attr_dim$y$to

    attr(stars_png, "dimensions") <- attr_dim
    st_crs(stars_png) <- ee_crs
    stars_png
  } else if (bands == 1) {
    # Image band name
    band_name <- x$bandNames()$getInfo()
    # Create a stars object for single band image
    stars_png <- mapply(read_png_as_stars,
      bands,
      image_id,
      SIMPLIFY = FALSE,
      MoreArgs = list(mtx = raw_image)
    )[[1]]

    stars_png <- st_set_dimensions(
      .x = stars_png,
      names = c("x", "y", "bands")
    ) %>% st_set_dimensions(which = 3, values = band_name)

    attr_dim <- attr(stars_png, "dimensions")
    attr_dim$x$offset <- init_offset[1]
    attr_dim$y$offset <- init_offset[2]
    attr_dim$x$delta <- (init_offset[3] - init_offset[1]) / attr_dim$x$to
    attr_dim$y$delta <- (init_offset[4] - init_offset[2]) / attr_dim$y$to
    attr(stars_png, "dimensions") <- attr_dim
    st_crs(stars_png) <- ee_crs
    stars_png
  } else {
    stop("Number of bands not supported")
  }
}

# From R array to stars
read_png_as_stars <- function(x, band_name, mtx) {
  rotate_x <- t(mtx[, , x])
  dim_x <- dim(rotate_x)
  array_x <- array(NA, dim = c(dim_x[1], dim_x[2], 1))
  array_x[, , 1] <- rotate_x
  stars_object <- st_as_stars(array_x)
  names(stars_object) <- band_name
  stars_object
}


#' Dimensions of a Earth Engine Image object
#'
#' Get the approximate number of rows, cols, and size of an
#' Earth Engine Image.
#' @param image Earth Engine Object.
#' @param getsize Logical. If TRUE, the size of the object
#' will be estimated.
#' @param compression_ratio Numeric. It is relevant just when
#' getsize params is TRUE. compression_ratio params is a measurement
#' of the relative reduction in size of data representation produced
#' by a data compression algorithm. By default is 12.
#' @param quiet logical. Suppress info message
#' @return A list of parameters
#' @examples
#' \dontrun{
#' library(rgee)
#' ee_reattach()
#' ee_Initialize()
#'
#' # World SRTM
#' srtm <- ee$Image("CGIAR/SRTM90_V4")
#' ee_get_npixel(srtm)
#'
#' # Landast8
#' l8 <- ee$Image("LANDSAT/LC08/C01/T1_SR/LC08_038029_20180810")
#' ee_get_npixel(l8)
#' }
#' @export
ee_image_dim <- function(image,
                         getsize = TRUE,
                         compression_ratio = 12,
                         quiet = FALSE) {
  img_proj <- image$projection()$getInfo()
  geotransform <- unlist(img_proj$transform)
  img_totalarea <- ee_as_sf(image$geometry())
  bbox <- img_totalarea %>%
    st_transform(as.numeric(gsub("EPSG:", "", img_proj$crs))) %>%
    st_bbox() %>%
    as.numeric()

  x_diff <- bbox[3] - bbox[1]
  y_diff <- bbox[4] - bbox[2]
  x_npixel <- round(abs(x_diff / geotransform[1]))
  y_npixel <- round(abs(y_diff / geotransform[5]))
  total_pixel <- abs(as.numeric(x_npixel * y_npixel))
  if (isFALSE(getsize)) {
    return(invisible(total_pixel))
  }
  if (!quiet) {
    cat('Image Rows       :', x_npixel,'\n')
    cat('Image Cols       :', y_npixel,'\n')
    cat('Number of Pixels :', format(total_pixel,scientific = FALSE),'\n')
  }
  if (isTRUE(getsize)) {
    img_types <- unlist(image$bandTypes()$getInfo())
    band_types <- img_types[grepl("precision", names(img_types))]
    band_precision <- vapply(band_types, ee_get_typeimage_size, 0)
    number_of_bytes <- total_pixel * band_precision / compression_ratio
    image_size <- ee_humansize(sum(number_of_bytes))
    if (!quiet) {
      cat("Image Size       :", image_size, "\n")
    }
  }
  invisible(
    list(
      nrow = x_npixel,
      ncol = y_npixel,
      total_pixel = total_pixel,
      image_size = image_size
    )
  )
}

ee_get_typeimage_size <- function(type) {
  if (type == "int") {
    32
  } else if (type == "INT") {
    32
  } else if (type == "double") {
    64
  } else if (type == "float") {
    64
  } else if (type == "int8") {
    8
  } else if (type == "int16") {
    16
  } else if (type == "int32") {
    32
  } else {
    32
  }
}
