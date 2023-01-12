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