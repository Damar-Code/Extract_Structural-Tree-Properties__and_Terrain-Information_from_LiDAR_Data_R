####################
## LAS PROCESSING
###################

plan(multisession, workers = availableCores()/2)
set_lidr_threads(availableCores()/2)

###############################
## FUNCTION OF CREATING CHM
create_chm <- function(las_name, boundary){
  las_cat <- readLAScatalog(paste0(las_path, las_name))
  
  opt_chunk_buffer(las_cat) <- 50
  opt_chunk_size(las_cat)   <- 800
  plot(las_cat, chunk_pattern = TRUE)
  
  
  create_chm <- function(chunk){
    las <- readLAS(chunk) # only for catalog_apply processing
    if (is.empty(las)) return(NULL)
    
    norm = normalize_height(las,algorithm = knnidw())
    chm_clip <- grid_canopy(norm, res = 0.5, algorithm = p2r(subcircle = 0.1, na.fill = knnidw()))
    w <- matrix(1, 3, 3) #
    smoothed <- focal(chm_clip, w, fun = mean, na.rm = TRUE) #
    return(smoothed)
  }
  
  
  opt    <- list(need_buffer = TRUE,   # catalog_apply will throw an error if buffer = 0
                 automerge   = TRUE)   # catalog_apply will merge the outputs into a single object
  
  #writeFormats()
  las_cat@output_options$drivers$Raster$param$format <- "GTiff"
  las_cat@output_options$drivers$Raster$param$overwrite <- TRUE
  #opt_restart(las_cat) <- 4
  
  opt_output_files(las_cat) <- paste0(tempdir(), "/chm_{XLEFT}_{YBOTTOM}")
  chm <- catalog_apply(las_cat, create_chm, .options = opt)
  chm
  # clip chm with boundary
  boundary <- st_transform(boundary, crs(las_cat))
  chm_clipped <- mask(crop(chm, boundary), boundary)
  return(chm_clipped)
}

###############################
## FUNCTION OF CREATING DTM
create_dtm <- function(las_name, boundary){
  ground_las <- readLAScatalog(paste0(las_path, las_name))
  
  opt_filter(ground_las) <- "-keep_class 2"
  opt_chunk_buffer(ground_las) <- 50
  opt_chunk_size(ground_las)   <- 800
  plot(ground_las, chunk_pattern = TRUE)
  
  mba <- function(n = 1, m = 1, h = 8, extend = TRUE) {
    f <- function(las, where) {
      res <- MBA::mba.points(las@data, where, n, m , h, extend)
      return(res$xyz.est[,3])
    }
    
    f <- plugin_dtm(f)
    return(f)
  }
  
  ground_las@output_options$drivers$Raster$param$format <- "GTiff"
  ground_las@output_options$drivers$Raster$param$overwrite <- TRUE
  
  opt_output_files(ground_las) <- paste0(tempdir(), "/dtm_{XLEFT}_{YBOTTOM}")
  dtm_mba <- grid_terrain(ground_las, res = 3, algorithm =  mba())
  
  dtm_mba_clipped <- mask(crop(dtm_mba, boundary), boundary)
  return(dtm_mba_clipped)
}