# Libraries loading ----------------------------------------------------
# List of required packages
packs <- c("tidyverse", "colordistance", "png", "factoextra", "grDevices",
           "colorscience", "gridExtra", "grid")

# Function to install and load packages if not already installed
InstIfNec <- function(pack) {
  if (!do.call(require, as.list(pack))) {
    do.call(install.packages, as.list(pack))
  }
  do.call(require, as.list(pack))
}
lapply(packs, InstIfNec)

# Get tuber color values for all genotypes and timestamp -------------------
# Load tuber color data from RDS file
df <- readRDS("./out/TuberColors.RDS")
# Create unique codes for each record
df$Code <- paste(df$Var, df$Time, df$TubNo, sep = "_")
df$VarTime <- paste(df$Var, df$Time, sep = "_")
# Load color name data from CSV files
ntc_colors <- read.csv2('./data/NameThatColorWrgb.csv')
xkcd_colors <- read.csv2('./data/XKCDWrgb.csv')

# Function definitions ----------------------------------------
# Function to convert RGB values to the closest predefined color name in R
rgb_to_color_name <- function(r, g, b) {
  colors <- colors() # Get all predefined colors in R
  input_color <- rgb(r, g, b, maxColorValue = 255) # Create a color from input RGB values
  distances <- sapply(colors, function(col) {
    col_rgb <- col2rgb(col)
    sum((col_rgb - c(r, g, b))^2) # Calculate distance between input color and predefined colors
  })
  closest_color <- colors[which.min(distances)] # Find the closest color
  return(closest_color)
}

# Function to create an image from a matrix and save it as a PNG file
creatImagefromMatrix <- function(DF, name, Path) {
  DF$x <- DF$x - min(DF$x) # Center the tuber in the middle of the image
  DF$y <- DF$y - min(DF$y)
  img_height <- max(DF[, "y"]) # Calculate image dimensions
  img_width <- max(DF[, "x"])
  img <- array(0, dim = c(img_height, img_width, 3)) # Create an empty black image
  for (i in 1:nrow(DF)) {
    x <- DF[i, "x"]
    y <- DF[i, "y"]
    r <- DF[i, "R"]
    g <- DF[i, "G"]
    b <- DF[i, "B"]
    img[y, x, 1] <- r
    img[y, x, 2] <- g
    img[y, x, 3] <- b
  }
  writePNG(img, target = Path) # Save the image as a PNG file
}

# Function to determine optimal number of clusters using the Elbow method and generate a plot
ElbowPlot <- function(Path, Lower = rep(0, 3), Upper = rep(.1, 3), thresh = 90) {
  bss_ratio <- sapply(1:10, function(k) {
    kbinnedTubers <- getKMeanColors(Path, n = k, lower = Lower, upper = Upper, plotting = F)
    kbinnedTubers$betweenss / kbinnedTubers$totss * 100
  })
  clusters_to_keep <- which(bss_ratio >= thresh)[1] # Determine number of clusters to keep
  png(height = 8, width = 10, res = 300, type = "cairo", family = "Garamond", units = "in",
      filename = paste0("./out/ColorDistance/ElbowPlot_", AvarTime, ".png"))
  plot(1:length(bss_ratio), bss_ratio, type = "b", pch = 19, frame = FALSE,
       xlab = "Number of clusters K",
       ylab = "Ratio of between-cluster to total sum of squares (%)",
       main = "Elbow Method",
       ylim = c(min(thresh, min(bss_ratio)), max(bss_ratio)))
  abline(h = thresh, col = "red", lty = 2)
  abline(v = clusters_to_keep, col = "blue", lty = 2)
  dev.off()
  return(clusters_to_keep)
}

# Functions to find the closest color names from various color databases
getClosestX11ColorName <- function(r, g, b) {
  x11_colors <- colors()
  x11_rgb <- t(col2rgb(x11_colors))
  distances <- sqrt((x11_rgb[, 1] - r)^2 + (x11_rgb[, 2] - g)^2 + (x11_rgb[, 3] - b)^2)
  closest_index <- which.min(distances)
  closest_color <- x11_colors[closest_index]
  return(closest_color)
}

