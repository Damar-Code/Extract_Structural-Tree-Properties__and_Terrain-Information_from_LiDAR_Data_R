lapply(c("lidR","RSAGA", "terra", "usethis", "devtools","sp","raster","lattice","rgdal","gstat",
         "shapefiles","foreign","sf","RColorBrewer","dplyr","tictoc","future","future.apply"), require, character.only = TRUE)


FBP_EndtoEnd <- function(las_name){
  
  ras_output = paste0("../raster/")
  shp_output = paste0("../shp/")
  
  #########################
  ## SETUP OUTPUT FOLDER
  #########################
  folder_name <- read.table(text=read.table(text=las_name, sep=".")$V1, sep = "_")$V1
  dir.create(path = paste0(shp_output,folder_name,"/"),  folder_name)
  dir.create(path = paste0(ras_output,folder_name,"/"),  folder_name)
  
  plantation <- st_read("/landuse.shp")
  farm_ID <- read.table(text=read.table(text=las_name, sep=".")$V1, sep = "_")$V1
  boundary <- plantation[plantation$farm_ID == farm_ID,]
  
  ########################################
  # LAS PROCESSING
  ########################################
  # ceate chm
  chm <- create_chm(las_name, boundary)
  writeRaster(chm, paste0(ras_output, folder_name,"/",farm_ID,"_CHM.tif"), overwrite=TRUE)
  # create dtm
  dtm <- create_dtm(las_name, boundary)
  writeRaster(dtm, paste0(ras_output, folder_name,"/",farm_ID,"_Elevation.tif"), overwrite=TRUE)
  
  ########################################
  # GENERATING TERRAIN PRODUCT 
  ########################################
  env <- rsaga.env("C:/Program Files/saga-6.3.0_x64")
  rsaga.get.version(env)
  
  create_terrain(dtm =  paste0(ras_output, folder_name,"/",farm_ID,"_Elevation.tif"))
  
  ########################################
  # GENERATING TERRAIN PRODUCT 
  ########################################
  
  chm_ttops <- function(chm){
    tops <- locate_trees(chm_clipped, lmf(function(x) {x * 0.05 + 1} ))
    ttops <- tops[tops$Z>4,]
    ttops2 <- st_as_sf(st_zm(tops))
    return(ttops2)
  }
  trees <- chm_ttops(chm)
  
  ########################################
  # Apply DBH Model in Individual Tree Level{
  ########################################
  trees$DBH <- predict.lm(linearModel, trees)
  
  
  ########################################
  # GRID EXTRACTION 
  ########################################
  grid <- st_intersection(st_make_grid(farm_ID, cellsize = 20,square = TRUE), farm_ID) %>%
    st_sf() %>% 
    mutate(id = 1:nrow(.))
  grid <- st_transform(grid, crs = crs(trees))
  
  ########################################
  # EXTRACT TREE BY GRID (SUMMARY BY LOCATION)
  ########################################
  joint = value_extraction_by_location(grid, trees)
  
  ########################################
  # TREE HEIGHT CLASSIFICATION
  ########################################
  reclassify <- maxtree_std(joint)
  
  st_write(reclassify,  paste0(shp_output, folder_name,"/",farm_ID,"_treeClassification.shp"), overwrite= TRUE, append= FALSE)
  
  #######################################
  # EXTRACT BEST TREE BY GRID
  #######################################
  joint$toptree <- ifelse(joint$Z == joint$max_tree, "toptree","non")
  st_write(joint, paste0(shp_output, folder_name,"/",farm_ID,"_ToptreesbyGrid.shp"))
  
  ######################################
  # SPATIAL METRIX EXTRACTION
  #####################################
  list.Ras <- grep(list.files(path = paste0(ras_output,folder_name),  pattern = ".sdat$|.tif$"), pattern = "Distance|Channel_Network_Distance|Slope_Percent|ORDER|chm",invert = TRUE, value=TRUE)
  ras_stack <- stack(list.Ras)
  
  grid.extraction <- st_as_sf(as.data.frame(reclassify))
  head(grid.extraction)
  
  # Extract Classify Value
  grid.extraction <- cbind(grid.extraction, exact_extract(ras_stack, grid.extraction, c('majority')))
  head(grid.extraction)
  
  # Remove Unnecessary name
  colnames(grid.extraction) <- str_remove(colnames(grid.extraction), "majority.ABCD123_")
  head(grid.extraction)
  
  st_write(grid.extraction, paste0(shp_output, folder_name,"/",farm_ID,"_grid.extraction.shp"))
}

list.las <- list.files(pattern=".las$")

for(i in 1:length(list.las)){
  #i <- 1
  las_name = list.las[i] 
  FBP_EndtoEnd(las_name)
}