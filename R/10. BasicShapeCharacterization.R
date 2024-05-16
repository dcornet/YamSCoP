################################################################################
### Author: Cornet Denis                                                     ###
### Date Created: 4 Novembre 2020                                            ###   
### Last modified: 13 May 2024                                               ###
### Contributors: /                                                          ###
### Version: 0.9.1                                                           ###
################################################################################

## Description:
# This script analyzes the shape parameters of tubers from digitized image data. It adjusts 
# raw measurements for pixel resolution to derive real-world dimensions in millimeters and 
# square centimeters. The script performs statistical comparisons of these shape parameters 
# across different tuber genotypes, using box plots to visually represent variations and 
# conducting post-hoc tests to identify statistically significant differences.

## Usage:
# Required packages: tidyverse, ggpubr
# This script automatically checks for and installs missing packages.
# Run this script in RStudio or a similar R environment by sourcing this file:
# Example: source('./R/TuberShapeAnalysis.R')

## Input:
# Processes shape data from './out/BasicShapeParams.csv', which contains various geometric 
# measurements derived from image analysis.

## Output:
# Produces box plots saved as PNG files in './out/', comparing different shape traits across 
# genotypes. The plots include statistical annotations to highlight significant differences.

## License:
# Distributed under the GNU General Public License v3.0. See COPYING file for details.

## Additional Notes:
# The script requires a solid understanding of morphometric data analysis and statistical 
# significance testing. It's tailored for researchers in plant science or agronomy, focusing 
# on phenotypic trait analysis.

## Actual script code starts below

# Libraries loading ----------------------------------------------------
packs <- c( "tidyverse", "ggpubr")
InstIfNec<-function (pack) {
  if (!do.call(require,as.list(pack))) {
    do.call(install.packages,as.list(pack))  }
  do.call(require,as.list(pack)) }
lapply(packs, InstIfNec)

# Load data
df<-read.csv2("./out/BasicShapeParams.csv", sep=";")

# Get real size with pixel resolution
PicWidth_mm<-800 # mm
PicWidth_pxl<-6016 # pixels
resolution<-PicWidth_mm/PicWidth_pxl #mm/pixel
VarRes<-c("s.area","s.perimeter","s.radius.mean","s.radius.sd","s.radius.min",
          "s.radius.max", "m.majoraxis")
df[, VarRes]<-df[, VarRes]*resolution
df$s.area<-df$s.area*resolution/100 #cm²

# Keep relevant variables
df<-dplyr::select(df, Var, s.area, s.perimeter, s.radius.mean, s.radius.sd,
           m.majoraxis, m.eccentricity)
dfg<-pivot_longer(df, names_to = "Trait", values_to = "Value", 
                  cols=c(s.area, s.perimeter, s.radius.mean, s.radius.sd,
                         m.majoraxis, m.eccentricity))
# dfg<-dplyr::summarize(group_by(dfg, Var, Trait), Mean=mean(Value), SD=sd(Value))
dfg$Trait<-recode_factor(dfg$Trait, 
                        s.area="Projecte\nsurface (cm²)", 
                        s.perimeter="Projected\nperimeter (mm)",
                        s.radius.mean="Projected mean \nradius (mm)",
                        s.radius.sd="Standard deviation of\n projected radius (mm)",
                        m.majoraxis="Projected major axis\nlength (mm)",
                        m.eccentricity="Projected eccentricity", .ordered=T)


# Compute group (genotypes) comparisons by varable (Trait)
png(height=8, width=7, res=300, type="cairo",family="Garamond",
    filename="./out/Boxplot_ShapeParamByGenotype.png", units="in")
ggboxplot(dfg, x="Var", y="Value", ncol=2, scales="free_y", 
          p.adjust.method="bonferroni", p.adjust.by="panel", 
          color="Var", palette="jco", facet.by="Trait") +
  geom_pwc(method="t_test", label="p.adj.signif", ref.group="A104", hide.ns=T,
           vjust = 1)+
  labs(title="Shape",
       subtitle="Post-hoc comparison between genotypes",
       caption="(Reference group: A39, adjustment method: Bonferroni)")+
  theme(legend.position="none", axis.title=element_blank())
dev.off()


# TODO: Use of theta for gradient analysis? OK with elongated tuber but not with digitized