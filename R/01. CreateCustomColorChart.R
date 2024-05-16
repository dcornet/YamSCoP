################################################################################
### Author: Cornet Denis                                                     ###
### Date Created: 4 Novembre 2020                                            ###   
### Last modified: 13 May 2024                                               ###
### Contributors: /                                                          ###
### Version: 0.9.1                                                           ###
################################################################################
#
#
## Description:
# This script help the user to build a custom color chart. 
# It is using  available images on his computer to choose relevant colors 
# for the chart. User can customize, the number of color patch present on 
# the chart. A dedicated patch is always kept for pure white. 
#
#
## Usage:
# The script requires the following packages: tidyverse, imager, crayon and colorscience. 
# Run the script in RStudio or a similar R environment by sourcing this file.
# Example: source('./R/CreateCustomColorChart.R')
#
#
## Input:
# Path to some example of yam tuber flesh images : "./data/"
# Ensure to have images of the desired object on your drive from which to pick colors.
#
#
## Output:
# Outputs two csv files and two .png files :
#    - ChartColorValues.csv: provide RGB, XYZ and CIE Lab color values for created custom chart
#    - ColorDifferences.csv: provide color differences (dE2000) between each patch of the created color chart
#    - TargetB5_RGB_Lab.png: Image of the created chart with color value label and patch number
#    - TargetB5.png: Image of the created chart to be printed
# Output file path: "./out/CustomColorChart/"
#
#
## License:
# Distributed under the GNU General Public License v3.0. See CPOPTYING file for details.
#
#
## Additional Notes:
# This script logs its progress to the console and will report on incompatible chart size or
# potential issues with color picked from image (e.g. similar color based on dE2000 distance).

## Actual script code starts below


# Checking if library are available and (down)loading them ---------------------
packs <- c("tidyverse","imager", "crayon", "colorscience")
InstIfNec<-function (pack) {
  if (!do.call(require,as.list(pack))) {
    do.call(install.packages,as.list(pack))  }
  do.call(require,as.list(pack)) }
lapply(packs, InstIfNec)
cat("\014")  

# Initial ex
cat(green("\n\nDear user, first you'll be asked to choose the desired number of color of your custom chart. Right after you'll have to choose the number of rows and columns to fill the chart. Finally, you'll be prompt to choose images on your computer to collect color from. For each image, you'll have to choose 5 pixels corresponding to the desired color."))
output_dir <- "./out/CustomColorChart/"
if (!dir.exists(output_dir)) { dir.create(output_dir, recursive=T)}

