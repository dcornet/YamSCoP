################################################################################
### Author: Cornet Denis                                                     ###
### Date Created: 4 Novembre 2020                                            ###   
### Last modified: 13 May 2024                                               ###
### Contributors: /                                                          ###
### Version: 0.9.1                                                           ###
################################################################################

## Description:
# This script processes a series of JPEG images from multiple genotypes of tubers
# to analyze and extract color data. It applies image segmentation masks and 
# resizes images for standardized processing. The script operates in batches,
# handling images by genotype and time, and compiles color data into a large dataset.

## Usage:
# Required packages: tidyverse, colorscience, EBImage, foreach, doParallel
# This script automatically checks for and installs missing packages.
# Run this script in RStudio or a similar R environment by sourcing this file:
# Example: source('./R/TuberColorExtraction.R')

## Input:
# Images are loaded from './out/WhiteCorrected/' with metadata from './out/Picsmeta.csv'.
# Image segmentation masks are read from './out/InitTuberMask.RDS'.

## Output:
# Outputs color data for each segmented tuber into './out/TuberColors.RDS'.
# Each entry includes the RGB color values and related metadata for the segmented areas.

## License:
# Distributed under the GNU General Public License v3.0. See COPYING file for details.

## Additional Notes:
# The script handles large image files and generates substantial data,
# requiring significant memory and processing power. Ensure adequate
# system resources are available before running.

## Actual script code starts below

# Libraries loading ----------------------------------------------------
packs <- c( "tidyverse", "colorscience", "EBImage", 
            "foreach", "doParallel")
InstIfNec<-function (pack) {
  if (!do.call(require,as.list(pack))) {
    do.call(install.packages,as.list(pack))  }
  do.call(require,as.list(pack)) }
lapply(packs, InstIfNec)


# Load data ------------------------------------------------------------
# Final image size
fim<-1056 # 10geno*30images*3tub = 350 to 750Mo => 100 geno ~ 7.5Go dataframe

# Load informations about images
dp<-read.csv2('./out/Picsmeta.csv')
ll<-readRDS("./out/InitTuberMask.RDS")

# Load jpg image list
input_dir <- "./out/WhiteCorrected/"
output_dir <- "./out/TuberIndices/"
df<-data.frame(id=list.files(input_dir, pattern="*.jpg",full.names=T, recursive = T))
df$code<-gsub(input_dir, "", df$id)
df$code<-gsub(".jpg", "", df$code)
df<-separate(df, code, into = c("Var", "Pic"), sep="_", convert=T)
df<-left_join(dp, df, by=c("Var", "Time"="Pic"))
allVar<-unique(df$Var)


# Batch processing of first pics of every genotype ---------------
i<-0
gg<-list()
for (avar in allVar) { # avar<-allVar[2]
  VAR<-avar
  vmask<-ll[[avar]]
  dfs<-subset(df, Var==avar)
  alltimes<-unique(dfs$Time)
  
  for (atime in alltimes) { # atime<-alltimes[2]
    dps<-subset(dfs, Time==atime)
    OT<-atime
    # Read image (afile<-allpics[1])
    img_srgb<-readImage(dps$id)
    
    for (j in 1:3) {
      (i<-i+1)
      cmask_t<-ifelse(vmask==j, 1, 0)
      cmask_t<-EBImage::combine(cmask_t, cmask_t, cmask_t)
      img_seg_t<-img_srgb*cmask_t # plot(img_seg_t)
      img_seg_t = EBImage::resize(img_seg_t, w=fim)
      
      df1<-data.frame(x=rep(1:dim(img_seg_t)[1], each=dim(img_seg_t)[2]),
                      y=rep(1:dim(img_seg_t)[2], times=dim(img_seg_t)[1]),
                      R=as.vector(img_seg_t[,,1]), G=as.vector(img_seg_t[,,2]),
                      B=as.vector(img_seg_t[,,3]))
      df1<-subset(df1, (R+G+B)!=0)
      df1$Var<-VAR
      df1$Time<-OT
      df1$TubNo<-j
      gg[[i]]<-df1
      rm(df1)
    }
  }
}

bdf <- do.call(rbind, gg)
saveRDS(bdf, "./out/TuberColors.RDS")