getClosestNTC <- function(r, g, b) {
  distances <- sqrt((ntc_colors$red - r)^2 + (ntc_colors$green - g)^2 + (ntc_colors$blue - b)^2)
  closest_index <- which.min(distances)
  closest_color <- ntc_colors$ColorName[closest_index]
  return(closest_color)
}

getClosestXKCD <- function(r, g, b) {
  distances <- sqrt((xkcd_colors$red - r)^2 + (xkcd_colors$green - g)^2 + (xkcd_colors$blue - b)^2)
  closest_index <- which.min(distances)
  closest_color <- xkcd_colors$ColName[closest_index]
  return(closest_color)
}

# Function to create and save a heatmap for color distance matrices
heatmapColorDistance2 <- function(ob, main = NULL, col = "default", margins = c(5, 6), filename, ...) {
  obj <- ob
  if (is.list(obj)) {
    obj <- getColorDistanceMatrix(obj)
  } else if (!is.matrix(obj)) {
    stop("Argument is not a list (extractClusters or getHistList object)",
         " or a distance matrix (getColorDistanceMatrix object)")
  }
  if (col[1] == "default") {
    col <- colorRampPalette(c("royalblue4", "ghostwhite", "violetred2"))(n = 299)
  }
  clust <- as.dist(obj)
  png(filename, width = 600, height = 600)
  gplots::heatmap.2(obj, symm = TRUE, col = col, Rowv = as.dendrogram(hclust(clust)),
                    main = main, trace = "none", density.info = "none", key.xlab = "Color distance score",
                    key.title = NA, keysize = 1, revC = T, srtCol = 35, na.color = "grey",
                    margins = margins, offsetRow = 0, offsetCol = 0, ...)
  dev.off()
}

# Batch processing to estimate color clusters --------------------------------------------
ll <- list()
i <- 0
if (!dir.exists("./out/AllSegmentedTubers/")) { dir.create("./out/AllSegmentedTubers/", recursive = T) }
if (!dir.exists("./out/ColorDistance/")) { dir.create("./out/ColorDistance/", recursive = T) }

for (AvarTime in unique(df$VarTime)) {
  i <- i + 1
  cat(paste0("Processing: ", AvarTime, " (", i, "/", length(unique(df$VarTime)), ")\n"))
  Path <- paste0("./out/AllSegmentedTubers/SegTuber_", AvarTime, ".png")
  dps <- subset(df, VarTime == AvarTime)
  
  # Create image from RGB matrix and save as PNG
  creatImagefromMatrix(dps, AvarTime, Path)
  img <- colordistance::loadImage(Path)
  
  # Remove black background
  Lower <- c(0, 0, 0)
  Upper <- c(0.1, 0.1, 0.1)
  png(height = 8, width = 10, res = 300, type = "cairo", family = "Garamond", units = "in",
      filename = paste0("./out/ColorDistance/RandomPixel3D_", AvarTime, ".png"))
  colordistance::plotPixels(img, lower = Lower, upper = Upper, main = "")
  dev.off()
  
  # Determine optimal number of clusters and perform k-means clustering
  clusters_to_keep <- ElbowPlot(Path, Lower, Upper, 90)
  png(height = 8, width = 10, res = 300, type = "cairo", family = "Garamond", units = "in",
      filename = paste0("./out/ColorDistance/kmeanCluster_", AvarTime, ".png"))
  kbinnedTubers <- getKMeanColors(Path, n = clusters_to_keep, lower = Lower, upper = Upper, plotting = T)
  dev.off()
  res <- as.data.frame(kbinnedTubers$centers)
  res$counts <- kbinnedTubers$size
  res$pct <- res$counts / sum(res$counts) * 100
  res$labels <- paste0(round(res$pct, 0), "%")
  
  # Assign closest color names from different color databases
  res$colNameX11 <- apply(res, 1, function(row) {
    getClosestX11ColorName(as.numeric(row['r']) * 255, as.numeric(row['g']) * 255, as.numeric(row['b']) * 255)
  })
  res$colNameNTC <- apply(res, 1, function(row) {
    getClosestNTC(as.numeric(row['r']) * 255, as.numeric(row['g']) * 255, as.numeric(row['b']) * 255)
  })
  res$colNameXKCD <- apply(res, 1, function(row) {
    getClosestXKCD(as.numeric(row['r']) * 255, as.numeric(row['g']) * 255, as.numeric(row['b']) * 255)
  })
  
  res$L <- XYZ2Lab(RGB2XYZ(dplyr::select(res, r:b)))[, 1]
  res$TextColor <- ifelse(res$L > 50, "black", "white")
  
  # Generate and save bar plot of cluster proportions
  png(height = 8, width = 10, res = 300, type = "cairo", family = "Garamond", units = "in",
      filename = paste0("./out/ColorDistance/ClusterProp_", AvarTime, ".png"))
  ggplot(res, aes(reorder(colNameXKCD, pct), pct)) +
    geom_bar(stat = "identity", fill = rgb(res$r, res$g, res$b)) +
    geom_text(aes(label = labels), hjust = 1.1, color = res$TextColor) +
    coord_flip() +
    theme_bw() +
    ylab("Cluster proportion (%)") +
    xlab("Cluster's closest color name (https://xkcd.com/color/rgb/)")
  dev.off()
  
  ll[[i]] <- kbinnedTubers
  names(ll)[i] <- AvarTime
}

