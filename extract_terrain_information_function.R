create_terrain <- function(dtm){
  ## Slope
  rsaga.geoprocessor("ta_morphometry", 0, list( ELEVATION = dtm,
                                                SLOPE = paste0(ras_output, folder_name,"/",farm_ID,"_Slope.sgrd"),
                                                ASPECT = paste0(ras_output, folder_name,"/",farm_ID,"_Aspect.sgrd"),
                                                UNIT_SLOPE = 1,
                                                UNIT_ASPECT = 1,
                                                METHOD = 6), 
                     env = env)
  
  ## Topographic Position Index
  rsaga.geoprocessor("ta_morphometry", 18, list( DEM = dtm,
                                                 TPI = paste0(ras_output, folder_name,"/",farm_ID,"_TPI.sgrd"),
                                                 DW_WEIGHTING = 0),
                     env=env)
  
  ## SAGA Wetness Index
  rsaga.geoprocessor("ta_hydrology", 15, list( DEM = dtm,
                                               TWI = paste0(ras_output, folder_name,"/",farm_ID,"_TWI.sgrd")),
                     env=env)
  
  ## farm_IDound Analysist
  rsaga.geoprocessor("ta_farm_IDound", 0, list( ELEVATION = dtm,
                                                CHANNELS = paste0(shp_output, folder_name,"/",farm_ID,"_Channel Network.shp"),
                                                CHNL_DIST = paste0(ras_output, folder_name,"/",farm_ID,"_Channel Network Distance.sgrd"),
                                                BASINS = paste0(shp_output, folder_name,"/",farm_ID,"_Basins.shp")),
                     env=env)
  # Landform
  rsaga.geoprocessor("ta_morphometry", 19, list( DEM = dtm,
                                                 LANDFORMS = paste0(ras_output, folder_name,"/",farm_ID,"_Landform.sgrd"),
                                                 DW_WEIGHTING = " 0"),
                     env=env)
  ## Create DtD
  ### Step 1 - Read Channels File
  DtD <- st_read(paste0(shp_output, folder_name,"/",farm_ID,"_Channel_Network.shp"))
  DtD <- st_zm(DtD)
  ##DtD <- DtD[DtD$ORDER >= 2,]
  
  st_write(DtD, paste0(shp_output, folder_name,"/",farm_ID,"_ORDER.shp"), append=FALSE, overwirite=TRUE)
  
  ### Step 2 - Rasterize the Channels
  rsaga.geoprocessor("grid_gridding",0,list( INPUT = paste0(shp_output, folder_name,"/",farm_ID,"_ORDER.shp"),
                                             FIELD = "ORDER",
                                             OUTPUT = 2,
                                             TARGET_USER_FITS = 1,
                                             TARGET_USER_SIZE = 3, # resolution
                                             TARGET_USER_FITS = 1,
                                             TARGET_USER_XMIN = base_extent@extent@xmin,
                                             TARGET_USER_XMAX = base_extent@extent@xmax,
                                             TARGET_USER_YMIN = base_extent@extent@ymin,
                                             TARGET_USER_YMAX = base_extent@extent@ymax,
                                             GRID = paste0(ras_output, folder_name,"/",farm_ID,"_ORDER.sgrd")),
                     env=env)  
  
  
  ### Step 3 - Proximity Grid
  rsaga.geoprocessor("grid_tools",26,list( FEATURES = paste0(ras_output, folder_name,"/",farm_ID,"_ORDER.sgrd"),
                                           DISTANCE = "Distance.sgrd"),
                     env=env)
  
  ### Step 4 - Mask with Raster
  rsaga.geoprocessor("grid_tools",24,list( GRID = paste0(ras_output, folder_name,"/",farm_ID,"_Distance.sgrd"),
                                           MASK = dtm,
                                           MASKED = paste0(farm_ID,"_DtD.sgrd")),
                     env=env)
}
create_terrain(dtm = "path")