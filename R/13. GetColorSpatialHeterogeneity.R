# Libraries loading ----------------------------------------------------
packs <- c( "tidyverse", "EBImage", "imager", "GLCMTextures", "raster",
            "colorscience", "data.table", "png", "corrplot", "corrplot")
InstIfNec<-function (pack) {
  if (!do.call(require,as.list(pack))) {
    do.call(install.packages,as.list(pack))  }
  do.call(require,as.list(pack)) }
lapply(packs, InstIfNec)


# Load data and estimate color indices ----------------------------------------
# Load informations about images
df<-readRDS("./out/TuberColors.RDS")

rgb_to_grayscale <- function(R, G, B) { return(.299*R+.587*G+.114*B) }


## 1. GLCM texture -------------------------------------------------------------
# Add a grayscale column
df <- df %>%
  mutate(Grayscale = rgb_to_grayscale(R, G, B))
df[, c("X", "Y", "Z")]<-RGB2XYZ(df[, c("R", "G", "B")])
df$WI<-100-sqrt((100-df$Y)^2+df$X^2+df$Z^2)
# If one color interest you more, the corresponding color index could be 
# used profitably in place of grayscale (e.g. White index)

# Keep only first and last time stamps pics
df<-subset(df, Time %in% c(0, 870))

# Initialize an Empty Data Frame to Collect Results:
results <- data.frame()

# Get unique combinations of Var, Time, and TubNo
unique_groups <- unique(df[, c("Var", "Time", "TubNo")])

for (i in 1:nrow(unique_groups)) {
  group <- unique_groups[i, ]
  LAB<-paste(group[1,1], group[1,2],group[1,3], sep="_")
  cat(paste0("Processing: ", paste(group[1,1], group[1,2],group[1,3], sep=" "), " (", i, "/", nrow(unique_groups), ")\n"))
  
  # Filter the data for the current group
  group_data <- df %>%
    filter(Var == group$Var, Time == group$Time, TubNo == group$TubNo)
  
  # Ensure the pixel data is sorted by x and y coordinates
  group_data <- group_data %>% arrange(y, x)
  group_data$x<-group_data$x-min(group_data$x)+1
  group_data$y<-group_data$y-min(group_data$y)+1
  
  # Generate a complete grid of x, y coordinates
  complete_grid <- expand.grid(x = 1:max(group_data$x), y = 1:max(group_data$y))
  
  # Merge with the complete grid to identify missing coordinates
  complete_data <- merge(complete_grid, group_data, by = c("x", "y"), all.x=T)
  
  # Fill missing Grayscale values with a placeholder (e.g., 0 or NA)
  # complete_data$Grayscale[is.na(complete_data$Grayscale)] <- NA
  complete_data$WI[is.na(complete_data$WI)] <- NA
  
  # Determine the dimensions of the image
  width <- max(complete_data$x)
  height <- max(complete_data$y)
  
  # Convert to matrix form for GLCM calculation
  # mat <- matrix(complete_data$Grayscale, nrow = height, ncol = width, byrow = F)
  mat <- matrix(complete_data$WI, nrow = height, ncol = width, byrow = F)
  
  # Convert the matrix to a raster
  r <- raster(mat)
  
  # Quantize with equal range
  rq_equalprob<- quantize_raster(r=r, n_levels=32, method = "equal range")
  textures1<- glcm_textures(rq_equalprob, w=c(3, 3), n_levels=32, 
                            quantization="none") 
  
  # Plot GLCM metrics
  if (!dir.exists("./out/ColHeterogeneity/")) { dir.create("./out/ColHeterogeneity/", recursive = T) }
  png(paste0('./out/ColHeterogeneity/WI_', LAB, '.png'), 
      width=4*width/height, height=6, res=300, type="cairo", units="in")
  # par(plt = c(0, 1, 0, 1))
  plot(rq_equalprob, col=grey.colors(32), asp=height/width, xlim=c(0,1), ylim=c(0,1), yaxs="i")
  title('Quantized raw image based on White Index value')
  dev.off()
  png(paste0('./out/ColHeterogeneity/HeteroIndices_', LAB, '.png'), 
      width=4*width/height, height=6, res=300, type="cairo", units="in")
  plot(textures1, asp=height/width, add=T, nc=3, include_scale=T, 
       axes=F, colNA="black", reset=T)
  dev.off()
  
  # Extract texture features and append to results
  results <- rbind(results, data.frame(
    Var = group$Var,
    Time = group$Time,
    TubNo = group$TubNo,
    Mean = mean(textures1[["glcm_mean"]]@data@values, na.rm=T),
    Variance = mean(textures1[["glcm_variance"]]@data@values, na.rm=T),
    Homogeneity = mean(textures1[["glcm_homogeneity"]]@data@values, na.rm=T),
    Contrast = mean(textures1[["glcm_contrast"]]@data@values, na.rm=T),
    Dissimilarity = mean(textures1[["glcm_dissimilarity"]]@data@values, na.rm=T),
    Entropy = mean(textures1[["glcm_entropy"]]@data@values, na.rm=T),
    SA = mean(textures1[["glcm_SA"]]@data@values, na.rm=T),
    ASM = mean(textures1[["glcm_ASM"]]@data@values, na.rm=T),
    Correlation = mean(textures1[["glcm_correlation"]]@data@values, na.rm=T),
    Mean_sd = sd(textures1[["glcm_mean"]]@data@values, na.rm=T),
    Variance_sd = sd(textures1[["glcm_variance"]]@data@values, na.rm=T),
    Homogeneity_sd = sd(textures1[["glcm_homogeneity"]]@data@values, na.rm=T),
    Contrast_sd = sd(textures1[["glcm_contrast"]]@data@values, na.rm=T),
    Dissimilarity_sd = sd(textures1[["glcm_dissimilarity"]]@data@values, na.rm=T),
    Entropy_sd = sd(textures1[["glcm_entropy"]]@data@values, na.rm=T),
    SA_sd = sd(textures1[["glcm_SA"]]@data@values, na.rm=T),
    ASM_sd = sd(textures1[["glcm_ASM"]]@data@values, na.rm=T),
    Correlation_sd = sd(textures1[["glcm_correlation"]]@data@values, na.rm=T),
    stringsAsFactors = FALSE
  ))
}