# Gather results for all genotypes and timestamps -----------------------------------------
bbdf <- data.frame()
for (avar in unique(df$Var)) {
  llid <- grep(avar, names(ll), value = TRUE)
  lls <- ll[llid]
  llsm <- lapply(names(lls), function(name) {
    centers_df <- as.data.frame(lls[[name]][["centers"]])
    centers_df$parent_name <- name
    centers_df$size <- lls[[name]][["size"]]
    return(centers_df)
  })
  bdf <- do.call(rbind, llsm)
  bdf <- separate(bdf, parent_name, into = c("Var", "Timing"), sep = "_")
  bdf <- mutate(group_by(bdf, Timing), pct = size / sum(size) * 100)
  bdf$labels <- paste0(round(bdf$pct, 0), "%")
  bdf <- ungroup(bdf)
  
  # Assign closest color names from different color databases
  bdf$colNameX11 <- apply(bdf, 1, function(row) {
    getClosestX11ColorName(as.numeric(row['r']) * 255, as.numeric(row['g']) * 255, as.numeric(row['b']) * 255)
  })
  bdf$colNameNTC <- apply(bdf, 1, function(row) {
    getClosestNTC(as.numeric(row['r']) * 255, as.numeric(row['g']) * 255, as.numeric(row['b']) * 255)
  })
  bdf$colNameXKCD <- apply(bdf, 1, function(row) {
    getClosestXKCD(as.numeric(row['r']) * 255, as.numeric(row['g']) * 255, as.numeric(row['b']) * 255)
  })
  bdf$L <- XYZ2Lab(RGB2XYZ(dplyr::select(bdf, r:b)))[, 1]
  bdf$TextColor <- ifelse(bdf$L > 50, "black", "white")
  
  bbdf <- rbind(bbdf, bdf)
}

# Plot color cluster dynamics by genotype -------------------------------------------
bbdf$colNameXKCD <- fct_reorder(bbdf$colNameXKCD, bbdf$L)
png(height = 8, width = 10, res = 300, type = "cairo", family = "Garamond", units = "in",
    filename = "./out/ColorClusterDynamicByVar.png")
ggplot(bbdf, aes(Timing, pct, group = colNameXKCD)) +
  geom_bar(stat = "identity", fill = rgb(bbdf$r, bbdf$g, bbdf$b)) +
  facet_grid(Var ~ .) +
  scale_fill_identity() +
  theme_bw() +
  xlab("Observation timestamps (s)") +
  ylab("Color cluster proportion (%)")
dev.off()

# Genotype clustering at initial and final observation -------------------------
initpics <- list.files("./out/AllSegmentedTubers", pattern = "_0.png", full.names = T)
finalpics <- list.files("./out/AllSegmentedTubers", pattern = "_870.png", full.names = T)

# Calculate k-means RGB distances
bbdf$Pct <- bbdf$pct
tti <- select(subset(bbdf, Timing == "0"), r:b, Pct, Var)
ttf <- select(subset(bbdf, Timing == "870"), r:b, Pct, Var)
ltti <- split(tti, tti$Var)
ltti <- lapply(ltti, function(df) df[, -which(names(df) == "Var")])
lttf <- split(ttf, ttf$Var)
lttf <- lapply(lttf, function(df) df[, -which(names(df) == "Var")])

