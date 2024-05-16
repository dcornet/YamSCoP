# YamSCoP: Yam Shape and Color Phenotyping Pipeline

![Pipeline](https://github.com/dcornet/YamSCoP/assets/5694013/fa2a1a0b-3288-4491-ac1b-e70c0120faeb)  

## Overview
YamSCoP (Yam Shape and Color Phenotyping Pipeline) is designed to facilitate comprehensive phenotypic analysis of yams, focusing on both color and shape traits through a series of structured scripts. These scripts process raw image data, extract phenotypic information, and perform advanced statistical analysis to understand genetic variations and their implications on yam phenotypes.    
This project focuses on image analysis. For more information on image acquisition and prerequisites: 
<a href="https://github.com/dcornet/YamSCoP/blob/main/Docs/RTBfoods_H.2.2_SOP_Color%20Characterization%20through%20Imaging_RTB%20foods_2019.pdf">
  <img src="https://github.com/dcornet/YamSCoP/blob/main/Images/YamSCoP_SOP1.jpg" alt="SOP1" width="600" />
</a>  

<br>

## Scripts Description  
### 1. Create Custom Color Chart
Generates a custom color chart from images, allowing users to select specific color ranges and create a standardized color reference for image analysis. User can customize, the number of color patch present on the chart. A dedicated patch is always kept for pure white. Some example of yam tuber flesh images are given in the [data](./data) repository.
Outputs two csv files and two .png files :
* [ChartColorValues.csv](./out/CustomColorChart/ChartColorValues.csv): provide RGB, XYZ and CIE Lab color values for created custom chart
* [ColorDifferences.csv](./out/CustomColorChart/ColorDifference.csv): provide color differences (dE2000) between each patch of the created color chart
* [TargetB5_RGB_Lab.png](./out/CustomColorChart/TargetB5_RGB_Lab.png): Image of the created chart with color value label and patch number
* [TargetB5.png](./out/CustomColorChart/TargetB5.png): Image of the created chart to be printed
[Output file path](./out/CustomColorChart)
<img src="./out/CustomColorChart/TargetB5_RGB_Lab.png" width="25%">
<p>This script logs its progress to the console and will report on incompatible chart size or potential issues with color picked from image (e.g. similar color based on dE2000 distance).</p>

<br>

### 2. Get Picture Exif Information
Extracts EXIF information from images, which is crucial for understanding the capture conditions and camera settings used during the phenotyping process.
Ensure you have .NEF images of the desired object on your drive (if not, change the exstension). Some example of yam tuber flesh images are given in the [data](./data/TuberColorSamples) repository.
Outputs a CSV file with metadata extracted from images: [Output file path](./out/Picsmeta.csv) 

<br>

### 3. Convert RAW to JPG
Converts RAW image files to JPG format, preparing them for further processing and analysis in the pipeline. It uses parallel processing to speed up the conversion of multiple images simultaneously. The script reads metadata from a previously generated CSV [file](./out/Picsmeta.csv). It expects this file to contain paths to NEF images stored in the column 'SourceFile'. 
In order to speed up the subsequent processing of images, for example, the .NEF image is resized before being converted to .JPG: 
```R
  raw_image <- image_read(img)
  resized_image <- image_resize(raw_image, "1400x")
```
However, it is preferable to average the colour indices rather than calculating the index from the average of the colour values. This is why, for best results, it is recommended to maintain the quality of the image throughout the analysis without resizing it. The same applies when converting to .JPG, where lossless compression can be imposed using the quality argument:
```R
  image_write(resized_image, path = output_path, format = "jpg", quality=100) 
```
Converted JPG images are outputed to this [directory](./out/JPGconvertedPics/). Each image is named according to its associated genotype and timestamp from the metadata.  

<br>

### 4. Get Picture Color Chart
Analyzes images to retrieve color chart data, which is used to calibrate and correct colors in phenotyping images accurately. Color patch are detected using the simpleBlobDetector function of Rvision package:
```R
   patch<-Rvision::simpleBlobDetector(
     img, 50, 220, 10, 2, 10, filter_by_area=T, min_area=3000, max_area=10000, 
     filter_by_color=F, filter_by_circularity=T, min_circularity=0.6, max_circularity=1,
     filter_by_convexity=F, filter_by_inertia=T
   )
```
'min_area' and 'max_area' arguments should be adapted regardiung the image and chart respective size. It utilizes parallel processing to handle large batches of images efficiently and computes various color metrics including RGB, XYZ, and CIE Lab color values. Additionally, it compares observed color values (from chart on image) against theoretical values (measured with chromameter on the real chart). A white correction is applied following [Mendoza et al. 2006](http://dx.doi.org/10.1016/j.postharvbio.2006.04.004).   
The script reads metadata from a CSV file located at [./out/Picsmeta.csv](./out/Picsmeta.csv) and image files from [./out/JPGconvertedPics/](./out/JPGconvertedPics/) directory.
Outputs several files including [individual patch recognition images](./out/PatchRecognition/), [chart color comparison images](./out/ColorChartTheorVSobs/), and a comprehensive CSV file with [all color data](./out/PicsChartLab.csv):
<img src="https://github.com/dcornet/YamSCoP/blob/main/out/PacthRecognition/Patch_A104_120.JPG" width="600">
<img src="https://github.com/dcornet/YamSCoP/blob/main/out/ColorChartTheorVSobs/A104_120.png" width="300">

<br>

### 5. Get Chart Delta E 2000
Calculates the Delta E 2000 color difference values (dE2000) from the color charts between images (repeatability) and against real chart value measured using chromamater (accuracy). This script calculates the dE2000 color difference betweentheoretical and observed color values from color patches (before and after white correction). It generates visual representations of these differences and assesses variation across multiple measurements. The script handles large data sets and uses advanced color science techniques to provide accurate and detailed color analysis. The script reads processed color data from [./out/PicsChartLab.csv](./out/PicsChartLab.csv) and theoretical values from [./data/ColorChartTheoreticalValues.csv](./data/ColorChartTheoreticalValues.csv). Outputs include PNG files visualizing the [dE2000 differences](./out/).  
*Repeatability:*
<img src="https://github.com/dcornet/YamSCoP/blob/main/out/dE_BetweenPics.png" width="900">  
*Accuracy: Color differences between image and chart theoretical value by color patch, with (orange) and without white correction (purple)*
<img src="https://github.com/dcornet/YamSCoP/blob/main/out/dE_ObsTheoWC.png" width="900">  

Also, detailed data comparisons are saved as .RDS for further analysis.
The table below explains how different Delta E values relate to human color perception.

| Delta E | Perception                              |
|---------|------------------------------------------|
| <= 1.0  | Not perceptible by human eyes.           |
| 1 - 2   | Perceptible through close observation.   |
| 2 - 10  | Perceptible at a glance.                 |
| 11 - 49 | Colors are more similar than opposite.   |
| 100     | Colors are exact opposite.               |

<br>

### 6. Get White Corrected Pictures
Applies white balancing to images based on color chart data, ensuring that colors are represented accurately in images before analysis.

<br>

### 7. Get Initial Tuber Mask
Creates initial segmentation masks for tubers in images, which are used to isolate and analyze specific tuber regions in subsequent scripts.

<br>

### 8. Get Tuber Color Matrix
Extracts color data from tuber segments and compiles this into a matrix format for statistical analysis.

<br>

### 9. Get Color Indices
Calculates various color indices from the tuber color data, providing detailed insights into the color traits of different yam varieties.

<br>

### 10. Compare Genotypes
Performs statistical comparisons between different yam genotypes based on the extracted color indices, helping to highlight phenotypic differences driven by genetic variation.

<br>


### 11. Get Index Heritability
Estimates the heritability of various color indices, providing insights into the genetic control over these traits in yams.

<br>

### 12. Identify Best Timing
Determines the optimal timing for phenotyping based on developmental stages or environmental conditions to ensure consistent and reliable data.

<br>

### 13. Basic Shape Characterization
Analyzes basic shape parameters of yams using image processing techniques to quantify morphological traits that are critical for breed characterization and selection.

<br>

## Usage
Each script is standalone but designed to be run sequentially as part of the pipeline. Detailed instructions on how to execute each script can be found at the top of the script files.

<br>

## Installation
Ensure R is installed on your machine along with the necessary packages:
* colorscience - For color science calculations and transformations.
* doParallel - For parallel computing capabilities.
* EBImage - For image processing and analysis (used in image-based scripts).
* exifr - Reads EXIF data using [ExifTool](https://exiftool.org) and returns results as a data frame.
* factoextra - For visualizing results from FactoMineR.
* FactoMineR - For exploratory and multivariate data analysis.
* farver - For high-performance color space manipulation.
* foreach - For executing looping constructs.
* ggcorrplot - For visualizing correlation matrices.
* ggpubr - For creating easily publishable ggplot2 plots.
* gridExtra - For arranging multiple grid-based plots.
* imager - For image processing and analysis.
* inti - For genetic statistics such as heritability.
* lme4 - For fitting linear mixed-effects models.
* lmerTest - To provide p-values for linear mixed-effect models.
* magick - For advanced image processing capabilities.
* multcomp - For conducting multiple comparisons.
* parallel - For support for parallel computation.
* psych - For psychological, psychometric, and personality research
* randomcoloR - For generating distinct colors for data visualization.
* Rvision - For image processing and analysis, particularly in handling and analyzing image data in R
* tidyverse - For data manipulation and visualization.

<br>

For CRAN package:
```R
install.packages(c("BiocManager""tidyverse", "ggpubr", "lme4", "multcomp", "lmerTest", "psych", "gridExtra", "colorscience", "farver", "inti", "ggcorrplot", "FactoMineR", "factoextra", "magick", "imager", "foreach", "doParallel", "parallel", "randomcoloR"), dependencies = TRUE)
```

For Bioconductor package:
```R
if (!require("BiocManager", quietly = TRUE))
    install.packages("BiocManager")
BiocManager::install("EBImage")
```

For Rvision: visit [RVision installing guidelines](https://swarm-lab.github.io/Rvision/articles/z1_install.html)

