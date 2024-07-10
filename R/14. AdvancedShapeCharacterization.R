# Libraries loading ----------------------------------------------------
packs <- c( "tidyverse", "EBImage", "pracma", "corrplot")
InstIfNec<-function (pack) {
  if (!do.call(require,as.list(pack))) {
    do.call(install.packages,as.list(pack))  }
  do.call(require,as.list(pack)) }
lapply(packs, InstIfNec)


## Custom Functions ----------------------------------------------------
# Function to calculate the convex hull area
calculate_convex_area <- function(coords) {
  if (nrow(coords) < 3) {
    return(NA)  # Convex hull cannot be formed with less than 3 points
  }
  hull <- chull(coords)
  hull_coords <- coords[hull, ]
  # Ensure coordinates are correctly ordered
  area <- polyarea(hull_coords[, 1], hull_coords[, 2])
  return(abs(area))  # Return absolute value of area
}

# Function to calculate major and minor axes
calculate_axes <- function(coords) {
  mean_coords <- colMeans(coords)
  centered_coords <- sweep(coords, 2, mean_coords)
  cov_matrix <- cov(centered_coords)
  eig_vals <- eigen(cov_matrix)$values
  major_axis <- 2 * sqrt(max(eig_vals))
  minor_axis <- 2 * sqrt(min(eig_vals))
  return(list(major_axis = major_axis, minor_axis = minor_axis))
}

# Optimized function to calculate the fractal dimension using the box-counting method
calculate_fractal_dimension <- function(region) {
  box_counting <- function(mask, box_size) {
    mask_height <- nrow(mask)
    mask_width <- ncol(mask)
    count <- 0
    for (i in seq(1, mask_height, by = box_size)) {
      for (j in seq(1, mask_width, by = box_size)) {
        sub_matrix <- mask[i:min(i + box_size - 1, mask_height), j:min(j + box_size - 1, mask_width)]
        if (any(sub_matrix > 0)) {
          count <- count + 1
        }
      }
    }
    return(count)
  }
  sizes <- 2^(1:floor(log2(min(dim(region)/2))))  # Limit the range of box sizes
  counts <- sapply(sizes, function(s) box_counting(region, s))
  fit <- lm(log(counts) ~ log(sizes))
  return(abs(fit$coefficients[2]))
}


## Compare  basic shapes -------------------------------------------------------
mask_image<-EBImage::readImage("./data/ShapeSamples.jpg") # plot(mask_image)
img_gray<-EBImage::channel(mask_image,"luminance") # greyscale
binary_image <- mask_image > otsu(img_gray) # Binarize the image
labelled <- bwlabel(binary_image) # Label the objects display(colorLabels(labelled))
labeled_coords  <- as.data.frame(bind_cols(computeFeatures.moment (labelled),
                                           computeFeatures.shape(labelled)))

# Display the image
display(binary_image, method = "raster")
text(labeled_coords[, "m.cx"], labeled_coords[, "m.cy"], labels = seq_len(nrow(labeled_coords)), col = "white")

# Initialize vectors to store results
convex_areas <- numeric()
major_axes <- numeric()
minor_axes <- numeric()
fractal_dimensions <- numeric()

# Loop through each region, excluding the background (label 0)
for (i in 1:max(labelled)) {
  region_coords <- which(labelled == i, arr.ind = TRUE)
  
  if (nrow(region_coords) >= 3) {
    region_mask <- (labelled == i)
    convex_areas <- c(convex_areas, calculate_convex_area(region_coords))
    axes <- calculate_axes(region_coords)
    major_axes <- c(major_axes, axes$major_axis)
    minor_axes <- c(minor_axes, axes$minor_axis)
    fractal_dimensions <- c(fractal_dimensions, calculate_fractal_dimension(region_mask))
  } else {
    convex_areas <- c(convex_areas, NA)
    major_axes <- c(major_axes, NA)
    minor_axes <- c(minor_axes, NA)
    fractal_dimensions <- c(fractal_dimensions, NA)
  }
}

