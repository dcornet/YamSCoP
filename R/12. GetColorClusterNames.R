# Libraries loading ----------------------------------------------------
packs <- c( "tidyverse", "colordistance", "png", "factoextra")
InstIfNec<-function (pack) {
  if (!do.call(require,as.list(pack))) {
    do.call(install.packages,as.list(pack))  }
  do.call(require,as.list(pack)) }
lapply(packs, InstIfNec)


df<-readRDS("./out/TuberColors.RDS")



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