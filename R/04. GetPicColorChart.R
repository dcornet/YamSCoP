################################################################################
### Author: Cornet Denis                                                     ###
### Date Created: 4 Novembre 2020                                            ###   
### Last modified: 13 May 2024                                               ###
### Contributors: /                                                          ###
### Version: 0.9.1                                                           ###
################################################################################

## Description:
# This script processes a batch of images to extract and analyze color patches
# of a custom color chart from each image. It utilizes parallel processing 
# to handle large batches of images efficiently and computes various color
# metrics including RGB, XYZ, and CIE Lab color values. Additionally, 
# it compares observed color values against theoretical values and visualizes 
# these comparisons.

## Usage:
# Required packages: Rvision, tidyverse, colorscience, imager, foreach, 
# doParallel, gridExtra
# This script automatically checks for and installs missing packages.
# Run this script in RStudio or a similar R environment by sourcing this file:
# Example: source('./R/ColorAnalysis.R')

## Input:
# The script reads metadata from a CSV file located at './out/Picsmeta.csv' and 
# image files from './out/JPGconvertedPics/' directory.

## Output:
# Outputs several files including individual patch recognition images, 
# color comparison charts, and a comprehensive CSV file with all color data.
# Output files are saved to directories './out/PatchRecognition/', 
# './out/ColorChartTheorVSobs/' and  './out/PicsChartLab.csv'.

## License:
# Distributed under the GNU General Public License v3.0. See COPYING file for details.

## Additional Notes:
# The script utilizes a high amount of RAM and CPU resources due to parallel processing.
# Ensure adequate system resources are available before running.

## Actual script code starts below

# Libraries loading ----------------------------------------------------
packs <- c( "Rvision", "tidyverse", "colorscience", "imager", 
            "foreach", "doParallel", "gridExtra")
InstIfNec<-function (pack) {
  if (!do.call(require,as.list(pack))) {
    do.call(install.packages,as.list(pack))  }
  do.call(require,as.list(pack)) }
lapply(packs, InstIfNec)

# Parameters ------------------------------------------------------------
NRows=4
NCols=6
NbOfPatch=NRows*NCols
Path="./out/JPGconvertedPics/"

# Function definition ---------------------------------------------------
# Keep only the NbOfPatch blobs corresponding to the NbOfPatch patches
get_missing_patch <- function(patch, afile) {
  # patch<-subset(patch, !(x > dimPic[2]*.8)) # delete outer right blob
  # patch<-subset(patch, !(x < dimPic[2]*.2)) # delete outer left blob
  patch<-subset(patch, !(x > mean(patch$x)*2)) # delete small tuber on the rigth
  patch<-subset(patch, !(y < mean(patch$y)/1.6)) # delete small tuber on the bottom
  
  patch<-subset(patch, id<=NbOfPatch)
  patch<-subset(patch, !(y < mean(patch$y)-3.3*mean(patch$size)))
  patch<-subset(patch, !(y > mean(patch$y)+3.3*mean(patch$size)))
  
  patch<-patch[with(patch, order(x)), ]
  patch<-dplyr::mutate(patch,
                       xl=ifelse(is.na(lag(x)), x, lag(x)),
                       col=cumsum((x-xl)>(size/2))+1)
  patch<-patch[with(patch, order(y)), ]
  patch<-dplyr::mutate(patch,
                       yl=ifelse(is.na(lag(y)), y, lag(y)),
                       row=cumsum((y-yl)>(size*.7/2))+1)
  if (nrow(patch)<NbOfPatch){
    patch<-left_join(expand.grid(col=1:NCols, row=1:NRows), 
                     patch, by=c("row", "col"))
    patch<-patch[with(patch, order(col)), ]
    patch<-dplyr::mutate(group_by(patch, row), 
                         size=ifelse(is.na(size), mean(size, na.rm=T), size),
                         x=ifelse(is.na(x), lag(x)+mean(x-lag(x), na.rm=T), x),
                         x=ifelse(is.na(x), lead(x)-mean(x-lag(x), na.rm=T), x),
                         x=ifelse(is.na(x), lag(x)+ lag(x)-lag(lag(x)), x),
                         y=ifelse(is.na(y), mean(y, na.rm=T), y))
    patch<-dplyr::mutate(group_by(patch, col), 
                         x=ifelse(is.nan(x), NA, x),
                         x=ifelse(is.na(x), mean(x, na.rm=T), x))
  }
  patch<-patch[with(patch, order(col, row)), ]
  patch$id<-1:NbOfPatch
  patch<-as.data.frame(patch)
  rownames(patch)<-patch$id
  return(patch)
}