# Compactness: 4 * pi * Area / Perimeter^2
labeled_coords$compactness <- (4 * pi * labeled_coords$s.area) / (labeled_coords$s.perimeter^2)

# Add major and minor axes to features
labeled_coords$major_axis <- major_axes
labeled_coords$minor_axis <- minor_axes

# Calculate Aspect Ratio: Major Axis Length / Minor Axis Length
labeled_coords$aspect_ratio <- labeled_coords$major_axis / labeled_coords$minor_axis

# Calculate Roundness: 4 * Area / (pi * Major Axis Length^2)
labeled_coords$roundness <- (4 * labeled_coords$s.area) / (pi * (labeled_coords$major_axis^2))

# Add convex area to features
labeled_coords$convex_area <- convex_areas

# Calculate Solidity: Area / Convex Area
labeled_coords$solidity <- labeled_coords$s.area / labeled_coords$convex_area

# Add fractal dimension to features
labeled_coords$fractal_dimension <- fractal_dimensions

# Calculate Circularity Ratio: 4 * pi * Area / Perimeter^2
labeled_coords$circularity_ratio <- (4 * pi * labeled_coords$s.area) / (labeled_coords$s.perimeter^2)

# Calculate Elongation Index: Major Axis Length / Minor Axis Length
labeled_coords$elongation_index <- labeled_coords$major_axis / labeled_coords$minor_axis
labeled_coords$id<-rownames(labeled_coords)
labeled_coords<-select(labeled_coords, id, compactness, circularity_ratio, aspect_ratio, 
            fractal_dimension, elongation_index, roundness, solidity, 
            m.cx:s.radius.max, major_axis, minor_axis, convex_area)

write.csv2(labeled_coords, "./out/AdvancedShapeIndicesForBasicShapes.csv", row.names = F)

# Plot 
df<-read.csv2("./out/AdvancedShapeIndicesForBasicShapes.csv", dec=",")
# Calculate the correlation matrix
correlation_matrix <- cor(df[, 2:8])

# Plot the correlation matrix
corrplot(correlation_matrix, method = "color", type = "upper", 
         tl.col = "black", tl.srt = 45, 
         addCoef.col = "black", number.cex = 0.7, 
         col = colorRampPalette(c("blue", "white", "red"))(200))

# Remove highly correlmated indices
df<-select(df, -circularity_ratio, -elongation_index, -roundness)

dfg<-pivot_longer(df[, 1:9], names_to = "Index", values_to = "Value", compactness:solidity)
dfgs<-dplyr::summarize(group_by(dfg, id, m.cx, Index), MEAN=mean(Value), SD=sd(Value))

png('./out/AdvancedShapeIndices_shapes.png', width=4, height=6, res=300, 
    type="cairo", units="in")
ggplot(dfgs, aes(Index, MEAN, fill=Index))+
  geom_bar(stat="identity", position = position_dodge(width=.9))+
  geom_linerange(aes(ymin=MEAN, ymax=MEAN+SD))+
  facet_grid(reorder(id, m.cx)~., scale="free_y")+
  theme_bw()+
  theme(legend.position="none", axis.title = element_blank())+
  coord_flip()
dev.off()

ggplot(dfgs, aes(reorder(id, m.cx), MEAN, fill=factor(id)))+
  geom_bar(stat="identity", position = position_dodge(width=.9))+
  geom_linerange(aes(ymin=MEAN, ymax=MEAN+SD))+
  facet_wrap(.~Index, scale="free_y", ncol=1)+
  theme_bw()+
  theme(legend.position="none", axis.title = element_blank())


