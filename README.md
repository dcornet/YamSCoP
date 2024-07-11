# YamSCoP: Yam tuber Shape and Color Phenotyping Pipeline

![Pipeline](https://github.com/dcornet/YamSCoP/blob/main/Images/YamSCoP_Pipeline.jpg)  

<br>

## Table of Contents
- [Overview](#overview)
- [Projects](#projects)
- [Running Example](#running-example)
- [Image Format and Metadata Management](#image-format-and-metadata-management)
  - [1. Extract EXIF Information from Images](#1-extract-exif-information-from-images)
  - [2. Convert RAW Files to JPG](#2-convert-raw-files-to-jpg)
- [Accuracy and Repeatability of Color Measurements](#accuracy-and-repeatability-of-color-measurements)
  - [1. Create a Custom Color Chart](#1-create-a-custom-color-chart)
  - [2. Extract Color Chart Values from Images](#2-extract-color-chart-values-from-images)
  - [3. Calculate Color Differences between Images and Physical Charts](#3-calculate-color-differences-between-images-and-physical-charts)
  - [4. Obtain White-Corrected Images](#4-obtain-white-corrected-images)
- [Tuber Segmentation](#tuber-segmentation)
  - [1. Generate Initial Tuber Mask](#1-generate-initial-tuber-mask)
  - [2. Extract Tuber Color Matrix](#2-extract-tuber-color-matrix)
- [Interpretation of Color Values](#interpretation-of-color-values)
  - [1. Derive Color Indices](#1-derive-color-indices)
  - [2. Post-Hoc Comparison of Genotypes for Yellowness](#2-post-hoc-comparison-of-genotypes-for-yellowness)
- [Interpretation of tuber color heterogeneity](#interpretation-of-tuber-color-heterogeneity)
  - [1. Cluster Tuber Colors](#1-cluster-tuber-colors)
  - [2. Color Heterogeneity Using Texture Analysis](#2-color-heterogeneity-using-texture-analysis)
- [Interpretation of tuber shape](#interpretation-of-tuber-shape)
  - [1. Characterize Basic Shapes](#1-characterize-basic-shapes)
- [Usage](#usage)
- [Installation](#installation)

<br>

## Overview
YamSCoP (Yam Shape and Color Phenotyping Pipeline) is designed to facilitate comprehensive phenotypic analysis of yams, focusing on both color and shape traits through a series of structured scripts. These scripts process raw image data, extract phenotypic information, and perform basic statistical analysis to understand genetic variations. This project focuses on image analysis. For more information on image acquisition and prerequisites report to the following standard operating protocole: 
<a href="https://github.com/dcornet/YamSCoP/blob/main/Docs/RTBfoods_H.2.2_SOP_Color%20Characterization%20through%20Imaging_RTB%20foods_2019.pdf">
  <img src="https://github.com/dcornet/YamSCoP/blob/main/Images/YamSCoP_SOP1.jpg" alt="SOP1" width="600" />
</a>  

<br>

### Projects
This work was developed as part of two projects funded by the bill and melinda gates foundation: 
* [RTB Foods](https://rtbfoods.cirad.fr/): to encourage a better choice of root, tuber and banana varieties in Africa. The RTBfoods project (Breeding RTB Products for End User Preferences) aims to identify the quality traits that determine the adoption of new root, tuber and banana (RTB) varieties developed by breeders in five African countries (Benin, Cameroon, Côte d'Ivoire, Nigeria and Uganda). Project start date: 01/11/2017 Project end date: 31/10/2022
* [AfricaYam](https://africayamphase2.com/): This IITA-led aims at increasing yam productivity whilst reducing production costs and environmental impact by developing and deploying end-user preferred varieties with higher yield, greater resistance to pests and diseases and improved quality. This project involves a network of research organizations in the four main producer countries of the yam belt: the National Root Crops Research Institute (NRCRI) and the Ebonyi State University (EBSU) in Nigeria; two research institutes under the Council for Scientific and Industrial Research (CSIR) in Ghana (the Crops Research Institute and the Savanna Agricultural Research Institute; the Centre National de Recherche Agronomique (CNRA), Côte d'Ivoire; and the Université d'Abomey-Calavi (UAC), Dassa Center, Benin.  

The final version of this github project was developped to support a training course given at IITA (Ibadan, Nigeria) from 6 to 10 May 2024 for RTB Bredding project partners. Interaction with IITA and the partners has led to considerable improvements in the ergonomics of the scripts and examples provided.

<br>

### Running example
To help you understand and use the analysis pipeline, a set of images is provided in the [./data/TuberColorSample](./data/TuberColorSamples) directory. It includes 4 yam genotypes for which 3 tubers were monitored over time (1 image per minute during 15 minutes). The actual values of the custom reference colour target are provided in CIE Lab colour space values in [./out/PicsChartLab.csv](./out/PicsChartLab.csv). All other files provided in the [./out/](./out/) directory can be produced by the pipeline. Having them available allows the user to test the different pipeline modules independently.  

<br>

## Image Format and Metadata Management 
### 1. Extract EXIF Information from Images
Extracts EXIF information from images, which is crucial for understanding the capture conditions and camera settings used during the phenotyping process.
Ensure you have .NEF images of the desired object on your drive (if not, change the exstension). Some example of yam tuber flesh images are given in the [data](./data/TuberColorSamples) repository.
Outputs a CSV file with metadata extracted from images: [Output file path](./out/Picsmeta.csv) 

<br>

### 2. Convert RAW Files to JPG
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

## Accuracy and Repeatability of Color Measurements  
### 1. Create a Custom Color Chart
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


### 2. Extract Color Chart Values from Images
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

### 3. Calculate Color Differences between Images and Physical Charts
Calculates the Delta E 2000 color difference values (dE2000, [Sharma et al. 2004](http://www.ece.rochester.edu/~gsharma/ciede2000/ciede2000noteCRNA.pdf)) from the color charts between images (repeatability) and against real chart value measured using chromamater (accuracy). This script calculates the dE2000 color difference betweentheoretical and observed color values from color patches (before and after white correction). It generates visual representations of these differences and assesses variation across multiple measurements. The script handles large data sets and uses advanced color science techniques to provide accurate and detailed color analysis. The script reads processed color data from [./out/PicsChartLab.csv](./out/PicsChartLab.csv) and theoretical values from [./data/ColorChartTheoreticalValues.csv](./data/ColorChartTheoreticalValues.csv). Outputs include PNG files visualizing the [dE2000 differences](./out/):  
<img src="https://github.com/dcornet/YamSCoP/blob/main/out/dE_BetweenPics.png" width="900">  

<img src="https://github.com/dcornet/YamSCoP/blob/main/out/dE_ObsTheoWC.png" width="900">  

In order to interpret results, the table below explains how different Delta E values relate to human color perception:  

| Delta E | Perception                              |
|---------|------------------------------------------|
| <= 1.0  | Not perceptible by human eyes.           |
| 1 - 2   | Perceptible through close observation.   |
| 2 - 10  | Perceptible at a glance.                 |
| 11 - 49 | Colors are more similar than opposite.   |
| 100     | Colors are exact opposite.               |

<br>

### 4. Obtain White-Corrected Images
Applies white balancing to images based on color chart data, ensuring that colors are represented accurately in images before analysis. The applied white correction follow [Mendoza et al. 2006](http://dx.doi.org/10.1016/j.postharvbio.2006.04.004).It utilizes color science transformations to convert image colors from RGB to XYZ to Lab and back, applying white balance correction with reference white values derived from theoretical color charts and observed image data. Images are read from [./out/JPGconvertedPics/](./out/JPGconvertedPics/) and color data from [./out/Picsmeta.csv](./out/Picsmeta.csv). Theoretical color values are read from [./data/ColorChartTheoreticalValues.csv](./data/ColorChartTheoreticalValues.csv). Outputs corrected images into [./out/WhiteCorrected/](./out/WhiteCorrected/).  

<br>

## Tuber Segmentation
### 1. Generate Initial Tuber Mask
Creates initial segmentation masks for tubers in images, which are used to isolate and analyze specific tuber regions in subsequent scripts. It processes a series of JPEG images to segment tubers based on color and shape parameters. It utilizes image processing techniques to binarize, denoise, and segment images, extracting shape features for further analysis and keeping segmentation mask for each genotype to be applied later on further image from the same time series. Images are read from [./out/WhiteCorrected/](./out/WhiteCorrected/) and metadata from [./out/Picsmeta.csv](./out/Picsmeta.csv). 
Genotype tuber sgmentation mask is kept in a .RDS file for later analysis. Detailed shape parameters are saved to [./out/BasicShapeParams.csv](./out/BasicShapeParams.csv). Outputs include segmented images and shape parameters results saved in [./out/TuberSegmentation/](./out/TuberSegmentation/):
<img src="https://github.com/dcornet/YamSCoP/blob/main/Images/YamSCoP_Segmentation.jpg" width="900">

<br>

### 2. Extract Tuber Color Matrix
Extracts color data from tuber segments and compiles this into a matrix format for further statistical analysis. This script processes a series of JPEG images from multiple genotypes of tubers to analyze and extract color data. It applies image segmentation masks and resizes images for standardized processing. The script operates in batches, handling images by genotype and time, and compiles color data into a large dataset. Images are loaded from [./out/WhiteCorrected/](./out/WhiteCorrected/) with metadata from [./out/Picsmeta.csv](./out/Picsmeta.csv). Image segmentation masks are read from [./out/InitTuberMask.RDS](./out/InitTuberMask.RDS). Outputs color data for each segmented tuber pixel into [./out/TuberColors.RDS](./out/TuberColors.RDS). Each entry includes the RGB color values and related metadata for the segmented areas.
The script handles large image files and generates substantial data, requiring significant memory and processing power. Ensure adequate system resources are available before running.  

<br>

## Interpretation of Color Values
### 1. Derive Color Indices
Calculates various color indices from the tuber color data, providing detailed insights into the color traits of different yam varieties. This script is designed to calculate and analyze various color indices from tuber images. It converts RGB color values to different color spaces and calculates several indices including whiteness and yellowness. The script further examines the changes in these indices over time and across different genotypes, and conducts statistical analysis including correlation matrices and principal component analysis (PCA) to explore the relationships between the different color traits. Color data for tubers are loaded from [./out/TuberColors.RDS](./out/TuberColors.RDS), which includes segmented image data with RGB values for different tuber sections. 
Available color indices:
| Index               | Equation                                                                                       | Reference                                                                                       | Color Space |
|---------------------|-----------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------|--------------------------------|
| Whiteness index     | $$WI_{Croes} = L - \sqrt{a^2} - b$$                                                           | [Croes 1961](https://www.cerealsgrains.org/publications/cc/backissues/1961/Documents/chem38_8.pdf) | [CIELAB](https://en.wikipedia.org/wiki/CIELAB_color_space) |
| Whiteness index     | $$WI_{Judd}  = 100 - \sqrt{(100 - L)^2 + a^2 + b^2}$$                                         | [Judd and Wyszecki 1963; *In* Hirschler 2012](https://www.researchgate.net/file.PostFileLoader.html?id=562c1fc85f7f715b228b4577&assetKey=AS:288236296523776@1445732296739) | [CIELAB](https://en.wikipedia.org/wiki/CIELAB_color_space) |
| Whiteness index     | $$WI_{Hunter} = L - 3b$$                                                                      | [Hunter 1960](https://opg.optica.org/josa/abstract.cfm?URI=josa-50-1-44)                          | [CIELAB](https://en.wikipedia.org/wiki/CIELAB_color_space) |
| Whiteness index     | $$WI_{ASTM_{E313}} = 100 - \sqrt{(100 - Y)^2 + X^2 + Z^2}$$                                      | [ASTM E313-20](https://www.astm.org/Standards/E313.htm)                                           | [XYZ](https://en.wikipedia.org/wiki/CIE_1931_color_space) |
| Yellowness index    | $$YI_{ASTM_{E313}} = 100 \times \frac{1.3013X - 1.1498Z}{Y}$$                                   | [ASTM E313-20](https://www.astm.org/Standards/E313.htm)                                           | [XYZ](https://en.wikipedia.org/wiki/CIE_1931_color_space) |
| Yellowness index    | $$YI_{Francis} = \frac{142.86b}{L}$$                                                          | [Francis and Clydesdale 1975; *In* Hirschler 2012](https://www.researchgate.net/file.PostFileLoader.html?id=562c1fc85f7f715b228b4577&assetKey=AS:288236296523776@1445732296739) | [CIELAB](https://en.wikipedia.org/wiki/CIELAB_color_space) |
| Yam purpleness index| $$Hue = 180 + \frac{\arctan(\frac{b}{a}) \cdot 180}{\pi} \text{  if } a < 0 \quad \text{else} \quad \frac{\arctan(\frac{b}{a}) \cdot 180}{\pi}$$ | [Jouhar et al. 2022](https://www.mdpi.com/2076-3417/12/14/6841) | [CIELAB](https://en.wikipedia.org/wiki/CIELAB_color_space) |
| Browness index      | $$BI_{Buera} = 100 \cdot \frac{X - 0.31}{0.172} \quad \text{where} \quad X = \frac{a + 1.75L}{5.645L + a - 3.012b}$$ | [Buera et al. 1985; *In* Hirschler 2012](https://www.researchgate.net/file.PostFileLoader.html?id=562c1fc85f7f715b228b4577&assetKey=AS:288236296523776@1445732296739) | [CIELAB](https://en.wikipedia.org/wiki/CIELAB_color_space) |


The script outputs various graphical representations of the color indices analysis, including line plots of color indices over time, bar plots comparing color indices, and correlation matrices. The following two plots illustrate respectively the evolution of color indices over time by genotype and tuber, and the average value of color indices over the three tubers at initial and final observation time and the evolution between these two timestamp (i.e. the slope or the difference): 
<img src="https://github.com/dcornet/YamSCoP/blob/main/out/LinePlot_ColorIndicesOverTimeByGenotype.png" width="900">  

<img src="https://github.com/dcornet/YamSCoP/blob/main/out/BarPlot_ColorIndicesMeanSD%26diffByGenotype.png" width="700">  

Additionally, relationships between variables can be studied using correlation plot or PCA:

<img src="https://github.com/dcornet/YamSCoP/blob/main/out/CorPlot_ColorIndicesMeanSD%26diff.png" width="800">  

<img src="https://github.com/dcornet/YamSCoP/blob/main/out/PCABiplot_ColorIndicesMeanSD%26diff.png" width="400"> <img src="https://github.com/dcornet/YamSCoP/blob/main/out/PCA_ColorIndicesMeanSD%26diff.png" width="400">  

<br>

### 2. Post-Hoc Comparison of Genotypes for Yellowness
Performs statistical comparisons between different yam genotypes based on the extracted color indices, helping to highlight phenotypic differences driven by genetic variation. This script performs a detailed post hoc statistical comparison of the Yellowness index among different genotypes. It utilizes a Bonferroni adjustment for multiple comparisons and generates box plots to visually represent the differences across genotypes, facilitating the identification of significant variations.
Reads data from [./out/ColorIndicesByGeniotypeAndTub.csv](./out/ColorIndicesByGeniotypeAndTub.csv), focusing on Yellowness index values. Generates a box plot visualizing the post hoc comparisons of the Yellowness index across genotypes. The plot is saved to [./out/Boxplot_YelIndexPostHocByGenotype.png](./out/Boxplot_YelIndexPostHocByGenotype.png):  

<img src="https://github.com/dcornet/YamSCoP/blob/main/out/Boxplot_YelIndexPostHocByGenotype.png" width="600">  


<br>


## Interpretation of tuber color heterogeneity
### 1. Cluster Tuber Colors
This R script is designed to analyze and visualize color data from images of tubers. It was mostly adapted from the [colordistance vignette](https://cran.r-project.org/web/packages/colordistance/vignettes/color-spaces.html) from Hannah Weller. It begins by loading necessary libraries and reading data from RDS and CSV files. The script defines several functions to convert RGB values to color names ([X11](https://en.wikipedia.org/wiki/X11_color_names), [NTC](https://chir.ag/projects/ntc/ntc.js) or [XKCD](https://xkcd.com/color/rgb/) color name systems), create images from RGB matrices, and perform clustering analysis. It processes each unique combination of genotype and timestamp, creating images and performing k-means clustering on the color data. The script generates plots to visualize color clusters and their proportions, and combines results across different genotypes and timestamps. Finally, it creates heatmaps to show the color distances between clusters, providing a comprehensive analysis of color variations in the tuber images.
The first clustering method investigated is based on a binning of the 3D RGB color space using getImageHist() function. It allow to plot pixels in a 3D RGB box and to extract average color value for each desired bins from this box:  

<img src="https://github.com/dcornet/YamSCoP/blob/main/Images/YamScop_SegmentedTubersBinnedPxl2.png" width="800">  

To be able to make image-specific color choices we further used k-means clusterin. If an image has important color variation in a narrow region of color space, k-means may be able to pick up on it more easily than a color histogram would. But the number of clusters might change from one image to another. Here we seek for a cluster number allowing to maximize the between-cluster sum of square (BSS) compared to the total sum of square (TSS) with BSS/TSS > 90% :

<img src="https://github.com/dcornet/YamSCoP/blob/main/Images/YamScop_kmeans_clustering2.png" width="800"> 

From the color cluster values, it is then possible to look for the closer color name:

<img src="https://github.com/dcornet/YamSCoP/blob/main/Images/YamScop_kmeans_colName.png" width="600"> 

Dealing wit 4 genotypes followed during time, it is possible to illustrate the color cluster dynamic bteween genotypes:

<img src="https://github.com/dcornet/YamSCoP/blob/main/out/ColorClusterDynamicByVar.png" width="900"> 

And finally we can look at the genotype clustering based on color distances between them:

<img src="https://github.com/dcornet/YamSCoP/blob/main/out/ColorDistanceHeatmaps.png" width="600"> 

<br>


### 2. Color Heterogeneity using texture analysis
- **Description**: This involves using texture analysis methods (e.g., Gray Level Co-occurrence Matrix, GLCM).
- **Application**: Can identify patterns and structures in the color distribution.
- **Quantitative Metric**:
  - **GLCM Contrast**
    - **Definition**: Measures the local variations in the GLCM. It is calculated as the sum of the squared differences from the mean.
    - **Interpretation**: High contrast indicates a high level of local intensity variation, implying a more pronounced texture.
  - **GLCM Dissimilarity**
    - **Definition**: Measures the difference between pairs of pixels. It is similar to contrast but less sensitive to larger intensity differences.
    - **Interpretation**: Higher dissimilarity values indicate greater variation in intensity, representing a rougher texture.
  - **GLCM Homogeneity**
    - **Definition**: Measures the closeness of the distribution of elements in the GLCM to the GLCM diagonal.
    - **Interpretation**: Higher homogeneity values indicate more uniform textures.
  - **GLCM ASM (Angular Second Moment)**
    - **Definition**: Measures the uniformity or energy of the GLCM. It is the sum of the squared elements in the GLCM.
    - **Interpretation**: High ASM values indicate textures with repetitive patterns and lower complexity.
  - **GLCM Entropy**
    - **Definition**: Measures the randomness in the GLCM. It is calculated as the negative sum of the probability of occurrence multiplied by the logarithm of the probability.
    - **Interpretation**: High entropy indicates a more complex texture with higher randomness.
  - **GLCM Mean**
    - **Definition**: The mean intensity of the pixel pairs in the GLCM.
    - **Interpretation**: Represents the average texture intensity.
  - **GLCM Variance**
    - **Definition**: Measures the dispersion of intensities in the GLCM.
    - **Interpretation**: High variance indicates more significant intensity variation.
  - **GLCM Correlation**
    - **Definition**: Measures how correlated a pixel is to its neighbor over the entire image.
    - **Interpretation**: Higher correlation values indicate a more predictable texture pattern.
  - **GLCM SA (Sum Average)**
    - **Definition**: Sum average is the mean of the sums of the elements in the GLCM.
    - **Interpretation**: It is related to the average intensity of the texture.
- **Reference URL**: [GLCM Tutorial](https://www.fp.ucalgary.ca/mhallbey/tutorial.htm)
- **R Library**: The `GLCMTextures` package in R can be used for texture analysis.

```R
install.packages("GLCMTextures")
library(GLCMTextures)
```

<br>

In the exemple hereunder the RGB segmented tuber is turned into greyscale using luminance value. Afterward the GLCM and derivated indices are calculated:

<img src="https://github.com/dcornet/YamSCoP/blob/main/Images/HeterIndices.png" width="800"> 


<br>


## Interpretation of tuber shape
### 1. Characterize Basic Shapes
Analyzes basic shape parameters of yams using image processing techniques to quantify morphological traits that are critical for breed characterization and selection.
This script analyzes the shape parameters of tubers from digitized image data. It adjusts raw measurements for pixel resolution to derive real-world dimensions in millimeters and square centimeters. The script performs statistical comparisons of these shape parameters across different tuber genotypes, using box plots to visually represent variations and conducting post-hoc tests to identify statistically significant differences.
Processes shape data from [./out/BasicShapeParams.csv](./out/BasicShapeParams.csv), which contains various geometric measurements derived from image analysis.
Produces box plots saved as PNG files in './out/', comparing different shape traits across genotypes. The plots include statistical annotations to highlight significant differences:  

<img src="https://github.com/dcornet/YamSCoP/blob/main/out/Boxplot_ShapeParamByGenotype.png" width="600">  


<br>


### 2. More advanced Shape Indices

#### Indices description

##### 1. Compactness

**Definition:**
Compactness is a measure of how closely an object resembles a perfect circle. It is used to quantify the roundness of a shape.

**Method:**
Compactness = (Perimeter^2) / (4 * π * Area)

**Interpretation:**
- A compactness value close to 1 indicates that the shape is very close to a perfect circle.
- Higher values indicate more complex, elongated, or irregular shapes.

**Pros:**
- Simple to calculate.
- Useful for distinguishing between round and irregular shapes.

**Cons:**
- Sensitive to noise and boundary irregularities.
- Does not account for the internal structure of the shape.

##### 2. Circularity Ratio

**Definition:**
Circularity ratio, also known as form factor, is another measure of how similar an object is to a circle.

**Method:**
Circularity Ratio = (4 * π * Area) / (Perimeter^2)

**Interpretation:**
- A circularity ratio of 1 indicates a perfect circle.
- Values less than 1 indicate less circular shapes.

**Pros:**
- Provides a straightforward assessment of circularity.
- Easy to compute.

**Cons:**
- Sensitive to the accuracy of perimeter measurement.
- Less effective for highly irregular shapes.

##### 3. Aspect Ratio

**Definition:**
Aspect ratio is the ratio of the width to the height of the bounding box of an object.

**Method:**
Aspect Ratio = Width / Height

**Interpretation:**
- An aspect ratio of 1 indicates a square shape.
- Values greater or less than 1 indicate elongation in width or height, respectively.

**Pros:**
- Simple and intuitive measure.
- Useful for distinguishing elongated shapes.

**Cons:**
- Does not account for the internal structure or boundary complexity.
- Can be misleading for shapes with irregular boundaries.

##### 4. Fractal Dimension

**Definition:**
Fractal dimension quantifies the complexity of a shape by describing how detail in a pattern changes with the scale at which it is measured.

**Method:**
Commonly calculated using the box-counting method.

**Interpretation:**
- A higher fractal dimension indicates a more complex and detailed boundary.
- Values typically range between 1 (simple curve) and 2 (complex plane-filling curve).

**Pros:**
- Captures boundary complexity and detail.
- Useful for characterizing natural and irregular shapes.

**Cons:**
- Computationally intensive.
- Sensitive to the resolution of the shape representation.

##### 5. Elongation Index

**Definition:**
Elongation index measures how much longer a shape is in one dimension compared to another.

**Method:**
Elongation Index = Length of Major Axis / Length of Minor Axis

**Interpretation:**
- Higher values indicate more elongated shapes.
- Values close to 1 indicate more equidimensional shapes.

**Pros:**
- Easy to understand and compute.
- Useful for identifying elongated structures.

**Cons:**
- Does not capture boundary irregularities.
- Sensitive to the orientation of the shape.

##### 6. Roundness

**Definition:**
Roundness measures how closely the shape of an object approaches that of a circle, considering the smoothness of the object's perimeter.

**Method:**
Different methods exist, but one common method is:
Roundness = (4 * Area) / (π * (Major Axis Length)^2)

**Interpretation:**
- A value close to 1 indicates a round shape.
- Lower values indicate less round and more elongated shapes.

**Pros:**
- Intuitive measure for assessing shape roundness.
- Useful for geological and biological shape analysis.

**Cons:**
- Does not capture boundary detail or complexity.
- Sensitive to the definition of major axis length.

##### 7. Solidity

**Definition:**
Solidity is the ratio of the area of the shape to the area of its convex hull.

**Method:**
Solidity = Area of Shape / Area of Convex Hull

**Interpretation:**
- A solidity value of 1 indicates no concavities (perfectly convex shape).
- Lower values indicate more concave regions.

**Pros:**
- Captures the concavity of the shape.
- Useful for identifying irregular and concave shapes.

**Cons:**
- Does not differentiate between types of concavities.
- Sensitive to noise and small boundary variations.


## Usage
Each script is standalone but designed to be run sequentially as part of the pipeline. Detailed instructions on how to execute each script can be found at the top of the script files.

<br>

## Installation
Ensure R is installed on your machine along with the necessary packages:

### Color Science and Manipulation
- [colorscience](https://cran.r-project.org/web/packages/colorscience/vignettes/colorscience.html) - For color science calculations and transformations.
- [farver](https://cran.r-project.org/web/packages/farver/vignettes/farver.html) - For high-performance color space manipulation.
- [randomcoloR](https://cran.r-project.org/web/packages/randomcoloR/vignettes/randomcoloR.html) - For generating distinct colors for data visualization.
- [colordistance](https://cran.r-project.org/web/packages/colordistance/vignettes/colordistance.html) - For comparing images based on color content.

### Image Processing and Analysis
- [EBImage](https://bioconductor.org/packages/release/bioc/vignettes/EBImage/inst/doc/EBImage-introduction.html) - For image processing and analysis (used in image-based scripts).
- [exifr](https://cran.r-project.org/web/packages/exifr/vignettes/exifr.html) - Reads EXIF data using ExifTool and returns results as a data frame.
- [imager](https://cran.r-project.org/web/packages/imager/vignettes/imager.html) - For image processing and analysis.
- [magick](https://cran.r-project.org/web/packages/magick/vignettes/intro.html) - For advanced image processing capabilities.
- [Rvision](https://cran.r-project.org/web/packages/Rvision/vignettes/Rvision.html) - For image processing and analysis, particularly in handling and analyzing image data in R.
- [png](https://cran.r-project.org/web/packages/png/vignettes/png.pdf) - For reading and writing PNG images.

### Data Analysis and Visualization
- [factoextra](https://cran.r-project.org/web/packages/factoextra/vignettes/factoextra.html) - For visualizing results from FactoMineR.
- [FactoMineR](https://cran.r-project.org/web/packages/FactoMineR/vignettes/FactoMineR.html) - For exploratory and multivariate data analysis.
- [ggcorrplot](https://cran.r-project.org/web/packages/ggcorrplot/vignettes/ggcorrplot.html) - For visualizing correlation matrices.
- [ggpubr](https://cran.r-project.org/web/packages/ggpubr/vignettes/ggpubr.html) - For creating easily publishable ggplot2 plots.
- [gridExtra](https://cran.r-project.org/web/packages/gridExtra/vignettes/arrangeGrob.html) - For arranging multiple grid-based plots.
- [psych](https://cran.r-project.org/web/packages/psych/vignettes/overview.pdf) - For psychological, psychometric, and personality research.
- [tidyverse](https://cran.r-project.org/web/packages/tidyverse/vignettes/tidyverse.html) - For data manipulation and visualization.
- [grid](https://cran.r-project.org/web/packages/grid/vignettes/grid.pdf) - For graphics functions.
- [grDevices](https://cran.r-project.org/web/packages/grDevices/vignettes/grDevices.pdf) - For base graphic devices and support for color handling.

### Parallel Computing
- [doParallel](https://cran.r-project.org/web/packages/doParallel/vignettes/gettingstartedParallel.html) - For parallel computing capabilities.
- [foreach](https://cran.r-project.org/web/packages/foreach/vignettes/foreach.html) - For executing looping constructs.
- [parallel](https://cran.r-project.org/web/packages/parallel/vignettes/parallel.pdf) - For support for parallel computation.

### Statistical Modeling and Analysis
- [inti](https://cran.r-project.org/web/packages/inti/vignettes/inti.html) - For genetic statistics such as heritability.
- [lme4](https://cran.r-project.org/web/packages/lme4/vignettes/lmer.html) - For fitting linear mixed-effects models.
- [lmerTest](https://cran.r-project.org/web/packages/lmerTest/vignettes/lmerTest.html) - To provide p-values for linear mixed-effect models.
- [multcomp](https://cran.r-project.org/web/packages/multcomp/vignettes/multcomp.html) - For conducting multiple comparisons.


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

