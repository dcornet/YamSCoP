################################################################################
### Author: Cornet Denis                                                     ###
### Date Created: 4 Novembre 2020                                            ###   
### Last modified: 13 May 2024                                               ###
### Contributors: /                                                          ###
### Version: 0.9.1                                                           ###
################################################################################

## Description:
# This script is designed to calculate and analyze various color indices from tuber images. 
# It converts RGB color values to different color spaces and calculates several indices 
# including whiteness and yellowness. The script further examines the changes in these indices 
# over time and across different genotypes, and conducts statistical analysis including 
# correlation matrices and principal component analysis (PCA) to explore the relationships 
# between the different color traits.

## Usage:
# Required packages: tidyverse, colorscience, farver, ggcorrplot, FactoMineR, factoextra
# This script automatically checks for and installs missing packages.
# Run this script in RStudio or a similar R environment by sourcing this file:
# Example: source('./R/AdvancedColorAnalysis.R')

## Input:
# Color data for tubers are loaded from './out/TuberColors.RDS', which includes segmented 
# image data with RGB values for different tuber sections.

## Output:
# The script outputs various graphical representations of the color indices analysis, 
# including line plots of color indices over time, bar plots comparing color indices,
# and correlation matrices. Additionally, PCA results are visualized to identify the 
# principal components of color variation. All outputs are saved to './out/' directory.

## License:
# Distributed under the GNU General Public License v3.0. See COPYING file for details.

## Additional Notes:
# This script is computationally intensive due to the large volume of data and the complex 
# statistical analyses performed. Ensure that adequate computational resources are available.

## Actual script code starts below

# Libraries loading ----------------------------------------------------
packs <- c( "tidyverse", "colorscience", "farver", "ggcorrplot",
            "FactoMineR", "factoextra")
InstIfNec<-function (pack) {
  if (!do.call(require,as.list(pack))) {
    do.call(install.packages,as.list(pack))  }
  do.call(require,as.list(pack)) }
lapply(packs, InstIfNec)


# Load data and estimate color indices ----------------------------------------
# Load informations about images
df<-readRDS("./out/TuberColors.RDS")

# Get color indices # if the df is too big go for data.table package and format
df[,c("L","a","b")]<-convert_colour(df[, c("R","G","B")]*255, from="RGB", to="Lab")
df[,c("H","S","V")]<-convert_colour(df[, c("R","G","B")]*255, from="RGB", to="hsv")
df$WIcroes<-with(df, L-sqrt(a^2)-b) # Croes, A.W. 1961. Measurement of flour whiteness. Cereal Chem.38:8-13
# df$WI<-with(df, 100-sqrt((100-L)^2+a^2+b^2)) # Judd and Wyszecki (1963) => not good
df$Hue<-with(df, ifelse(a<0, 180+atan(b/a)*180/pi, atan(b/a)*180/pi))
df$Chroma<-sqrt(df$a^2+df$b^2) 
df$CIRG<-with(df, (180-Hue)/(L+Chroma)) # Carreno et al 1995 CIRG (McGuire, 1992)
# df$WIhunter<-with(df, L-3*b) # Whitness indice (Hunter 1960) => not usefull
df$YIfc<-with(df, 142.86*b/L) # Yellowness indice (Francis and Clydesdale 1975)
df$X<-with(df, (a+1.75*L)/(5.645*L+a-3.012*b))
df$BI<-with(df, 100*(X-0.31)/.172) 
df$WY<-df$WIcroes/df$YIfc


# Color indices over time -------------------------------------
# Summarize
dfs<-dplyr::summarize(group_by(df, Time, Var, TubNo), 
                      L=mean(L), a=mean(a), b=mean(b),
                      Hue_sd=sd(Hue), Hue=mean(Hue), 
                      Chroma_sd=sd(Chroma), Chroma=mean(Chroma),
                      WIcroes_sd=sd(WIcroes), WIcroes=mean(WIcroes),
                      CIRG_sd=sd(CIRG), CIRG=mean(CIRG), 
                      YIfc_sd=sd(YIfc), YIfc=mean(YIfc), 
                      BI_sd=sd(BI), BI=mean(BI), 
                      WY_sd=sd(BI), WY=mean(BI))

# Plot color indices over time
dfsg<-pivot_longer(ungroup(dfs), names_to = "Index", values_to = "Value",
                   cols =c(Hue, WIcroes, YIfc, BI, WY, WIcroes_sd, Hue_sd))
png(height=6, width=10, res=300, type="cairo",family="Garamond",
    filename="./out/LinePlot_ColorIndicesOverTimeByGenotype.png", units="in")
