# LiDAR_Implementation_to_Identify_The_Best_Perfoming_Trees_and_Provide_its_Terrain_Information_R

In a traditional way forest inventory was done by intensive sampling field survey inventory. Forest inventory provide structural tree information, such as heigh and diameter at breast height (DBH) because those two kind of data is easier to measure and have strong relationship with volume, which is importance for management. However the sampling method only cover 2% in each compartment and frequently cannot represent the real condition because the blank spot on particular place cannot be capture. Moreover, traditional forest inventory time-consuming and labor intensive.

Nowdays, LiDAR considered as the most edvance technology for forest inventory, because it is full sensus, accurate, cost saving and provide eficient workflow. This study shows the fundamental LiDAR application in forest inventory to provide the structural tree information such as, heigh, DBH, BAHA, volume, and additional terrain information. Spesifically in this study having aother purposes to find the best indivual tree with heigh peformance.

![Flow Chart - Copy](https://user-images.githubusercontent.com/60123331/211818931-534d1f70-f76c-4a3a-b74d-8dd9b83d7703.png)

Figure 1. Workflow of LiDAR Impelmentation in Forest Inentory

All process in the workflow above was already automated. It is only required the plantation boundary, structural tree models and LiDAR point cloud data with standard naming, include the name of compartment, flight date, and pilot. After putting the point cloud data in the input folder, the R code will run and all the result will distribute and store in particular folder automatically.

## RESULT

The final product to this project is two map, there is Distribution of High trees peformance in grid based 20x20m and second is the canopy height models map. That two product will guide the field Tree Improvement Team to find where is the location of the best tree inside the plantation. Previously this assessment is done manually, so they have to walk around the farm to find the best trees.

![Field Map 2 v2](https://user-images.githubusercontent.com/60123331/212143863-69f185c3-1966-449b-9ad8-3bd20062b5a0.png)


![CHM v2](https://user-images.githubusercontent.com/60123331/212147414-8754f398-b75f-493f-b858-7dcd1b235e5f.png)
