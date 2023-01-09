lapply(c("lidR","RSAGA", "terra", "usethis", "devtools","sp","raster","lattice","rgdal","gstat",
         "shapefiles","foreign","sf","RColorBrewer","dplyr","tictoc","future","future.apply"), require, character.only = TRUE)


las_name = "ABCD123_20221130_Pilot.las"
las_path = "LAS path/"

plantation <- st_read("shp path/")

folder_name <- read.table(text=las_name, sep=".")$V1

ras_output = paste0("raster path/")
shp_output = paste0("shp path/")

dir.create(path = paste0(shp_output,folder_name,"/"),  folder_name)
dir.create(path = paste0(ras_output,folder_name,"/"),  folder_name)



# TREE AGE ADJUSTMENT
f36 <- function(x) {x * 0.05 + 1} # 36
f <- f36

#########
# Select Compartment Target
#########

comp_name = read.table(text=las_name, sep="_")$V1
comp <- plantation[plantation$COMPID == comp_name,]
comp
plot(comp)
########################################
# LAS PROCESSING

plan(multisession, workers = 18L)
set_lidr_threads(18L)
########################################
## OPTIMIZE CHM
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

writeFormats()
las_cat@output_options$drivers$Raster$param$format <- "GTiff"
las_cat@output_options$drivers$Raster$param$overwrite <- TRUE
#opt_restart(las_cat) <- 4

opt_output_files(las_cat) <- paste0(tempdir(), "/chm_{XLEFT}_{YBOTTOM}")
chm <- catalog_apply(las_cat, create_chm, .options = opt)

# clip chm with comp
comp <- st_transform(comp, crs(las_cat))
chm_clipped <- mask(crop(chm, comp), comp)

writeRaster(chm_clipped, paste0(ras_output, folder_name,"/chm_",comp_name,".tif"), overwrite=TRUE)

### Individual Tree Detection
chm_ttops <- function(chm){
  tops <- locate_trees(chm_clipped, lmf(f))
  ttops <- tops[tops$Z>4,]
  ttops2 <- st_as_sf(st_zm(tops))
}
ttops2 <- chm_ttops(chm_clipped) 

st_write(ttops2, paste0(shp_output, folder_name, "/ttops_",comp_name,".shp"), overwrite=TRUE, append = FALSE)

## CREATE DTM
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

dtm_mba_clipped <- mask(crop(dtm_mba, comp), comp)
writeRaster(dtm_mba_clipped, paste0(ras_output, folder_name,"/",comp_name,"_Elevation.tif"), overwrite=TRUE)
plot_dtm3d(dtm_mba_clipped)

########################################
# GENERATING TERRAIN PRODUCT 
########################################
setwd(paste0(ras_output,folder_name,"/"))
env <- rsaga.env("C:/saga-6.0.0_x64/")
rsaga.get.version(env)

