################################################################################
### Author: Cornet Denis                                                     ###
### Date Created: 4 Novembre 2020                                            ###   
### Last modified: 13 May 2024                                               ###
### Contributors: /                                                          ###
### Version: 0.9.1                                                           ###
################################################################################

## Description:
# This script processes images to extract EXIF data and performs an analysis 
# to prepare data for a study on color balance and camera settings in photography.
# It focuses on yam tuber color samples to study variations under different camera settings.

## Usage:
# Required packages: tidyverse, exifr
# This script automatically checks for and installs missing packages.
# Run this script in RStudio or a similar R environment by sourcing this file:
# Example: source('./R/TuberColorSampleAnalysis.R')

## Input:
# Path to example images of yam tuber flesh: "./data/TuberColorSamples/"
# Ensure you have .NEF images of the desired object on your drive.

## Output:
# Outputs a CSV file with metadata extracted from images.
# Output file path: "./out/Picsmeta.csv"

## License:
# Distributed under the GNU General Public License v3.0. See COPYING file for details.

## Actual script code starts below
# --------------------------------

# Libraries loading
packs <- c("tidyverse", "exifr")
InstIfNec<-function (pack) {
  if (!do.call(require,as.list(pack))) {
    do.call(install.packages,as.list(pack))  }
  do.call(require,as.list(pack)) }
lapply(packs, InstIfNec)

# Get data on camera settings
Path="./data/TuberColorSamples/"
files <- list.files(Path, pattern="*.NEF", full.names=T, recursive = T)
df <- read_exif(files)
df<-dplyr::select(df, SourceFile, FileName, CreateDate,
                        Model, ImageWidth, ImageHeight, FocusDistance,
                        FNumber, ExposureTime, ISO, WB_RBLevels, DOF, FOV, 
                        ShutterSpeed, Aperture, Flash, FocalLength,
                        Quality, RedBalance, BlueBalance)


# Data transformation and cleaning
df$id<-df$SourceFile
df$id<-gsub(Path, "", df$id)
df<-separate(df, id, into = c("Var", "Pic"), sep="/")
df$Pic<-gsub(".NEF", "", df$Pic)
df$DateTime<-as.POSIXct(df$CreateDate, format = "%Y:%m:%d %H:%M:%S")
df<-mutate(group_by(df, Var), Nb=rank(DateTime)-1)
df<-ungroup(dplyr::select(df, SourceFile, Var:Nb, Model:BlueBalance))
df<-subset(df, Nb!=0)
df<-mutate(group_by(df, Var), DateTime=as.POSIXct(DateTime), 
           Time=DateTime-lag(DateTime), Time=ifelse(is.na(Time),0,Time),
           Time=cumsum(Time))

# Output the processed data to CSV
write.csv2(df, './out/Picsmeta.csv', col.names = T, row.names = F, sep=";")
