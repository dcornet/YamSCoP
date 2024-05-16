################################################################################
### Author: Cornet Denis                                                     ###
### Date Created: 4 Novembre 2020                                            ###   
### Last modified: 13 May 2024                                               ###
### Contributors: /                                                          ###
### Version: 0.9.1                                                           ###
################################################################################

## Description:
# This script performs batch processing on a set of images to convert them from
# NEF to JPG format. It uses parallel processing to speed up the conversion of
# multiple images simultaneously.

## Usage:
# Required packages: tidyverse, magick, parallel, foreach, doParallel
# This script automatically checks for and installs missing packages.
# Run this script in RStudio or a similar R environment by sourcing this file:
# Example: source('./R/BatchImageProcessing.R')

## Input:
# The script reads metadata from a previously generated CSV file at './out/Picsmeta.csv'.
# It expects this file to contain paths to NEF images stored in the column 'SourceFile'.

## Output:
# Outputs converted JPG images to the directory './out/JPGconvertedPics/'.
# Each image is named according to its associated variable and timestamp from the metadata.

## License:
# Distributed under the GNU General Public License v3.0. See COPYING file for details.

## Additional Notes:
# The script checks the number of available processing cores and adjusts the number of cores
# used for parallel processing to prevent overloading the system.

## Actual script code starts below
# --------------------------------

# Libraries loading
packs <- c("tidyverse", "magick", "parallel", "foreach", "doParallel")
InstIfNec<-function (pack) {
  if (!do.call(require,as.list(pack))) {
    do.call(install.packages,as.list(pack))  }
  do.call(require,as.list(pack)) }
lapply(packs, InstIfNec)


# Batch analysis ----------------------------------------------------------
# Load information about images
dp<-read.csv2('./out/Picsmeta.csv')
allpics<-dp$SourceFile

# Get cluster ready
NbNodeForYou<-detectCores()
# Keep two core for current tasks and use others for processing images
NbofNodeKeptForCurrentTask<-2 
cl <- makeCluster(NbNodeForYou-NbofNodeKeptForCurrentTask)
registerDoParallel(cl)

# Perform operations on each file in parallel
foreach(afile = allpics, .packages = "magick", .errorhandling = 'pass') %dopar% {
  # Get file info
  # afile<-allpics[5] 
  # run this to test every single line 1 by 1 inside the for loop
  dps<-subset(dp, SourceFile==afile) 
  Var<-as.character(dps$Var)
  OxyTime<-dps$Time
  
  # Read .NEF files and convert them to JPG
  raw_image <- image_read(afile) # plot(raw_image)
  # Resizing is done only for the purpose of the example. For real study it 
  # is better to keep quality and average color indices rather than color values
  resized_image <- image_resize(raw_image, "1400x") 
  output_dir <- "./out/JPGconvertedPics/" 
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }
  output_path <- paste0(output_dir, Var, "_", OxyTime, ".JPG")
  image_write(resized_image, path = output_path, format = "jpg", quality=75) 
  # don't forget to keep it at 100 for real analysis
}
stopCluster(cl)