## Loop over tuber mask --------------------------------------------------------
ll<-readRDS("./out/InitTuberMask.RDS")
RES<-data.frame()
for (i in 1:length(ll)){
  mask<-ll[[i]]
  VAR<-names(ll[i])
  mask_image <- Image(mask, colormode='Grayscale') # plot(mask_image)
  mask_image <- resize(mask_image, 700)
  labelled <- bwlabel(mask_image)
  features <- as.data.frame(bind_cols(computeFeatures.moment (labelled),
                                      computeFeatures.shape(labelled)))
  
  # Initialize vectors to store results
  convex_areas <- numeric()
  major_axes <- numeric()
  minor_axes <- numeric()
  fractal_dimensions <- numeric()
  
  # Loop through each region, excluding the background (label 0)
  for (i in 1:max(labelled)) {
    region_coords <- which(labelled == i, arr.ind = TRUE)
    
    if (nrow(region_coords) >= 3) {
      region_mask <- (labelled == i)
      convex_areas <- c(convex_areas, calculate_convex_area(region_coords))
      axes <- calculate_axes(region_coords)
      major_axes <- c(major_axes, axes$major_axis)
      minor_axes <- c(minor_axes, axes$minor_axis)
      fractal_dimensions <- c(fractal_dimensions, calculate_fractal_dimension(region_mask))
    } else {
      convex_areas <- c(convex_areas, NA)
      major_axes <- c(major_axes, NA)
      minor_axes <- c(minor_axes, NA)
      fractal_dimensions <- c(fractal_dimensions, NA)
    }
  }
  
  # Calculate specific indices
  # Compactness: 4 * pi * Area / Perimeter^2
  features$compactness <- (4 * pi * features$s.area) / (features$s.perimeter^2)
  
  # Add major and minor axes to features
  features$major_axis <- major_axes
  features$minor_axis <- minor_axes
  
  # Calculate Aspect Ratio: Major Axis Length / Minor Axis Length
  features$aspect_ratio <- features$major_axis / features$minor_axis
  
  # Calculate Roundness: 4 * Area / (pi * Major Axis Length^2)
  features$roundness <- (4 * features$s.area) / (pi * (features$major_axis^2))
  
  # Add convex area to features
  features$convex_area <- convex_areas
  
  # Calculate Solidity: Area / Convex Area
  features$solidity <- features$s.area / features$convex_area
  
  # Add fractal dimension to features
  features$fractal_dimension <- fractal_dimensions
  
  # Add metadata
  features$Var<-VAR
  features$TuberNo<-1:3
  RES<-bind_rows(RES, features)
}


## Format & save df ------------------------------------------------------------
# Calculate Circularity Ratio: 4 * pi * Area / Perimeter^2
RES$circularity_ratio <- (4 * pi * RES$s.area) / (RES$s.perimeter^2)
# Calculate Elongation Index: Major Axis Length / Minor Axis Length
RES$elongation_index <- RES$major_axis / RES$minor_axis
RES<-select(RES, Var, TuberNo, compactness, circularity_ratio, aspect_ratio, 
            fractal_dimension, elongation_index, roundness, solidity, 
            m.cx:s.radius.max, major_axis, minor_axis, convex_area)

write.csv2(RES, "out/AdvancedShapeIndices.csv", row.names = F)


## Plot results ----------------------------------------------------------------
# Plot indices by genotype
resg<-pivot_longer(RES[, 1:9], names_to = "Index", values_to = "Value", compactness:solidity)
resgs<-dplyr::summarize(group_by(resg, Var, Index), MEAN=mean(Value), SD=sd(Value))

png('./out/AdvancedShapeIndices_tubers.png', width=7, height=4, res=300, 
    type="cairo", units="in")
ggplot(resgs, aes(Var, MEAN, fill=Var))+
  geom_bar(stat="identity", position = position_dodge(width=.9))+
  geom_linerange(aes(ymin=MEAN, ymax=MEAN+SD))+
  facet_wrap(.~Index, scale="free_y", ncol=4)+
  theme_bw()+
  theme(legend.position="none", axis.title = element_blank())
dev.off()