# Render all rectangle associated to each blob inside img
multi_draw <- function(img, detected_objects) {
  for (i in 1:nrow(detected_objects)) {
    size <- detected_objects$size[i]/4
    left <- detected_objects$x[i]-size
    right <- detected_objects$x[i]+size
    top <- detected_objects$y[i]-size*.7
    bottom <- detected_objects$y[i]+size*.7
    drawRectangle(img, right, bottom, left, top, thickness = 8)
  }
}

# Get mean color value of each patch
get_colors_matrix <- function(initR, patch) {
  # store all colors in a new image (1 ligne, NbOfPatch column, 3 color)
  colors <- data.frame(PatchNb=NA, id=NA, col=NA, row=NA, x=NA, y=NA, V1=NA, 
                       V2=NA, V3=NA)
  # filtering each blobs
  for (j in patch$id) {
    df<-subset(patch, id==j)
    size <- df$size/4
    left <- df$x-size*.4
    right <- df$x+size*.4
    top <- df$y-size*.4
    bottom <- df$y+size*.4
    sub_array = initR[top:bottom, left:right, 3:1] # get sub texture
    
    # calculate the RGB mean of the window texture
    colors[j, "V1"] <- mean(sub_array[,,1])
    colors[j, "V2"] <- mean(sub_array[,,2])
    colors[j, "V3"] <- mean(sub_array[,,3])
    colors[j, "PatchNb"] <- j
    colors[j, "x"] <- df$x
    colors[j, "y"] <- df$y
    colors[j, "col"] <- df$col
    colors[j, "row"] <- df$row
    colors[j, "id"] <- df$id
    
  }
  return(colors)
}

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
df<-data.frame(id=list.files(Path, pattern="*.JPG", 
                    full.names=T, recursive = T))
df$code<-gsub(Path, "", df$id)
df$code<-gsub(".JPG", "", df$code)
df<-separate(df, code, into = c("Var", "Pic"), sep="_", convert=T)
df<-left_join(dp, df, by=c("Var", "Time"="Pic"))


# Batch analysis ----------------------------------------------------------
allpics<-df$id
DIM<-dim(Rvision::image(allpics[3]))
res<-matrix(ncol=12, nrow=NbOfPatch)
colnames(res)<-c("Var", "OxyTime", "PatchNo", "R", 
                 "G", "B", "L", "a", "b", "Lwc", "awc", "bwc")
resf<-list()
initR<-array(data=NA, dim=c(DIM[1], DIM[2], DIM[3]))

# Get cluster ready
cl <- makeCluster(detectCores()-2)
registerDoParallel(cl)

