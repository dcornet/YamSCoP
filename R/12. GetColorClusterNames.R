# Libraries loading ----------------------------------------------------
packs <- c( "tidyverse", "colordistance", "png", "factoextra", "grDevices",
            "colorscience", "gridExtra", "grid")
InstIfNec<-function (pack) {
  if (!do.call(require,as.list(pack))) {
    do.call(install.packages,as.list(pack))  }
  do.call(require,as.list(pack)) }
lapply(packs, InstIfNec)

# Get tuber color values for all genotypes and timestamp -------------------
df<-readRDS("./out/TuberColors.RDS")
df$Code<-paste(df$Var, df$Time, df$TubNo, sep="_")
df$VarTime<-paste(df$Var, df$Time, sep="_")
# The color name were taken from https://chir.ag/projects/ntc/ntc.js
ntc_colors <- read.csv2('./data/NameThatColorWrgb.csv')
# https://xkcd.com/color/rgb.txt
xkcd_colors <- read.csv2('./data/XKCDWrgb.csv')


# Function definition ----------------------------------------
rgb_to_color_name <- function(r, g, b) {
  # Get all the predefined colors in R
  colors <- colors()
  
  # Create a color from the input RGB values
  input_color <- rgb(r, g, b, maxColorValue = 255)
  
  # Calculate the distance between the input color and each of the predefined colors
  distances <- sapply(colors, function(col) {
    col_rgb <- col2rgb(col)
    sum((col_rgb - c(r, g, b))^2)
  })
  
  # Find the closest color
  closest_color <- colors[which.min(distances)]
  return(closest_color)
}

creatImagefromMatrix<-function(DF, name, Path) {
  # Center the tuber in the middle of the image
  DF$x<-DF$x-min(DF$x)
  DF$y<-DF$y-min(DF$y)

  # Calculate the dimensions of the image based on the maximum x and y values
  img_height <- max(DF[, "y"])
  img_width <- max(DF[, "x"])
  
  # Create an empty black image
  img <- array(0, dim = c(img_height, img_width, 3))
  
  # Assign the RGB values to the corresponding coordinates
  for (i in 1:nrow(DF)) {
    x <- DF[i, "x"]
    y <- DF[i, "y"]
    r <- DF[i, "R"]
    g <- DF[i, "G"]
    b <- DF[i, "B"]
    img[y, x,1] <- r
    img[y, x, 2] <- g
    img[y, x, 3] <- b
  }

  # Write the image to a PNG file
  writePNG(img, target = Path)
  
}

