################################################################################
### Author: Cornet Denis                                                     ###
### Date Created: 4 Novembre 2020                                            ###   
### Last modified: 13 May 2024                                               ###
### Contributors: /                                                          ###
### Version: 0.9.1                                                           ###
################################################################################

## Description:
# This script processes a series of JPEG images to segment tubers based on color and 
# shape parameters. It utilizes image processing techniques to binarize, denoise, and
# segment images, extracting shape features for further analysis and keeping 
# segmentation mask for each genotype to be applied later on further image from 
# the same time series.

## Usage:
# Required packages: tidyverse, colorscience, EBImage
# This script automatically checks for and installs missing packages.
# Run this script in RStudio or a similar R environment by sourcing this file:
# Example: source('./R/TuberSegmentationAnalysis.R')

## Input:
# Images are read from './out/WhiteCorrected/' and metadata from './out/Picsmeta.csv'.

## Output:
# Outputs include segmented images and shape analysis results saved in './out/TuberSegmentation/'.
# Detailed shape parameters are saved to './out/BasicShapeParams.csv'.
# Genotype tuber sgmentation mask is kept in a .RDS file for later analysis. 

## License:
# Distributed under the GNU General Public License v3.0. See COPYING file for details.

## Additional Notes:
# The script involves complex image manipulation techniques and may require substantial
# computational resources for processing high-resolution images.

## Actual script code starts below

# Libraries loading ----------------------------------------------------
packs <- c( "tidyverse", "colorscience", "EBImage")
InstIfNec<-function (pack) {
  if (!do.call(require,as.list(pack))) {
    do.call(install.packages,as.list(pack))  }
  do.call(require,as.list(pack)) }
lapply(packs, InstIfNec)


# Load data ------------------------------------------------------------
# Load information about images
dp<-read.csv2('./out/Picsmeta.csv')

# Load jpg image list
input_dir <- "./out/WhiteCorrected/"
output_dir <- "./out/TuberSegmentation/"
df<-data.frame(id=list.files(input_dir, pattern="*.jpg",full.names=T, recursive = T))
df$code<-gsub(input_dir, "", df$id)
df$code<-gsub(".jpg", "", df$code)
df<-separate(df, code, into = c("Var", "Pic"), sep="_", convert=T)
df<-left_join(dp, df, by=c("Var", "Time"="Pic"))


# Batch processing of first pics of every genotype ---------------
dfs<-subset(df, Time==0)
allpics<-dfs$id
i<-0
ll<-list()
cfl<-list()
for (afile in allpics) {      #(afile<-allpics[3])
  
  i<-i+1
  dps<-subset(dfs, id==afile)
  VAR<-as.character(dps$Var)
  
  # Read image and convert to grey matrix 
  img_srgb<-readImage(afile) # display(img_srgb)
  img_gray<-EBImage::channel(img_srgb,"luminance") # greyscale
  # display(img_gray)
  
  # Binarize the image (Black & White)
  img_bin <- img_gray > otsu(img_gray) # binary
  # display(img_bin)
  
  # Clean small particles
  kern = makeBrush(7, shape='disc') # make a mask with a disc shape brush of size 5pxls
  img_bdenoised<-EBImage::erode(img_bin, kern) # Opening=erosion followed by dilation
  # display(img_bdenoised)
  
  # Identify objects
  dmap <- distmap(img_bdenoised) # distance map display(dmap)
  wmask<-bwlabel(dmap) # object detection
  # display(colorLabels(wmask))
  
  # Keep only tubers and remove other objects
  cf<-computeFeatures.shape(wmask[,]) # Morpho features of objects
  blur<-sort(cf[,"s.area"], index.return=TRUE, decreasing=TRUE)$ix[4:nrow(cf)]
  cmask=rmObjects(wmask, blur)
  # display(colorLabels(cmask))
  
  # Get shape parameters for each tuber
  cf<-computeFeatures.shape(cmask[,]) 
  cf<-as.data.frame(cbind(cf, computeFeatures.moment(cmask[,])))
  cf$Var<-VAR
  cfl[[i]]<-cf
  
  # Plot ellipse and mino/major axis
  if (!dir.exists(output_dir)) { dir.create(output_dir, recursive=T)}
  moments<-cf
  moments$m.minoraxis <- moments$m.majoraxis * sqrt(1 - moments$m.eccentricity^2)
  png(height=3, width=5, res=300, units="in", 
      filename=paste0(output_dir, "Shape_", VAR, ".png"))
  plot(img_srgb)
  for (j in 1:nrow(cf)) {
    a <- moments[j, "m.majoraxis"] / 2  # semi-major axis
    b <- moments[j, "m.minoraxis"] / 2  # semi-minor axis
    angle <- moments[j, "m.theta"]
    
    # Parametric equation of the ellipse
    t <- seq(0, 2*pi, length.out=100)
    x <- a * cos(t)
    y <- b * sin(t)
    
    # Rotation matrix
    rotation <- matrix(c(cos(angle), sin(angle), -sin(angle), cos(angle)), ncol=2)
    coords <- rotation %*% rbind(x, y)
    
    # Adjust the coordinates by adding the centroid and draw ellipse
    coords[1,] <- coords[1,] + moments[j, 'm.cx']
    coords[2,] <- coords[2,] + moments[j, 'm.cy'] 
    lines(coords[1,], coords[2,], col='red', lwd=1.5)
    
    # Calculate and draw the major axis
    major_start <- rotation %*% c(-a, 0) + c(moments[j,'m.cx'], moments[j,'m.cy'])
    major_end <- rotation %*% c(a, 0) + c(moments[j,'m.cx'], moments[j,'m.cy'])
    lines(c(major_start[1], major_end[1]), c(major_start[2], major_end[2]), col='red', lwd=1.5)
    
    # Calculate and draw the minor axis
    minor_start <- rotation %*% c(0, -b) + c(moments[j,'m.cx'], moments[j,'m.cy'])
    minor_end <- rotation %*% c(0, b) + c(moments[j,'m.cx'], moments[j,'m.cy'])
    lines(c(minor_start[1], minor_end[1]), c(minor_start[2], minor_end[2]), col='red', lwd=1.5)
  }
  dev.off()
  
  # Plot segmentation result
  # cmaskt<-resize(cmask, 512)
  # img_srgbt<-resize(img_srgb, 512)
  temp<-paintObjects(cmask, img_srgb, col=c('green', NA), thick=T, closed=T, opac=c(1, 1))
  png(height=2, width=4, res=300, units="in", 
      filename=paste0(output_dir, "Segmentation_", VAR, ".png"))
  plot(temp, all=TRUE)
  dev.off()
  
  ll[[i]]<-cmask
  names(ll)[i]<-VAR
  
}

# Save shape and color data
saveRDS(ll, "./out/InitTuberMask.RDS")
sdf<-do.call(rbind, cfl)
write.csv2(sdf, "./out/BasicShapeParams.csv", col.names=T, row.names=F, sep=";")