create_terrain <- function(dtm){
  # Slope
  rsaga.geoprocessor("ta_morphometry", 0, list( ELEVATION = dtm,
                                                SLOPE = paste0(comp_name,"_Slope.sgrd"),
                                                ASPECT = paste0(comp_name,"_Aspect.sgrd"),
                                                UNIT_SLOPE = 1,
                                                UNIT_ASPECT = 1,
                                                METHOD = 6), 
                     env = env)
  ## Topographic Position Index
  rsaga.geoprocessor("ta_morphometry", 18, list( DEM = dtm,
                                                 TPI = paste0(comp_name,"_TPI.sgrd"),
                                                 DW_WEIGHTING = 0),
                     env=env)
  
  
  ## SAGA Wetness Index
  rsaga.geoprocessor("ta_hydrology", 15, list( DEM = dtm,
                                               TWI = paste0(comp_name,"_TWI.sgrd")),
                     env=env)
  
  
  ## compound Analysis: Channels 
  rsaga.geoprocessor("ta_compound", 0, list( ELEVATION = dtm,
                                             SLOPE = paste0(comp_name,"_Slope_Percent.sgrd"),
                                             CHANNELS = paste0(comp_name,"_Channel_Network.shp"),
                                             CHNL_DIST = paste0(comp_name,"_Channel_Network_Distance.sgrd"),
                                             BASINS = paste0(comp_name,"_Basins.shp")),
                     env=env)
  
  ## Create DtD
  ### Step 1 - Read Channels File
  DtD <- st_read(paste0(comp_name,"_Channel_Network.shp"))
  DtD <- st_zm(DtD)
  DtD <- DtD[DtD$ORDER >= 2,]
  
  st_write(DtD, "ORDER.shp", append=FALSE, overwirite=TRUE)
  
  base_extent <- raster(dtm)
  
  ### Step 2 - Rasterize the Channels
  rsaga.geoprocessor("grid_gridding",0,list( INPUT = "ORDER.shp",
                                             FIELD = "ORDER",
                                             OUTPUT = 2,
                                             TARGET_USER_FITS = 1,
                                             TARGET_USER_SIZE = 3, # resolution
                                             TARGET_USER_FITS = 1,
                                             TARGET_USER_XMIN = base_extent@extent@xmin,
                                             TARGET_USER_XMAX = base_extent@extent@xmax,
                                             TARGET_USER_YMIN = base_extent@extent@ymin,
                                             TARGET_USER_YMAX = base_extent@extent@ymax,
                                             GRID = "ORDER.sgrd"),
                     env=env)
  
  ### Step 3 - Proximity Grid
  rsaga.geoprocessor("grid_tools",26,list( FEATURES = "ORDER.sgrd",
                                           DISTANCE = "Distance.sgrd"),
                     env=env)
  
  ### Step 4 - Mask with Raster
  rsaga.geoprocessor("grid_tools",24,list( GRID = "Distance.sgrd",
                                           MASK = paste0(comp_name,"_TPI.sdat"),
                                           MASKED = paste0(comp_name,"_DtD.sgrd")),
                     env=env)
  #####
  
  # Landform
  rsaga.geoprocessor("ta_morphometry", 19, list( DEM = dtm,
                                                 LANDFORMS = paste0(comp_name,"_Landform.sgrd"),
                                                 DW_WEIGHTING = " 0"),
                     env=env)
}

create_terrain(dtm =  paste0(ras_output, folder_name,"/",comp_name,"_Elevation.tif"))

# Save for Color Palette
{
  df <- data.frame(Lf_Cls = c(1,2,3,4,5,6,7,8,9,10),
                   Lf_Ctr = c("Streams","Midslope Drainages","Upland Drainages","Valleys","Plains",
                              "Open Slopes","Upper Slopes","Local Ridges","Midslope Ridges","High Ridges"))
  df
  write.csv(df, "Landforms_Cls.csv")
}


########################################
# Apply DBH Model in Individual Tree Level
########################################
ttops2$DBH <- predict.lm(linearModel, ttops2)
head(ttops2)

########################################
# GRID EXTRACTION 
########################################
## Grid Dataset for Visual Purposes
grid <- st_intersection(st_make_grid(comp, cellsize = 20,square = TRUE), comp) %>%
  st_sf() %>% 
  mutate(id = 1:nrow(.))
grid <- st_transform(grid, crs = crs(ttops2))

value_extraction_by_location <- function(feature, point) {
  a <- st_join(point, feature)
  b <- left_join(data.frame(a), data.frame(feature), by="id")
  c <- b %>% 
    select(-"geometry.x") %>%
    group_by(id,geometry.y) %>%
    summarise(max_tree = max(Z),
              max_DBH = max(DBH)) %>%
    rename(geometry = "geometry.y") %>%
    as.data.frame() %>%
    st_as_sf()
  return(c)
}
joint = value_extraction_by_location(grid, ttops2)
joint
plot(joint["max_tree"], axes = T)
plot(joint["max_DBH"])