# Calculate binned RGB distances
rgbi <- colordistance::getHistList(initpics, lower = rep(0, 3), upper = rep(.1, 3))
rgbf <- colordistance::getHistList(finalpics, lower = rep(0, 3), upper = rep(.1, 3))

# Calculate binned Lab distances
labi <- colordistance::getLabHistList(initpics, lower = rep(0, 3), upper = rep(.1, 3), ref.white = "D65")
labf <- colordistance::getLabHistList(finalpics, lower = rep(0, 3), upper = rep(.1, 3), ref.white = "D65")

# Cluster matrices using earth mover's distance
EMD_rgbi <- colordistance::getColorDistanceMatrix(rgbi, method = "emd")
EMD_rgbf <- colordistance::getColorDistanceMatrix(rgbf, method = "emd")
EMD_labi <- colordistance::getColorDistanceMatrix(labi, method = "emd")
EMD_labf <- colordistance::getColorDistanceMatrix(labf, method = "emd")
EMD_krgbi <- colordistance::getColorDistanceMatrix(ltti, method = "emd")
EMD_krgbf <- colordistance::getColorDistanceMatrix(lttf, method = "emd")

# Plot results
colnames(EMD_rgbi) <- gsub("SegTuber_", "", gsub("_0", "", colnames(EMD_rgbi)))
colnames(EMD_rgbf) <- gsub("SegTuber_", "", gsub("_870", "", colnames(EMD_rgbf)))
colnames(EMD_labi) <- gsub("SegTuber_", "", gsub("_0.png", "", colnames(EMD_labi)))
colnames(EMD_labf) <- gsub("SegTuber_", "", gsub("_870.png", "", colnames(EMD_labf)))
rownames(EMD_rgbi) <- gsub("SegTuber_", "", gsub("_0", "", rownames(EMD_rgbi)))
rownames(EMD_rgbf) <- gsub("SegTuber_", "", gsub("_870", "", rownames(EMD_rgbf)))
rownames(EMD_labi) <- gsub("SegTuber_", "", gsub("_0.png", "", rownames(EMD_labi)))
rownames(EMD_labf) <- gsub("SegTuber_", "", gsub("_870.png", "", rownames(EMD_labf)))

# Create and save individual heatmap plots as PNG files
heatmapColorDistance2(EMD_rgbi, main = "Color distances between RGB based\n bins at initial timestamp", filename = "./out/plot1.png")
heatmapColorDistance2(EMD_rgbf, main = "Color distances between RGB based\n bins at final timestamp", filename = "./out/plot2.png")
heatmapColorDistance2(EMD_labi, main = "Color distances between Lab based\n bins at initial timestamp", filename = "./out/plot3.png")
heatmapColorDistance2(EMD_labf, main = "Color distances between Lab based\n bins at final timestamp", filename = "./out/plot4.png")
heatmapColorDistance2(EMD_krgbi, main = "Color distances between RGB based\n k-means clusters at initial timestamp", filename = "./out/plot5.png")
heatmapColorDistance2(EMD_krgbf, main = "Color distances between RGB based\n k-means clusters at final timestamp", filename = "./out/plot6.png")

# Read the PNG files and create raster grobs
plot1 <- rasterGrob(readPNG("./out/plot1.png"))
plot2 <- rasterGrob(readPNG("./out/plot2.png"))
plot3 <- rasterGrob(readPNG("./out/plot3.png"))
plot4 <- rasterGrob(readPNG("./out/plot4.png"))
plot5 <- rasterGrob(readPNG("./out/plot5.png"))
plot6 <- rasterGrob(readPNG("./out/plot6.png"))

# Arrange the plots in a 2x3 grid and save as a single PNG file
png(height = 12, width = 8, res = 300, type = "cairo", family = "Garamond", units = "in",
    filename = "./out/ColorDistanceHeatmaps.png")
grid.arrange(plot1, plot2, plot3, plot4, plot5, plot6, ncol = 2)
dev.off()
