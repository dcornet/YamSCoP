################################################################################
### Author: Cornet Denis                                                     ###
### Date Created: 4 Novembre 2020                                            ###   
### Last modified: 13 May 2024                                               ###
### Contributors: /                                                          ###
### Version: 0.9.1                                                           ###
################################################################################

## Description:
# This script performs a detailed post hoc statistical comparison of the Yellowness
# index among different genotypes. It utilizes a Bonferroni adjustment for multiple
# comparisons and generates box plots to visually represent the differences across
# genotypes, facilitating the identification of significant variations.

## Usage:
# Required packages: tidyverse, ggpubr
# This script automatically checks for and installs missing packages.
# Run this script in RStudio or a similar R environment by sourcing this file:
# Example: source('./R/YellownessIndexPostHocComparison.R')

## Input:
# Reads data from './out/ColorIndicesByGeniotypeAndTub.csv', focusing on Yellowness index values.

## Output:
# Generates a box plot visualizing the post hoc comparisons of the Yellowness index across genotypes.
# The plot is saved to './out/Boxplot_YelIndexPostHocByGenotype.png'.

## License:
# Distributed under the GNU General Public License v3.0. See COPYING file for details.

## Additional Notes:
# The script involves statistical tests and multiple comparison adjustments; understanding of 
# statistical methods in the context of biological data analysis is recommended for interpreting 
# the results.

## Actual script code starts below

# Libraries loading ----------------------------------------------------
packs <- c( "tidyverse", "ggpubr")
InstIfNec<-function (pack) {
  if (!do.call(require,as.list(pack))) {
    do.call(install.packages,as.list(pack))  }
  do.call(require,as.list(pack)) }
lapply(packs, InstIfNec)


# Post hoc genotype comparison ----------------------------------------
df<-read.csv2("./out/ColorIndicesByGeniotypeAndTub.csv")

# Keep only Yellowness index for the example
df<-subset(df, Index=="YIfc")
df$Trait<-recode_factor(df$Trait, Mean_i="Initial mean", Mean_f="Final mean",
                        SD_i="Initial sd", SD_f="Final sd",
                        Diff="Index difference", Slope="Index slope", .ordered=T)

# Compute group (genotypes) comparisons by varable (Trait)
png(height=8, width=7, res=300, type="cairo",family="Garamond",
    filename="./out/Boxplot_YelIndexPostHocByGenotype.png", units="in")
ggboxplot(df, x="Var", y="Value", ncol=2, scales="free_y", 
          p.adjust.method="bonferroni", p.adjust.by="panel", 
          color="Var", palette="jco", facet.by="Trait") +
  geom_pwc(method="t_test", label="p.adj.signif", ref.group="A117", hide.ns=T)+
  labs(title="Yellowness Index",
       subtitle="Post-hoc comparison between genotypes",
       caption="(Reference group: A117, adjustment method: Bonferroni)")+
  theme(legend.position="none", axis.title=element_blank())
dev.off()