## Tree Information
maxtree_std <- function(grid_tree){
  median <- median(grid_tree$max_tree)
  sd_tree <- sd(grid_tree$max_tree)
  
  reclassify <- joint %>%
    mutate(std_class = case_when(max_tree <=  median-(2*sd_tree) ~ 1,
                                 max_tree >=  median-(2*sd_tree) & max_tree <= median-(1.5*sd_tree) ~ 2,
                                 max_tree >=  median-(1.5*sd_tree) & max_tree <= median-(1*sd_tree) ~ 3,
                                 max_tree >=  median-(1*sd_tree) & max_tree <= median-(0.5*sd_tree) ~ 4,
                                 max_tree >=  median-(0.5*sd_tree) & max_tree <= median-(0*sd_tree) ~ 5,
                                 max_tree >=  median-(0*sd_tree) & max_tree <= median+(0.5*sd_tree) ~ 6,
                                 max_tree >=  median+(0.5*sd_tree) & max_tree <= median+(1*sd_tree) ~ 7,
                                 max_tree >=  median+(1*sd_tree) & max_tree <= median+(1.5*sd_tree) ~ 8,
                                 max_tree >=  median+(1.5*sd_tree) & max_tree <= median+(2*sd_tree) ~ 9,
                                 max_tree >=  median+(2*sd_tree) ~ 10,
                                 TRUE ~ 0)) %>%
    mutate(legend = case_when(std_class == 1 ~ paste0("<", round(median-(2*sd_tree),2)),
                              std_class == 2 ~ paste0(round(median-(2*sd_tree),2),"-",round(median-(1.5*sd_tree),2)),
                              std_class == 3 ~ paste0(round(median-(1.5*sd_tree),2),"-",round(median-(1.*sd_tree),2)),
                              std_class == 4 ~ paste0(round(median-(1*sd_tree),2),"-",round(median-(0.5*sd_tree),2)),
                              std_class == 5 ~ paste0(round(median-(0.5*sd_tree),2),"-",round(median-(0*sd_tree),2)),
                              std_class == 6 ~ paste0(round(median-(0*sd_tree),2),"-",round(median-(0.5*sd_tree),2)),
                              std_class == 7 ~ paste0(round(median+(0.5*sd_tree),2),"-",round(median+(1*sd_tree),2)),
                              std_class == 8 ~ paste0(round(median+(1*sd_tree),2),"-",round(median+(1.5*sd_tree),2)),
                              std_class == 9 ~ paste0(round(median+(1.5*sd_tree),2),"-",round(median+(2*sd_tree),2)),
                              std_class == 10 ~ paste0(">", round(median+(2*sd_tree),2))))
  
  # Plot Raster
  plot(reclassify["legend"], axes=T)
  return(reclassify)
}
reclassify <- maxtree_std(joint)

st_write(reclassify, paste0(shp_output, folder_name, "/plustreeGRID_",comp_name,".shp"), overwrite= TRUE, append= FALSE)

reclassify

## Zonal Statistic (Raster Data)
library(exactextractr)
library(raster)

setwd(paste0(ras_output,folder_name))

# List of Classify Raster
list.Ras <- grep(list.files(path = paste0(ras_output,folder_name),  pattern = ".sdat$|.tif$"), pattern = "Distance|Channel_Network_Distance|Slope_Percent|ORDER|chm|Cls",invert = TRUE, value=TRUE)
list.Ras
  
ras_stack <- stack(list.Ras)
ras_stack

grid.extraction <- st_as_sf(as.data.frame(reclassify))
grid.extraction
# Extract Classify Value
grid.extraction <- cbind(grid.extraction, exact_extract(ras_stack, grid.extraction, c('majority')))
head(grid.extraction)

# Remove Unnecessary name
colnames(grid.extraction) <- str_remove(colnames(grid.extraction), "majority.ABCD123_")
head(grid.extraction)

colnames(grid.extraction)[8] <- "Elevation"

write.csv(grid.extraction, "C:/Users/M S I/Desktop/FBP/table/grid.extraction.csv")