# Define user parameters
NbOfColor<-readline(cat(blue("\nEnter the number of color in the desired chart: ")))
NbOfColor<-as.integer(NbOfColor) 
NbOfRow<-readline(cat(blue("\nEnter the number of row in the desired chart: ")))  
NbOfRow<-as.integer(NbOfRow)
NbOfCol<-readline(cat(blue("\nEnter the number of column in the desired chart: "))) 
NbOfCol<-as.integer(NbOfCol)
if(NbOfRow*NbOfCol!=NbOfColor) stop("\n \nERROR:\nThe number of color do not match the number of cells in the chart. Please restart the script and ensure that:
Column number * Row number = Number of color")

cat(green(paste0("Within the ", NbOfColor, " colors you choosed, 1 will automatically be the white. So you'll only be asked to choose ", NbOfColor-1, " images to determine the remaining colors of your chart.")))

# Picking color from pics
df<-data.frame(ImageNb=NA, FileName=NA, R=NA, G=NA, B=NA, X=NA, Y=NA, Z=NA, L=NA, 
               a=NA, b=NA, Coul=NA)
for (i in 1:(NbOfColor-1)) {
  cat(red(paste0("\nPicking color N°", i, "\n")))
  cat(green("\nPlease choose an image on which you'll be asked to pick a specific color\n"))
  FileName=file.choose()
  image<-load.image(FileName)
  image<-resize(image, 600, 400) # TODO: check if size is already <600
  cat(green("\nPlease click on 5 pixels corresponding to the desired color\n"))
  par(mar=c(0,0,0,0))
  plot(image)
  xy<-as.data.frame(lapply(locator(5), round, 0))
  RGB<-cbind(diag(image[xy$x, xy$y,1,1]), diag(image[xy$x, xy$y,1,2]),
             diag(image[xy$x, xy$y,1,3]))
  df[i,]<-c(i, FileName, round(mean(RGB[,1])*255,0), round(mean(RGB[,2])*255,0),
            round(mean(RGB[,3])*255,0), rep(NA, 7)) # to use with RGB loading
  # df[i,]<-c(i, FileName, round(mean(RGB[,3])*255,0), round(mean(RGB[,2])*255,0),
  #           round(mean(RGB[,1])*255,0), rep(NA, 7)) # to use with BRG loading
}

# Add reference white
White<-c(NbOfColor, "Reference White", 255, 255, 255, rep(NA, 7))
df<-rbind(df, White)
df[, -c(1:2)] <- sapply(df[, -c(1:2)],as.numeric)

# Get color values in other usefull colorspaces
for (i in 1:nrow(df)) {
  df[i, 6:8]<-RGB2XYZ(as.numeric(df[i, 3:5])/255)
  df[i, 9:11]<-XYZ2Lab(as.numeric(df[i, 6:8]))
  df[i, 12]<-rgb(df[i,3:5]/255)
}
df$Row<-rep(1:NbOfRow, NbOfCol)
df$Col<-rep(1:NbOfCol, each=NbOfRow)
df$PatchNb<-1:NbOfColor
df$TextColor<-ifelse((df$L/100) > 0.179, "black", "white")

# Save produced charts
png(height=9.8, width=6.9, res=300, filename="./out/CustomColorChart/TargetB5.png",
    units="in", type="cairo",family="Garamond")
g<-ggplot(data=df, aes(Col, Row))+
  geom_tile(color="black", linewidth=3, fill=df$Coul)+
  theme_void()+
  theme(legend.position="none", plot.background=element_rect(fill="black"))
print(g)
dev.off()

png(height=9.8, width=6.9, res=300, filename="./out/CustomColorChart/TargetB5_RGB_Lab.png",
    units="in", type="cairo",family="Garamond")
g<-ggplot(df, aes(Col, Row))+
  geom_tile(color="black", linewidth=3, fill=df$Coul)+
  theme_void()+
  geom_text(aes(x=Col, y=Row+0.3, label=PatchNb), color=df$TextColor, size=12)+
  geom_text(aes(x=Col, y=Row+0.1, label=paste0("RGB (", R, ",", G, ",", B, ")")), 
            size=4, color=df$TextColor)+
  geom_text(aes(x=Col, y=Row, label=paste0("XYZ (", round(X,2), ",", 
                                           round(Y, 2), ",", round(Z, 2), ")")), 
            size=4, color=df$TextColor)+
  geom_text(aes(x=Col, y=Row-0.1, label=paste0("Lab (", round(L,0), ",", 
                                               round(a, 0), ",", round(b, 0), ")")), 
            size=4, color=df$TextColor)+
theme(legend.position="none", plot.background=element_rect(fill= "black"))
print(g)
dev.off()

# Calculation of color differences between selected patches
cb<-combn(df$PatchNb, 2)
dE<-data.frame(PatchNb1=NA, PatchNb2=NA, dE2000=NA)
for (i in 1:ncol(cb)) {
  dE[i,]<-c(cb[,i], deltaE2000(t(df[cb[,i][1], c("R", "G", "B")])[,1], 
                               t(df[cb[,i][2], c("R", "G", "B")])[,1]))
}
dE<-dE[order(dE$dE2000),]

if (min(dE$dE2000)<2) {
  cat(red("\nWarning: if deltaE2000 value is less than 2, only experienced observer can notice the difference between 2 colors. It is the case for some colors you selected. Please refer to output file ColorDifferences.csv for further detail. You may want to change some of these colors with more contrasted ones."))
} else { 
  cat(green("\nWell done! You'll find all files (png and csv) in the ./out/CustomColorChart/ folder of this R project."))
}

# Saving data frames
write.csv2(df[,-c(15,16)], "./out/CustomColorChart/ChartColorValues.csv", row.names =F)
write.csv2(dE, "./out/CustomColorChart/ColorDifferences.csv", row.names =F)