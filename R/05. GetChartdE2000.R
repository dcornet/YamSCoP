################################################################################
### Author: Cornet Denis                                                     ###
### Date Created: 4 Novembre 2020                                            ###   
### Last modified: 13 May 2024                                               ###
### Contributors: /                                                          ###
### Version: 0.9.1                                                           ###
################################################################################

## Description:
# This script calculates the delta E2000 (dE2000) color difference between
# theoretical and observed color values from color patches (before and after
# white correction). It generates visual representations of these differences 
# and assesses variation across multiple measurements. The script handles large
# data sets and uses advanced color science techniques to provide accurate and 
# detailed color analysis.

## Usage:
# Required packages: Rvision, tidyverse, colorscience, imager, foreach, 
# doParallel, gridExtra, randomcoloR
# This script automatically checks for and installs missing packages.
# Run this script in RStudio or a similar R environment by sourcing this file:
# Example: source('./R/ColorDifferenceAnalysis.R')

## Input:
# The script reads processed color data from './out/PicsChartLab.csv' and
# theoretical values from './data/ColorChartTheoreticalValues.csv'.

## Output:
# Outputs include PNG files visualizing the dE2000 differences, saved to './out/'.
# Also, detailed data comparisons are saved as .RDS for further analysis.

## License:
# Distributed under the GNU General Public License v3.0. See COPYING file for details.

## Additional Notes:
# Ensure your system has adequate memory and processing power, as the script is 
# resource-intensive due to its use of high-resolution image data and complex 
# color computations.

## Actual script code starts below


# Libraries loading ----------------------------------------------------
packs <- c( "Rvision", "tidyverse", "colorscience", "imager", 
            "foreach", "doParallel", "gridExtra", "randomcoloR")
InstIfNec<-function (pack) {
  if (!do.call(require,as.list(pack))) {
    do.call(install.packages,as.list(pack))  }
  do.call(require,as.list(pack)) }
lapply(packs, InstIfNec)


# Function definitions ---------------------------------------------------
# Mean deltaE2000 over a whole matrix
getMeanDelta<-function(M1, M2) {
  l<-list()
  for (i in 1:nrow(M1)) {
    a<-deltaE2000(M1[i,], M2[i,])
    l[i]<-a
  }
  mean(unlist(l))
}
# Vector deltaE2000 over a whole matrix
getVectorDelta<-function(M1, M2) {
  l<-list()
  for (i in 1:nrow(M1)) {
    a<-deltaE2000(M1[i,], M2[i,])
    l[i]<-a
  }
  unlist(l)
}

# dE2000 ----------------------------------------------------------------
# Estimation of dE between theoretical and observed color chart value
resfgrw<-read.csv2('./out/PicsChartLab.csv')
xrite_t_Lab<-read.csv("./data/ColorChartTheoreticalValues.csv", sep=";", dec=",")
theorLab<-xrite_t_Lab[, c(1:4)]
colnames(theorLab)<-c("PatchNo", "Lth", "ath", "bth")
resfgrw<-left_join(resfgrw, theorLab, by="PatchNo")
saveRDS(resfgrw, "./out/ColorChart_ObsTheoWC.RDS")

resfgrw$dE<-getVectorDelta(as.matrix(resfgrw[, c(7:9)]), 
                           as.matrix(resfgrw[, c(13:15)]))
resfgrw$dEwc<-getVectorDelta(as.matrix(resfgrw[, c(10:12)]), 
                             as.matrix(resfgrw[, c(13:15)]))
resfgrwl<-pivot_longer(resfgrw, names_to="Pic", values_to="Value", dE:dEwc)
resfgrws<-dplyr::summarize(group_by(resfgrwl, PatchNo, Pic),
                           MEAN=mean(Value), SD=sd(Value))

png(height=6, width=11, res=300, type="cairo",family="Garamond",
    filename="./out/dE_ObsTheoWC.png", units="in")
ggplot(resfgrws, aes(x=factor(PatchNo), y=MEAN, fill=Pic))+
  geom_bar(stat = "identity", position = "dodge")+
  geom_linerange(position=position_dodge(0.9),
                 aes(ymin=MEAN, ymax=MEAN+SD))+
  theme_bw()+
  xlab("Color chart patch number")+
  ylab("CIE delta E2000")+
  theme(legend.position = c(.85,.85))+
  scale_fill_manual(values=c('#d95f02','#7570b3'), 
                    labels=c("Original", "White corrected"))+
  geom_hline(aes(yintercept=mean(subset(resfgrws, Pic=="dE")$MEAN)), 
             color='#d95f02', linetype="dashed")+
  geom_hline(aes(yintercept=mean(subset(resfgrws, Pic=="dEwc")$MEAN)), 
             color='#7570b3', linetype="dashed")+
  labs(title="Color differences between image and chart theoretical value by color patch",
       caption="(Dashed lines represent average over patches)")