ggplot(dfsg, aes(Time, Value, group=factor(TubNo)))+
  geom_line(aes(color=factor(TubNo)))+
  facet_grid(Index~Var, scales = "free_y")+
  theme_bw()+
  theme(legend.position="bottom", axis.title.y = element_blank())+
  scale_color_manual("Tuber repetition", values=c('#33a02c', '#ff7f00','#6a3d9a'))
dev.off()

# Color indices and color change -------------------------------------------
# Summarize
dt<-pivot_longer(df, names_to="Index", values_to="Value", 
                 cols=c(Hue, WIcroes, YIfc, BI))
dts<-dplyr::summarize(group_by(dt, Index, Var, TubNo, Time),
                      Mean=mean(Value), SD=sd(Value))
write.csv2(dts, "./out/ColorIndicesOverTime.csv", col.names=T,
           row.names=F, sep=";")
dtss<-dplyr::summarize(group_by(ungroup(dts), Index, Var, TubNo),
                      Mean_i=mean(nth(Mean, 1)),
                      Mean_f=mean(nth(Mean, -1)),
                      SD_i=mean(nth(SD, 1)),
                      SD_f=mean(nth(SD, -1)),
                      Diff=Mean_f-Mean_i,
                      Slope=coef(lm(Mean ~ Time))[2])
dtssg<-pivot_longer(dtss, names_to = "Trait", values_to="Value",
                    cols=c(Mean_i:Slope))
dtssgs<-dplyr::summarize(group_by(ungroup(dtssg), Index, Var, Trait),
                      Mean=mean(Value), SD=sd(Value))

dtssgs$Index<-recode_factor(dtssgs$Index, WIcroes="White index (%) \n(Croes 1961)",
                     BI="Brown index", Hue="Color hue", 
                     YIfc="Yellowness index\n(Francis and Clydesdale 1975)",
                     .ordered=T)
dtssgs$Trait<-recode_factor(dtssgs$Trait, Mean_i="Initial mean",
                            SD_i="Initial sd", Diff="Index difference",
                            Slope="Index slope", Mean_f="Final mean",
                            SD_f="Final sd", .ordered=T)

# Plot color indices and color change
png(height=10, width=8, res=300, type="cairo",family="Garamond",
    filename="./out/BarPlot_ColorIndicesMeanSD&diffByGenotype.png", units="in")
ggplot(dtssgs, aes(reorder(Var, Mean), Mean))+
  geom_col(position = "dodge", aes(fill=Var))+
  geom_linerange(aes(ymin=Mean, ymax=ifelse(Mean>0, Mean+SD, Mean-SD)), 
                 position=position_dodge(width=.9))+
  facet_grid(Trait~Index, scale="free_y")+
  # geom_hline(yintercept=35, linetype="dashed")+
  theme_bw()+
  theme(axis.title=element_blank(), legend.position="none")+
  scale_fill_manual(values=c('#e41a1c','#377eb8','#4daf4a','#984ea3',
                             '#ff7f00','#ffff33'))
dev.off()


# Visualize color Trait and index relationships -----------------------------
# correlation
dtssg$Variable<-paste(dtssg$Index, dtssg$Trait, sep="_")
write.csv2(dtssg, "./out/ColorIndicesByGeniotypeAndTub.csv", col.names=T,
           row.names=F, sep=";")
dtssgl<-pivot_wider(select(ungroup(dtssg), -Trait, -Index), 
                    names_from=Variable, values_from=Value)
scaled_dt<-scale(dtssgl[,3:26])
p.mat<-cor_pmat(scaled_dt)
png(height=10, width=10, res=300, type="cairo",family="Garamond",
    filename="./out/CorPlot_ColorIndicesMeanSD&diff.png", units="in")
ggcorrplot(cor(scale(dtssgl[,3:26])), hc.order=T, p.mat=p.mat,
           insig = "blank", lab=T, digit=1)
dev.off()

# remove highly correlated variables
cormat_dt<-cor(scaled_dt)
cormat_dt[!lower.tri(cormat_dt)] <- 0
scaled_dt.new<-scaled_dt[, !apply(cormat_dt, 2, function(x) any(abs(x)>.95, na.rm=T))]

# Plot PCA
data.pca <- PCA(scaled_dt.new)
summary(data.pca)
png(height=6, width=6, res=300, type="cairo",family="Garamond",
    filename="./out/PCAvar_ColorIndicesMeanSD&diff.png", units="in")
fviz_pca_biplot(data.pca, col.var = "cos2", repel=T, label="var",
             gradient.cols = c("red", "orange", "darkgreen"))+
  theme_bw()
dev.off()

png(height=6, width=6, res=300, type="cairo",family="Garamond",
    filename="./out/PCABiplot_ColorIndicesMeanSD&diff.png", units="in")
fviz_pca_biplot(data.pca, repel=T, label="var", col.var="black",
                col.ind=dtssgl$Var)+
  theme_bw()
dev.off()