# View the results
# Calculate the correlation matrix
correlation_matrix <- cor(results[, 4:12])

# Plot the correlation matrix
corrplot(correlation_matrix, method = "color", type = "upper", 
         tl.col = "black", tl.srt = 45, 
         addCoef.col = "black", number.cex = 0.7, 
         col = colorRampPalette(c("blue", "white", "red"))(200))

# we keep Mean (over SA), Contrast (over variance & Dissimilarity), Entropy (over ASM & Homogeneity), Correlation
result<-dplyr::select(results, -c(SA, Variance, Dissimilarity, ASM, Homogeneity,
                                   SA_sd, Variance_sd, Dissimilarity_sd, ASM_sd,
                                   Homogeneity_sd))

# Calculate the correlation matrix
correlation_matrix <- cor(result[, 4:11])

# Plot the correlation matrix
corrplot(correlation_matrix, method = "color", type = "upper", 
         tl.col = "black", tl.srt = 45, 
         addCoef.col = "black", number.cex = 0.7, 
         col = colorRampPalette(c("blue", "white", "red"))(200))

# Plot indices by genotype
resg<-pivot_longer(result[, 1:7], names_to = "Index", values_to = "Value", Mean:Correlation)
resgs<-dplyr::summarize(group_by(resg, Var, Time, Index), MEAN=mean(Value), SD=sd(Value))
ggplot(resgs, aes(Var, MEAN, fill=Var))+
  geom_bar(stat="identity", position = position_dodge(width=.9))+
  geom_linerange(aes(ymin=MEAN, ymax=MEAN+SD))+
  facet_grid(Index~Time, scale="free_y")

resg$Time<-ifelse(resg$Time==0, "At 0'", "At 15'")

png('./out/HeteroIndices.png', width=6, height=4, res=300,
    type="cairo", units="in")
ggplot(resg, aes(Var, Value, fill=Var, group=TubNo))+
  geom_bar(stat="identity", position = position_dodge(width=.9), color="black")+
  facet_grid(Index~Time, scale="free_y")+
  theme_bw()+
  scale_fill_manual("Genotype", values=c('#7b3294','#c2a5cf','#a6dba0','#008837'))+
  theme(legend.position = "none",
        axis.title = element_blank())
dev.off()