dev.off()
(mean(subset(resfgrws, Pic=="dE")$MEAN))
(mean(subset(resfgrws, Pic=="dEwc")$MEAN))

# delta E between pics
refLab<-resfgrw[1:24, c(3, 7:9)]
refLabwc<-resfgrw[1:24, c(3, 10:12)]
colnames(refLab)<-c("PatchNo", "L_ref", "a_ref", "b_ref")
colnames(refLabwc)<-c("PatchNo", "Lwc_ref", "awc_ref", "bwc_ref")
resss<-left_join(resfgrw, refLab, by="PatchNo")
resss<-left_join(resss, refLabwc, by="PatchNo")
resss$dE_ref<-getVectorDelta(as.matrix(resss[, c(7:9)]), 
                             as.matrix(resss[, c(18:20)]))
resss$dEwc_ref<-getVectorDelta(as.matrix(resss[, c(10:12)]), 
                               as.matrix(resss[, c(21:23)]))
resssl<-pivot_longer(resss, names_to="Pic", values_to="Value", dE_ref:dEwc_ref)
ressss<-dplyr::summarize(group_by(resssl, PatchNo, Pic),
                         MEAN=mean(Value), SD=sd(Value))

png(height=6, width=11, res=300, type="cairo",family="Garamond",
    filename="./out/dE_BetweenPics.png", units="in")
ggplot(ressss, aes(x=factor(PatchNo), y=MEAN, fill=Pic))+
  geom_bar(stat = "identity", position = "dodge")+
  geom_linerange(position=position_dodge(0.9),
                 aes(ymin=MEAN, ymax=MEAN+SD))+
  theme_bw()+
  xlab("Color chart patch number")+
  ylab("CIE delta E2000")+
  theme(legend.position = c(.85,.85))+
  scale_fill_manual(values=c('#d95f02','#7570b3'), 
                    labels=c("Original", "White corrected"))+
  geom_hline(aes(yintercept=mean(subset(ressss, Pic=="dE_ref")$MEAN)), 
             color='#d95f02', linetype="dashed")+
  geom_hline(aes(yintercept=mean(subset(ressss, Pic=="dEwc_ref")$MEAN)), 
             color='#7570b3', linetype="dashed")+
  labs(title="Color differences between images by color patch",
       caption="(Dashed lines represent average over patches)")
dev.off()
(mean(subset(ressss, Pic=="dE_ref")$MEAN))
(mean(subset(ressss, Pic=="dEwc_ref")$MEAN))

png(height=8, width=10, res=300, type="cairo",family="Garamond",
    filename="./out/dE_BetweenPics_ByGenotype.png", units="in")
ggplot(resssl, aes(x=factor(PatchNo), y=Value))+
  geom_jitter(aes(color=Var), alpha=.9, size=1.5, width = .2)+
  geom_boxplot(color="black", fill="transparent", outlier.alpha=0)+
  facet_grid(Pic~.)+
  theme_bw()+
  theme(axis.title.y=element_blank())+
  xlab('Color chart patch number')+
  scale_color_manual(values=c('#1f78b4','#33a02c', '#ff7f00',
                              '#6a3d9a'))
dev.off()

png(height=6, width=10, res=300, type="cairo",family="Garamond",
    filename="./out/dE_ByPatchNo&Var.png", units="in")
ggplot(resssl, aes(x=reorder(Var, Value), y=Value))+
  geom_jitter(size=1.5, width = .2, aes(color=factor(PatchNo)))+
  geom_boxplot(color="black", fill="transparent", outlier.alpha=0)+
  facet_grid(Pic~.)+
  theme_bw()+
  theme(axis.title=element_blank(), legend.position="bottom",
        axis.text.x=element_text(angle=60, vjust=1, hjust=1))+
  scale_color_manual("Chart color Nb", values = distinctColorPalette(24))+ 
  guides(color = guide_legend(nrow = 2))
dev.off()