ElbowPlot <- function(Path, Lower=rep(0,3), Upper=rep(.1,3), thresh=90) {
  # Test increasing cluster number
  bss_ratio <- sapply(1:10, function(k) {
    kbinnedTubers<-getKMeanColors(Path, n=k, lower=Lower, upper=Upper, plotting=F)
    kbinnedTubers$betweenss/kbinnedTubers$totss*100
  })
  
  # Determine the number of clusters to keep
  clusters_to_keep <- which(bss_ratio >= thresh)[1]
  
  # Elbow plot
  png(height=8, width=10, res=300, type="cairo",family="Garamond", units="in",
      filename=paste0("./out/ColorDistance/ElbowPlot_", AvarTime,".png"))
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

getClosestX11ColorName <- function(r, g, b) {
  # Convert the X11 color names to RGB values
  x11_colors <- colors()
  x11_rgb <- t(col2rgb(x11_colors))
  
  # Calculate the Euclidean distance between the given RGB and all X11 colors
  distances <- sqrt((x11_rgb[,1] - r)^2 + (x11_rgb[,2] - g)^2 + (x11_rgb[,3] - b)^2)
  
  # Find the index of the minimum distance
  closest_index <- which.min(distances)
  
  # Return the closest X11 color name
  closest_color <- x11_colors[closest_index]
  return(closest_color)
}

getClosestNTC <- function(r, g, b) {
  # Calculate the Euclidean distance between the given RGB and all X11 colors
  distances <- sqrt((ntc_colors$red - r)^2 + (ntc_colors$green - g)^2 + (ntc_colors$blue - b)^2)
  
  # Find the index of the minimum distance
  closest_index <- which.min(distances)
  
  # Return the closest X11 color name
  closest_color <- ntc_colors$ColorName[closest_index]
  return(closest_color)
}

getClosestXKCD <- function(r, g, b) {
  # Calculate the Euclidean distance between the given RGB and all X11 colors
  distances <- sqrt((xkcd_colors$red - r)^2 + (xkcd_colors$green - g)^2 + (xkcd_colors$blue - b)^2)
  
  # Find the index of the minimum distance
  closest_index <- which.min(distances)
  
  # Return the closest X11 color name
  closest_color <- xkcd_colors$ColName[closest_index]
  return(closest_color)
}

heatmapColorDistance2 <- function(clusterList_or_matrixObject, main=NULL, col="default", margins=c(5, 6), filename, ...) {
  obj <- clusterList_or_matrixObject
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


# Batch estimation of color cluster --------------------------------------------
ll<-list()
i<-0
if (!dir.exists("./out/AllSegmentedTubers/")) { dir.create("./out/AllSegmentedTubers/", recursive=T)}
if (!dir.exists("./out/ColorDistance/")) { dir.create("./out/ColorDistance/", recursive=T)}

for (AvarTime in c(unique(df$VarTime))){   # AvarTime<-unique(df$VarTime)[3]
  i<-i+1
  cat(paste0("Processing: ", AvarTime, " (", i, "/", length(unique(df$VarTime)),")\n")) 
  Path<-paste0("./out/AllSegmentedTubers/SegTuber_", AvarTime,".png")
  dps<-subset(df, VarTime==AvarTime)
  
  # Get pixels RGB values
  creatImagefromMatrix(dps, AvarTime, Path)
  img<-colordistance::loadImage(Path)
  
  # Remove black background 
  Lower <- c(0, 0, 0)
  Upper <- c(0.1, 0.1, 0.1)
  png(height=8, width=10, res=300, type="cairo",family="Garamond", units="in",
      filename=paste0("./out/ColorDistance/RandomPixel3D_", AvarTime,".png"))
  colordistance::plotPixels(img, lower=Lower, upper=upper, main="")
  dev.off()
  
  # Binning the pixels
  # binnedTubers<-getImageHist(Path, bins=5, lower=Lower, upper=Upper, plotting=T, title="") 
  
  # k-mean clustering
  clusters_to_keep<-ElbowPlot(Path, Lower, Upper, 90)
  png(height=8, width=10, res=300, type="cairo",family="Garamond", units="in",
      filename=paste0("./out/ColorDistance/kmeanCluster_", AvarTime,".png"))
  kbinnedTubers<-getKMeanColors(Path, n=clusters_to_keep, lower=Lower, upper=Upper, plotting=T)
  dev.off()
  res<-as.data.frame(kbinnedTubers$centers)
  res$counts<-kbinnedTubers$size
  res$pct<-res$counts/sum(res$counts)*100
  res$labels<-paste0(round(res$pct,0), "%")
  res$colNameX11<-apply(res, 1, function(row) {
    getClosestX11ColorName(as.numeric(row['r'])*255, as.numeric(row['g'])*255, as.numeric(row['b'])*255)
  })
  res$colNameNTC<-apply(res, 1, function(row) {
    getClosestNTC(as.numeric(row['r'])*255, as.numeric(row['g'])*255, as.numeric(row['b'])*255)
  })
  res$colNameXKCD<-apply(res, 1, function(row) {
    getClosestXKCD(as.numeric(row['r'])*255, as.numeric(row['g'])*255, as.numeric(row['b'])*255)
  })

  res$L<-XYZ2Lab(RGB2XYZ(dplyr::select(res, r:b)))[,1]
  res$TextColor<-ifelse(res$L > 50, "black", "white")
  
  png(height=8, width=10, res=300, type="cairo",family="Garamond", units="in",
      filename=paste0("./out/ColorDistance/ClusterProp_", AvarTime,".png"))
  ggplot(res, aes(reorder(colNameXKCD, pct), pct))+
    geom_bar(stat="identity", fill=rgb(res$r, res$g, res$b))+
    geom_text(aes(label = labels), hjust = 1.1, color=res$TextColor)+
    coord_flip()+
    theme_bw()+
    ylab("Cluster proportion (%)")+
    xlab("Cluster's closer color name (https://xkcd.com/color/rgb/)")
  dev.off()
  
  ll[[i]]<-kbinnedTubers
  names(ll)[i]<-AvarTime
}

# Gather results for all var and time -----------------------------------------
bbdf<-data.frame()
for (avar in unique(df$Var)) { #avar<-unique(df$Var)[1]
  # Find the item names containing the string 'avar'
  llid <- grep(avar, names(ll), value = TRUE)
  
  # Subset the list based on matching names
  lls <- ll[llid]
  
  # Use lapply to extract and modify 'centers' matrices and add the 'size' value
  llsm <- lapply(names(lls), function(name) {
    centers_df <- as.data.frame(lls[[name]][["centers"]])
    centers_df$parent_name <- name
    centers_df$size <- lls[[name]][["size"]]
    return(centers_df)})
  
  # Combine all modified data frames into one large data frame
  bdf <- do.call(rbind, llsm)
  
  # Prepare df for plotting
  bdf<-separate(bdf, parent_name, into=c("Var", "Timing"), sep="_")
  bdf<-mutate(group_by(bdf, Timing), pct=size/sum(size)*100)
  bdf$labels<-paste0(round(bdf$pct,0), "%")
  bdf<-ungroup(bdf)
  bdf$colNameX11<-apply(bdf, 1, function(row) {
    getClosestX11ColorName(as.numeric(row['r'])*255, as.numeric(row['g'])*255, as.numeric(row['b'])*255)
  })
  bdf$colNameNTC<-apply(bdf, 1, function(row) {
    getClosestNTC(as.numeric(row['r'])*255, as.numeric(row['g'])*255, as.numeric(row['b'])*255)
  })
  bdf$colNameXKCD<-apply(bdf, 1, function(row) {
    getClosestXKCD(as.numeric(row['r'])*255, as.numeric(row['g'])*255, as.numeric(row['b'])*255)
  })
  bdf$L<-XYZ2Lab(RGB2XYZ(dplyr::select(bdf, r:b)))[,1]
  bdf$TextColor<-ifelse(bdf$L > 50, "black", "white")
  
  bbdf <- rbind(bbdf, bdf)
}

# Color cluster dynamic by genotype -------------------------------------------
# Ensure 'Timing' and 'colNameXKCD' are factors with levels in the sorted order
bbdf$colNameXKCD<-fct_reorder(bbdf$colNameXKCD, bbdf$L)

# Plot color evolution by var
png(height=8, width=10, res=300, type="cairo",family="Garamond", units="in",
    filename="./out/ColorClusterDynamicByVar.png")
ggplot(bbdf, aes(Timing, pct, group=colNameXKCD))+
  geom_bar(stat="identity", fill=rgb(bbdf$r, bbdf$g, bbdf$b))+
  facet_grid(Var~.) +
  scale_fill_identity()+
  theme_bw()+
  xlab("Observation timestamps (s)")+
  ylab("Color cluster proportion (%)")
dev.off()


# Genotype clustering at initial and final observation -------------------------
initpics<-list.files("./out/AllSegmentedTubers", pattern="_0.png", full.names=T)
finalpics<-list.files("./out/AllSegmentedTubers", pattern="_870.png", full.names=T)

# k-means RGB distances
bbdf$Pct<-bbdf$pct
tti<-select(subset(bbdf, Timing=="0"), r:b, Pct, Var)
ttf<-select(subset(bbdf, Timing=="870"), r:b, Pct, Var)
ltti <- split(tti, tti$Var)
ltti <- lapply(ltti, function(df) df[, -which(names(df) == "Var")])
lttf <- split(ttf, ttf$Var)
lttf <- lapply(lttf, function(df) df[, -which(names(df) == "Var")])

# binned RGB distances
rgbi <- colordistance::getHistList(initpics, lower=rep(0, 3), upper=rep(.1, 3))
rgbf <- colordistance::getHistList(finalpics, lower=rep(0, 3), upper=rep(.1, 3))

# binned Lab distances
labi <- colordistance::getLabHistList(initpics, lower=rep(0, 3), # plot=T,
                                      upper=rep(.1, 3), ref.white = "D65")
labf <- colordistance::getLabHistList(finalpics, lower=rep(0, 3),  # plot=T,
                                      upper=rep(.1, 3), ref.white = "D65")

# Cluster matrices using earth mover's distance
EMD_rgbi <- colordistance::getColorDistanceMatrix(rgbi, method="emd")
EMD_rgbf <- colordistance::getColorDistanceMatrix(rgbf, method="emd")
EMD_labi <- colordistance::getColorDistanceMatrix(labi, method="emd")
EMD_labf <- colordistance::getColorDistanceMatrix(labf, method="emd")
EMD_krgbi <- colordistance::getColorDistanceMatrix(ltti, method="emd")
EMD_krgbf <- colordistance::getColorDistanceMatrix(lttf, method="emd")


# Plot results
colnames(EMD_rgbi)<-gsub("SegTuber_", "", gsub("_0", "", colnames(EMD_rgbi)))
colnames(EMD_rgbf)<-gsub("SegTuber_", "", gsub("_870", "", colnames(EMD_rgbf)))
colnames(EMD_labi)<-gsub("SegTuber_", "", gsub("_0.png", "", colnames(EMD_labi)))
colnames(EMD_labf)<-gsub("SegTuber_", "", gsub("_870.png", "", colnames(EMD_labf)))
rownames(EMD_rgbi)<-gsub("SegTuber_", "", gsub("_0", "", rownames(EMD_rgbi)))
rownames(EMD_rgbf)<-gsub("SegTuber_", "", gsub("_870", "", rownames(EMD_rgbf)))
rownames(EMD_labi)<-gsub("SegTuber_", "", gsub("_0.png", "", rownames(EMD_labi)))
rownames(EMD_labf)<-gsub("SegTuber_", "", gsub("_870.png", "", rownames(EMD_labf)))

# Create and save individual plots as PNG files
heatmapColorDistance2(EMD_rgbi, main="Color distances between RGB based\n bins at intial timestamp", filename = "./out/plot1.png")
heatmapColorDistance2(EMD_rgbf, main="Color distances between RGB based\n bins at final timestamp", filename = "./out/plot2.png")
heatmapColorDistance2(EMD_labi, main="Color distances between Lab based\n bins at intial timestamp", filename = "./out/plot3.png")
heatmapColorDistance2(EMD_labf, main="Color distances between Lab based\n bins at final timestamp", filename = "./out/plot4.png")
heatmapColorDistance2(EMD_krgbi, main="Color distances between RGB based\n k-means clusters at intial timestamp", filename = "./out/plot5.png")
heatmapColorDistance2(EMD_krgbf, main="Color distances between RGB based\n k-means clusters at final timestamp", filename = "./out/plot6.png")

# Read the PNG files and create raster grobs
plot1 <- rasterGrob(readPNG("./out/plot1.png"))
plot2 <- rasterGrob(readPNG("./out/plot2.png"))
plot3 <- rasterGrob(readPNG("./out/plot3.png"))
plot4 <- rasterGrob(readPNG("./out/plot4.png"))
plot5 <- rasterGrob(readPNG("./out/plot5.png"))
plot6 <- rasterGrob(readPNG("./out/plot6.png"))

# Arrange the plots in a 2x2 grid
png(height=12, width=8, res=300, type="cairo",family="Garamond", units="in",
    filename="./out/ColorDistanceHeatmaps.png")
grid.arrange(plot1, plot2, plot3, plot4, plot5, plot6, ncol=2)
dev.off()
