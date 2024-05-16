################################################################################
### Author: Cornet Denis                                                     ###
### Date Created: 4 Novembre 2020                                            ###   
### Last modified: 13 May 2024                                               ###
### Contributors: /                                                          ###
### Version: 0.9.1                                                           ###
################################################################################

## Description:
# This script processes a series of JPEG images to apply color corrections based
# on custom white balance adjustments. It utilizes color science transformations
# to convert image colors from RGB to XYZ to Lab and back, applying white balance
# correction with reference white values derived from theoretical color charts and 
# observed image data.

## Usage:
# Required packages: tidyverse, colorscience, imager
# This script automatically checks for and installs missing packages.
# Run this script in RStudio or a similar R environment by sourcing this file:
# Example: source('./R/ColorBalanceCorrection.R')

## Input:
# Images are read from './out/JPGconvertedPics/' and color data from './out/Picsmeta.csv'.
# Theoretical color values are read from './data/ColorChartTheoreticalValues.csv'.

## Output:
# Outputs corrected images into './out/WhiteCorrected/'.
# Logs processing progress directly to the console.

## License:
# Distributed under the GNU General Public License v3.0. See COPYING file for details.

## Additional Notes:
# The script is designed to process large image files and may require substantial
# memory and CPU time, especially for high-resolution images.

## Actual script code starts below


# Libraries loading ----------------------------------------------------
packs <- c( "tidyverse", "colorscience", "imager")
InstIfNec<-function (pack) {
  if (!do.call(require,as.list(pack))) {
    do.call(install.packages,as.list(pack))  }
  do.call(require,as.list(pack)) }
lapply(packs, InstIfNec)


# Function definition ---------------------------------------------------
# XYZtoLab_CustomRefWhite
XYZtoLab_CustomRefWhite<- function (XYZm, RefWhite) {
  kE <- 216/24389
  kK <- 24389/27
  Rx <- RefWhite[1]
  Ry <- RefWhite[2]
  Rz <- RefWhite[3]
  xr <- XYZm[, 1]/Rx
  yr <- XYZm[, 2]/Ry
  zr <- XYZm[, 3]/Rz
  
  want=which(xr>kE) 
  fx=(kK * xr + 16)/116 
  fx[want]=xr[want]^(1/3)
  want=which(yr>kE) 
  fy=(kK * yr + 16)/116 
  fy[want]=yr[want]^(1/3)
  want=which(zr>kE) 
  fz=(kK * zr + 16)/116 
  fz[want]=zr[want]^(1/3)
  
  L <- 116 * fy - 16
  a <- 500 * (fx - fy)
  b <- 200 * (fy - fz)
  cbind(L = L, a = a, b = b)
}
# LabtoXYZ_CustomRefWhite
LabtoXYZ_CustomRefWhite<- function (Labm, RefWhite) {
  L <- Labm[, 1]
  a <- Labm[, 2]
  b <- Labm[, 3]
  kE <- 216/24389
  kK <- 24389/27
  Rx <- RefWhite[1]
  Ry <- RefWhite[2]
  Rz <- RefWhite[3]
  fy <- (L + 16)/116
  fx <- 0.002 * a + fy
  fz <- fy - 0.005 * b
  fx3 <- fx * fx * fx
  fz3 <- fz * fz * fz
  xr <- ifelse((fx3 > kE), fx3, ((116 * fx - 16)/kK))
  yr <- ifelse((L > 8), (((L + 16)/116)^3), (L/kK))
  zr <- ifelse((fz3 > kE), fz3, ((116 * fz - 16)/kK))
  X <- xr * Rx
  Y <- yr * Ry
  Z <- zr * Rz
  cbind(X = X, Y = Y, Z = Z)
}


# Load data ------------------------------------------------------------
# Load informations about images
dp<-read.csv2('./out/Picsmeta.csv')

# Load jpg image list
df<-data.frame(id=list.files("./out/JPGconvertedPics/", pattern="*.JPG", 
                             full.names=T, recursive = T))
df$code<-gsub("./out/JPGconvertedPics/", "", df$id)
df$code<-gsub(".JPG", "", df$code)
df<-separate(df, code, into = c("Var", "Pic"), sep="_", convert=T)
df<-left_join(dp, df, by=c("Var", "Time"="Pic"))
allpics<-df$id

# Batch analysis ----------------------------------------------------------
i<-0
for(afile in allpics) {
  # Image information record
  i<-i+1
  # (afile<-allpics[51])
  cat(paste0("Processing: ", afile, " (", i, "/", length(allpics),")\n")) 
  dps<-subset(df, id==afile)
  VAR<-as.character(dps$Var)
  OT<-dps$Time
  
  # Read the jpg file
  img_rgb<-imager::load.image(afile) # par(mar=c(0,0,0,0)); plot(img_rgb)
  # img_rgb<-imresize(img_rgb,1/4)
  
  # Convert image to xyz matrix
  img_xyz<-RGBtoXYZ(sRGBtoRGB(img_rgb))
  dimPic<-dim(img_xyz)
  array_xyz<-as.data.frame(img_xyz, wide="c")
  
  # Get chart refwhite pic value
  temp<-read.csv2('./out/PicsChartLab.csv')
  W_pic_Lab<-as.numeric(filter(temp, Var==VAR & OxyTime==OT & PatchNo==24)[, 7:9]) # 24 is the patch number corresponding to white ref
  W_pic_XYZ<-Lab2XYZ(W_pic_Lab)
  xrite_t_Lab<-read.csv("./data/ColorChartTheoreticalValues.csv", sep=";", dec=",")
  W_ref_XYZ<-Lab2XYZ(as.numeric(xrite_t_Lab[24, c(2:4)]))
  
  # Apply white correction (see XXXXX)
  array_Labw<-XYZtoLab_CustomRefWhite(array_xyz[,3:5], RefWhite=W_ref_XYZ)
  array_XYZwc<-LabtoXYZ_CustomRefWhite(array_Labw, RefWhite=W_pic_XYZ)
  
  # Turn array to image format
  img_xyz_wc<-as.cimg(c(array_XYZwc[,1], array_XYZwc[,2], array_XYZwc[,3]),
                      x=max(array_xyz$x), y=max(array_xyz$y), z=1, cc=3)
  img_rgb_wc<-imager::RGBtosRGB(imager::XYZtoRGB(img_xyz_wc))
  # par(mfrow=c(1,2))
  # plot(img_rgb_wc)
  # title("White corrected")
  # plot(img_rgb)
  # title("Raw image")
  
  # Save white corrected image
  output_dir <- "./out/WhiteCorrected/"
  if (!dir.exists(output_dir)) { dir.create(output_dir, recursive=T)}
  save.image(img_rgb_wc, 
             paste0(output_dir, VAR, "_", OT, ".jpg"), quality=1)
}
