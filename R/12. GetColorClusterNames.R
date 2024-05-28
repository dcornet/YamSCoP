# Libraries loading ----------------------------------------------------
packs <- c( "tidyverse", "colordistance", "png", "factoextra", "grDevices")
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
