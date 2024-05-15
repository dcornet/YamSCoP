# YamSCoP: Yam Shape and Color Phenotyping Pipeline

## Overview
YamSCoP (Yam Shape and Color Phenotyping Pipeline) is designed to facilitate comprehensive phenotypic analysis of yams, focusing on both color and shape traits through a series of structured scripts. These scripts process raw image data, extract phenotypic information, and perform advanced statistical analysis to understand genetic variations and their implications on yam phenotypes.

## Scripts Description

### 1. Create Custom Color Chart
Generates a custom color chart from images, allowing users to select specific color ranges and create a standardized color reference for image analysis.

### 2. Get Picture Exif Information
Extracts EXIF information from images, which is crucial for understanding the capture conditions and camera settings used during the phenotyping process.

### 3. Convert RAW to JPG
Converts RAW image files to JPG format, preparing them for further processing and analysis in the pipeline.

### 4. Get Picture Color Chart
Analyzes images to retrieve color chart data, which is used to calibrate and correct colors in phenotyping images accurately.

### 5. Get Chart Delta E 2000
Calculates the Delta E 2000 color difference values from the color charts within images, providing a measure of color accuracy and consistency.

### 6. Get White Corrected Pictures
Applies white balancing to images based on color chart data, ensuring that colors are represented accurately in images before analysis.

### 7. Get Initial Tuber Mask
Creates initial segmentation masks for tubers in images, which are used to isolate and analyze specific tuber regions in subsequent scripts.

### 8. Get Tuber Color Matrix
Extracts color data from tuber segments and compiles this into a matrix format for statistical analysis.

### 9. Get Color Indices
Calculates various color indices from the tuber color data, providing detailed insights into the color traits of different yam varieties.

### 10. Compare Genotypes
Performs statistical comparisons between different yam genotypes based on the extracted color indices, helping to highlight phenotypic differences driven by genetic variation.

### 11. Get Index Heritability
Estimates the heritability of various color indices, providing insights into the genetic control over these traits in yams.

### 12. Identify Best Timing
Determines the optimal timing for phenotyping based on developmental stages or environmental conditions to ensure consistent and reliable data.

### 13. Basic Shape Characterization
Analyzes basic shape parameters of yams using image processing techniques to quantify morphological traits that are critical for breed characterization and selection.

## Usage
Each script is standalone but designed to be run sequentially as part of the pipeline. Detailed instructions on how to execute each script can be found at the top of the script files.

## Installation
Ensure R is installed on your machine along with the necessary packages:
```R
install.packages(c("tidyverse", "ggpubr", "lme4", "multcomp", "lmerTest", "psych", "gridExtra", "colorscience", "farver", "inti"))