resf<-foreach(afile=allpics, .errorhandling = 'pass', .combine=rbind,
              .packages=c("Rvision", "tidyverse", "colorscience", "imager", "gridExtra")) %dopar% {
                #  (afile<-allpics[3])
                dps<-subset(df, id==afile)
                Var<-as.character(dps$Var)
                OxyTime<-dps$Time
                cat(paste0("Treatement of: ", Var, " @ ", OxyTime, " seconds\n"))
                
                # Read the jpg file
                img <- Rvision::image(afile)
                #  plot(img)
                
                # Detecting feature/blob within the initial image
                patch<-Rvision::simpleBlobDetector(
                  img, 50, 220, 10, 2, 10,
                                                   filter_by_area=T, 
                                                   # min and max_area should be modified depending on image size
                                                   min_area=3000, 
                                                   max_area=10000, 
                                                   filter_by_color=F,
                                                   filter_by_circularity=T, min_circularity=0.6, max_circularity=1,
                                                   filter_by_convexity=F,
                                                   filter_by_inertia=T)
                
                # multi_draw(img, patch)
                # plot(img)

                
                # Keep only the NbOfPatch blobs
                patch<-get_missing_patch(patch, afile)
                
                # # Render each detected feature and save the result for later checking
                multi_draw(img, patch)
                if (!dir.exists("./out/PatchRecognition/")) { # Directory does not exist, so create it
                  dir.create("./out/PatchRecognition/", recursive = TRUE)}
                write.Image(img, paste0("./out/PatchRecognition/Patch_", Var, "_", OxyTime, ".JPG"), overwrite=T)
                
                # Convert image to matrix
                dimPic<-dim(img)
                img_array<-as.matrix(img)
                
                # Get chart measured values
                colors<-get_colors_matrix(img_array, patch)
                colors$PicName<-paste0(Path, Var, "_", OxyTime, ".JPG")
                colors$x0<-rep(1:NCols, each=NRows)
                colors$y0<-rep(1:NRows, times=NCols)
                p1<-ggplot(colors, aes(x0,y0))+
                  geom_tile(fill=rgb(colors$V1, colors$V2, colors$V3, maxColorValue = 255))+
                  theme_bw()+
                  geom_text(aes(label=id))+
                  coord_fixed()+
                  theme(axis.title = element_blank())+
                  ggtitle('Observed chart')
                
                # Get XYZ and L*a*b* chart measured values
                xrite_pic_RGBs<-cbind(colors$V1, colors$V2, colors$V3)/255
                xrite_pic_XYZ<-RGB2XYZ(xrite_pic_RGBs, illuminant = "D65") 
                xrite_pic_Lab<-XYZ2Lab(xrite_pic_XYZ)
                
                
                # Get targets theoretical values and compare
                xrite_t_Lab<-read.csv("./data/ColorChartTheoreticalValues.csv", sep=";", dec=",")
                xrite_t_XYZ<-Lab2XYZ(as.matrix(xrite_t_Lab[,c(2:4)]))
                xrite_t_RGB<-XYZ2RGB(as.matrix(xrite_t_XYZ), illuminant = "D65")
                colnames(xrite_t_RGB)<-c("R", "G", "B")
                xrite_t_RGB[xrite_t_RGB>1]<-1
                xrite_t_RGB[xrite_t_RGB<0]<-0
                xrite_t_Lab<-bind_cols(xrite_t_Lab, xrite_t_RGB)
                
                p2<-ggplot(xrite_t_Lab, aes(x,y))+
                  geom_tile(fill=rgb(xrite_t_Lab$R, xrite_t_Lab$G, xrite_t_Lab$B, maxColorValue = 1))+
                  theme_bw()+
                  geom_text(aes(label=ColorNo))+
                  coord_fixed()+
                  theme(axis.title = element_blank())+
                  ggtitle('Theoretical chart')
                
                # Get ColorChart corrected white-Lab values
                W_pic_XYZ<-xrite_pic_XYZ[NbOfPatch,]
                W_ref_XYZ<-xrite_t_XYZ[NbOfPatch,]
                xrite_pic_Labw<-XYZtoLab_CustomRefWhite(xrite_pic_XYZ, RefWhite = W_pic_XYZ)
                xrite_pic_XYZw<-LabtoXYZ_CustomRefWhite(xrite_pic_Labw, RefWhite = W_ref_XYZ)
                xrite_pic_Labw2<-XYZ2Lab(xrite_pic_XYZw)
                xrite_pic_RGBsw<-XYZ2RGB(xrite_pic_XYZw)
                xrite_pic_RGBsw<-as.data.frame(xrite_pic_RGBsw)
                xrite_pic_RGBsw$x<-rep(1:NCols, each=NRows)
                xrite_pic_RGBsw$y<-rep(1:NRows, times=NCols)
                p3<-ggplot(xrite_pic_RGBsw, aes(x, y))+
                  geom_tile(fill=rgb(xrite_pic_RGBsw[,1], xrite_pic_RGBsw[,2], xrite_pic_RGBsw[,3]))+
                  theme_bw()+
                  geom_text(label=1:NbOfPatch)+
                  coord_fixed()+
                  theme(axis.title = element_blank())+
                  ggtitle('White corrected chart')
                
                # Keep track of color change with different color chart viz
                if (!dir.exists("./out/ColorChartTheorVSobs/")) { # Directory does not exist, so create it
                  dir.create("./out/ColorChartTheorVSobs/", recursive = TRUE)}
                tt<-gridExtra::grid.arrange(p1, p2, p3, ncol=1)
                ggsave(filename=paste0("./out/ColorChartTheorVSobs/", Var, "_", OxyTime, ".png"), plot=tt, 
                       units="in", height=10, width=5, dpi=300, device="png")
                
                # Save pic info 
                res[1:NbOfPatch,"OxyTime"]<-OxyTime
                res[1:NbOfPatch,"Var"]<-Var
                res[1:NbOfPatch,"PatchNo"]<-1:NbOfPatch
                res[1:NbOfPatch, c("R","G","B")]<-xrite_pic_RGBs
                res[1:NbOfPatch, c("L","a","b")]<-xrite_pic_Lab
                res[1:NbOfPatch, c("Lwc","awc","bwc")]<-xrite_pic_Labw2
                return(res)
                
                rm(list=ls()); gc()
              }
stopImplicitCluster()
stopCluster(cl)

# Gather df from lists and save results
resfgrw <- as.data.frame(resf)
resfgrw[4:12] <- sapply(resfgrw[4:12],as.numeric)
resfgrw[2:3] <- sapply(resfgrw[2:3],as.integer)

# Save results
write.csv2(resfgrw, './out/PicsChartLab.csv', col.names = T, row.names = F, sep=";")
