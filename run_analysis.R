# Running a real GWAS
# Author: Vivian Link
# Email: linkv@usc.edu
# Date: 2023-10-26
# Description: This script tests genotypes from the 1000 Genomes project for association with phenotypes
# Dependencies: This script calls plink2, GCTA

#-----------------------------------
# definitions and functions
#-----------------------------------

setwd("/data/class_stratification/Data/FullDataLDPruned/provided")
plink_prefix <- "subset"


plot_qq <- function(p_values, MAIN=""){
  unif <- runif(5000)
  qqplot(unif, p_values, xlim=c(0,1), ylim=c(0,1), main=MAIN, xlab="", ylab="", bty='n', xaxt='n', yaxt='n', pch=20)
  axis(side=1, at=seq(0,1,by=0.2), labels = c(0,seq(0.2,0.8,by=0.2),1)) 
  axis(side=2, at=seq(0,1,by=0.2), labels = c(0,seq(0.2,0.8,by=0.2),1), las=2)
  title(ylab="p", line=2.8)
  title(xlab="Uniform(0,1)", line=2.2)
  abline(a=0, b=1)
}

plot_manhattan_chr_plink2 <- function(association_results_plink, CHR, MAIN=""){
  association_results_plink_chr <- association_results_plink[association_results_plink$X.CHROM == CHR,]
  association_results_plink_chr <- association_results_plink_chr[association_results_plink_chr$TEST == "ADD",]
  plot(x=association_results_plink_chr$POS, y=-log10(association_results_plink_chr$P), ylim=c(0,20), xlab= "pos [bp]", ylab="-log10(p-values)", main=MAIN)
  abline(h=-log10(5*(10^-8)), col="red", lty=2)
}

plot_manhattan_chr_GCTA <- function(association_results_GCTA, CHR, MAIN=""){
  association_results_GCTA <- association_results_GCTA[association_results_GCTA$Chr == CHR,]
  plot(x=association_results_GCTA$bp, y=-log10(association_results_GCTA$p), ylim=c(0,20), xlab= "pos [bp]", ylab="-log10(p-values)", main=MAIN)
  abline(h=-log10(5*(10^-8)), col="red", lty=2)
}

#--------------------------------------------------------------------------------------------------------
# part 1: run association with plink
#--------------------------------------------------------------------------------------------------------

# run plink without covariates
command <- paste("plink2 --bfile ", plink_prefix," --glm allow-no-covars --out ", plink_prefix, sep='')
system(command)

#--------------------------------------------------------------------------------------------------------
# part 2: read in the association results and write function to plot them for chr 1, then use it to plot results
#--------------------------------------------------------------------------------------------------------

# read in plink results
associations <- read.table(paste(plink_prefix,".PHENO1.glm.linear", sep=''), header=TRUE, comment.char="")

# plot results
plot_manhattan_chr_plink2(associations, CHR=1)

#? why are some p-values NA? Maybe because it's the ones that are not polymorphic? need to check

#--------------------------------------------------------------------------------------------------------
# part 3: run PCA with plink and plot loadings for PC1 and PC2
#--------------------------------------------------------------------------------------------------------

# # run plink pca
command <- paste("plink2 --bfile ", plink_prefix," --pca 10 --out ", plink_prefix, sep='')
system(command)

# plot PCA
PC_loadings <- read.table(paste(plink_prefix,".eigenvec", sep=''), header=FALSE)
colnames(PC_loadings) <- c("Zero", "Individual", paste("PC", 1:10, sep=''))
plot(x=PC_loadings$PC1, y=PC_loadings$PC2, xlab="PC1", ylab="PC2")

# plot PCA with different colors for each population label
pop_info <- read.csv("sample_names.csv", header=TRUE, sep=',')
PC_loadings <- merge(PC_loadings, pop_info, by="Individual")
colors <- rep("black", nrow(PC_loadings))
colors[PC_loadings$Population == "TSI"] <- "blue"
colors[PC_loadings$Population == "JPT"] <- "red"
plot(x=PC_loadings$PC1, y=PC_loadings$PC2, col = colors, xlab="PC1", ylab="PC2")
legend("topleft", legend=c("CDX", "TSI", "JPT"), pch=1, col=c("black", "blue", "red"), bty='n')

#? can you say something about the positioning of the populations in the PCA plot?

#--------------------------------------------------------------------------------------------------------
# part 4: run association while correcting for structure with PCs and plot
#--------------------------------------------------------------------------------------------------------

# run plink with covariates
command <- paste("plink2 --bfile ", plink_prefix," --glm --out ", plink_prefix, "_withPCCorrection --covar ", plink_prefix, ".eigenvec", sep='')
system(command)


# read in plink results
associations_withPCCorrection <- read.table(paste(plink_prefix,"_withPCCorrection.PHENO1.glm.linear", sep=''), header=TRUE, comment.char="")
plot_manhattan_chr_plink2(associations_withPCCorrection, CHR=1, MAIN="PC stratification correction")


#--------------------------------------------------------------------------------------------------------
# part 5: Check p-value distribution
#--------------------------------------------------------------------------------------------------------
# plot QQ
pdf(paste(plink_prefix,"_qqplots.pdf", sep=''), width=8, height=4)
par(mfrow=c(1,2))
plot_qq(associations$P, MAIN="not corrected")
plot_qq(associations_withPCCorrection$P, MAIN="PC corrected")
dev.off()


# # make GRM with plink
# command <- paste("plink2 --bfile ", plink_prefix," --fam ",plink_prefix,"_withPheno.fam --make-grm-bin --out ", plink_prefix, sep='')
# system(command)

#--------------------------------------------------------------------------------------------------------
# part 5: Use GCTA to run GWAS with GRM
#--------------------------------------------------------------------------------------------------------

# GWAS with GRM
# download gcta https://yanglab.westlake.edu.cn/software/gcta/#Download
command <- paste("gcta-1.94.1-linux-kernel-3-x86_64/gcta-1.94.1 --mlma-loco --bfile ", plink_prefix, " --out ", plink_prefix, " --pheno ", plink_prefix, ".fam --mpheno 4", sep='')
# command <- paste("plink2 --bfile ", plink_prefix," --fam ",plink_prefix,"_withPheno.fam --glm --out ", plink_prefix, "_withGRMCorrection --make-rel on-the-fly --covar ", plink_prefix, ".eigenvec", sep='')
system(command)
associations_withGRMCorrection <- read.table(paste(plink_prefix,".loco.mlma", sep=''), header=TRUE)

#--------------------------------------------------------------------------------------------------------
# part 6: plot association
#--------------------------------------------------------------------------------------------------------

# plot associations

par(mfrow=c(1,1))
plot_manhattan_chr_GCTA(association_results_GCTA=associations_withGRMCorrection, CHR=1, MAIN="GRM stratification correction")

#--------------------------------------------------------------------------------------------------------
# part 7: plot QQ
#--------------------------------------------------------------------------------------------------------

# plot QQ
pdf(paste(plink_prefix,"_qqplots.pdf", sep=''), width=12, height=4)
par(mfrow=c(1,3))
plot_qq(associations$P, MAIN="not corrected")
plot_qq(associations_withPCCorrection$P, MAIN="PC corrected")
plot_qq(associations_withGRMCorrection$p, MAIN="GRM corrected")
dev.off()
# plink2 --bfile filtered_data --linear --rel-cutoff 0.125 --covar grm_output.genome --covar-name KING-IBD --out gwas_output


