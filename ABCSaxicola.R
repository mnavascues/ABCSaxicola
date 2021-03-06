# Script to perform an ABC analysis
# Project: Saxicola
# Miguel Navascués 2015
# Miguel.Navascues@supagro.inra.fr

#########################################
# ABC GENERAL SETTINGS
#########################################

nsim <- 100000                         # number of simulations
reftable_file <- "reference_table.txt" # reference table file name
tolerance <- 0.1 #0.01                # tolerance level (proportion of kept simulations)

# Model description
#
#   EARLY       LATE 1       LATE 2
#
#   theta1      theta2       theta3
#  \      / M  |     |      |     |
#   \    / <-> |     |      |     |
#    \  /      |     |      |     |
#  TE ---------|     |      |     |
#              |     |      |     |      
#              |     |      |     |      
#              |     |      |     |      
#              |     |      |     |      
#           TD --------------------     
#                    |      |
#                    |      |
#                    |      |
#                    |      |
#                    |      |
#                     thetaA
#

# write header of reference table 
write.table( cbind( #### PARAMETERS
  "model",      # 0:isolation; 1:isolation with migration
  "theta1",     # theta1        (early)
  "x2",         # theta2/theta1 (late 1)
  "x3",         # theta3/theta1 (late 2)
  "xA",         # thetaA/theta1 (ancestral)
  "alpha",      # growth rate (early)
  "mig12",      # migration
  "mig21",      # migration
  "TE",         # time split of early from late 1
  "TD",         # time split between late 1 and 2
  #### SUMMARY STATISTICS                      
  "m_H_early",    # mean (among loci) heterozygosity
  "v_H_early",    # variance (among loci) of heterozygosity
  "m_H_late_1",
  "v_H_late_1",
  "m_H_late_2",
  "v_H_late_2",
  "m_H_total",
  "v_H_total",
  "m_A_early",   # mean (among loci) number of alleles
  "v_A_early",   # variance (among loci) of number of alleles
  "m_A_late_1",
  "v_A_late_1",
  "m_A_late_2",
  "v_A_late_2",
  "m_A_total",
  "v_A_total"),
  file=reftable_file,sep=" ",
  quote=F,col.names=F,row.names=F,append=F)


#########################################
# DEFINE PRIORS (upper and lower limit)
#########################################

theta1_min <- 0#-3
theta1_max <- 1# 3

x_min <- 0.5#0.01
x_max <- 2#100  

alpha_min  <- 0
alpha_max  <- 1#10

M_min <- 0
M_max <- 1#100

T_min <- 0
T_max <- 10#100

PGSM_min <- 0     # Generalised Stepwise Mutation model parameter 
PGSM_max <- 0.5   # (probability of mutations larger than a single repeat unit)

#########################################
# LOAD REQUIRED FUNCTIONS/PACKAGES
#########################################

# load required libraries
# library(plyr) # for function count() that helps to explore allele size distribution
library(pegas)  # for calculating heterozygosity: function H()
library(abc)    # for approximate Bayesian computation functions
require(hexbin) # for plots of PCA
require(grid)   # for plots of PCA
require(laeken) # necessary? check if it is used...

# Uses RR Hudson coalescent simulator (ms)
# load RR Hudson's R script distributed with ms to read ms output in R
# http://home.uchicago.edu/~rhudson1/source/mksamples.html
source("readms.output.R")

#########################################
# LOAD DATA
#########################################

# read real data file
microsat_data <- read.table("/home/miguel/Work/Research/Illera/Saxicola_Structure.str",header=T)

# deal with missing data (change -9 to NA; record NA positions in data table)
head(microsat_data)
for(locus in 3:ncol(microsat_data)){
  microsat_data[which(microsat_data[,locus]==-9),locus] <- NA
}
missing_data <- which(is.na(microsat_data), arr.ind = T)
missing_data[,2] <- missing_data[,2]-2 # to remove the first two columns

# check size and frequency of alleles
# count(microsat_data, "CAM.02")

# creates vector with the position of individuals belonging to the three populations
Pop_early  <- 1:(match(7,microsat_data$pop)-1)
Pop_late_1 <- match(7,microsat_data$pop):(match(10,microsat_data$pop)-1)
Pop_late_2 <- match(10,microsat_data$pop):length(microsat_data$pop)

# calculates sample sizes for each population (and total) and number of loci
sample_size_early  <- length(Pop_early)
sample_size_late_1 <- length(Pop_late_1)
sample_size_late_2 <- length(Pop_late_2)
sample_size_total  <- sample_size_early + sample_size_late_1 + sample_size_late_2
num_of_loci <- ncol(microsat_data)-2

#########################################
# TARGET SUMMARY STATISTICS
#########################################

# Calculate summary statistics for observed data
# Heterozygosity
H_early  <- apply(microsat_data[Pop_early ,-c(1,2)], 2, function(x) H(as.factor(x)) ) 
m_H_early <- mean(H_early,na.rm=T)
v_H_early <- var(H_early,na.rm=T)
H_late_1 <- apply(microsat_data[Pop_late_1,-c(1,2)], 2, function(x) H(as.factor(x)) ) 
m_H_late_1 <- mean(H_late_1,na.rm=T)
v_H_late_1 <- var(H_late_1,na.rm=T)
H_late_2 <- apply(microsat_data[Pop_late_2,-c(1,2)], 2, function(x) H(as.factor(x)) ) 
m_H_late_2 <- mean(H_late_2,na.rm=T)
v_H_late_2 <- var(H_late_2,na.rm=T)
H_total  <- apply(microsat_data[          ,-c(1,2)], 2, function(x) H(as.factor(x)) ) 
m_H_total <- mean(H_total,na.rm=T)
v_H_total <- var(H_total,na.rm=T)
# Number of alleles
A_early  <- apply(microsat_data[Pop_early ,-c(1,2)], 2, function(x) length(levels(as.factor(x))) ) 
m_A_early <- mean(A_early,na.rm=T)
v_A_early <- var(A_early,na.rm=T)
A_late_1 <- apply(microsat_data[Pop_late_1,-c(1,2)], 2, function(x) length(levels(as.factor(x))) ) 
m_A_late_1 <- mean(A_late_1,na.rm=T)
v_A_late_1 <- var(A_late_1,na.rm=T)
A_late_2 <- apply(microsat_data[Pop_late_2,-c(1,2)], 2, function(x) length(levels(as.factor(x))) ) 
m_A_late_2 <- mean(A_late_2,na.rm=T)
v_A_late_2 <- var(A_late_2,na.rm=T)
A_total  <- apply(microsat_data[          ,-c(1,2)], 2, function(x) length(levels(as.factor(x))) ) 
m_A_total <- mean(A_total,na.rm=T)
v_A_total <- var(A_total,na.rm=T)

# write header of file
write.table( cbind(     "m_H_early",    # mean (among loci) heterozygosity
                        "v_H_early",    # variance (among loci) of heterozygosity
                        "m_H_late_1",
                        "v_H_late_1",
                        "m_H_late_2",
                        "v_H_late_2",
                        "m_H_total",
                        "v_H_total",
                        "m_A_early",   # mean (among loci) number of alleles
                        "v_A_early",   # variance (among loci) of number of alleles
                        "m_A_late_1",
                        "v_A_late_1",
                        "m_A_late_2",
                        "v_A_late_2",
                        "m_A_total",
                        "v_A_total"),
             file="target_sumstats.txt",sep=" ",
             quote=F,col.names=F,row.names=F,append=F)

# write summary statistics to file
write.table( cbind(  m_H_early,    # mean (among loci) heterozygosity
                     v_H_early,    # variance (among loci) of heterozygosity
                     m_H_late_1,
                     v_H_late_1,
                     m_H_late_2,
                     v_H_late_2,
                     m_H_total,
                     v_H_total,
                     m_A_early,   # mean (among loci) number of alleles
                     v_A_early,   # variance (among loci) of number of alleles
                     m_A_late_1,
                     v_A_late_1,
                     m_A_late_2,
                     v_A_late_2,
                     m_A_total,
                     v_A_total),
             file="target_sumstats.txt",sep=" ",
             quote=F,col.names=F,row.names=F,append=T)

#########################################
# SIMULATION
#########################################

for(sim in 1:nsim){
  # write progress of simulation on screen 
  if (sim==1)      cat(paste(sim,"of",nsim))
  if (sim%%100==0) cat(paste(sim,"of",nsim))
  if (sim==nsim)   cat(paste(sim,"of",nsim))

  # SAMPLE FROM PRIOR
  #-------------------
  
  # model (migration OR pure divergence) is sampled from prior
  model <- sample(c(0,1),1)
  
  # take parameter values from priors
  theta1 <- 10^runif( 1, min=theta1_min, max=theta1_max )
  x2     <- runif( 1, min=x_min, max=x_max )
  x3     <- runif( 1, min=x_min, max=x_max )
  xA     <- runif( 1, min=x_min, max=x_max )
  alpha  <- runif( 1, min=alpha_min, max=alpha_max)
  if (model==1){
    mig12   <- runif( 1, min=M_min, max=M_max )
    mig21   <- mig12 # runif( 1, min=0, max=100 )
  }else{
    mig21<-mig12<-0
  }
  TE <- runif( 1, min=T_min, max=T_max )
  TD <- runif( 1, min=TE, max=T_max )
  PGSM <- runif( 1, min=PGSM_min, max=PGSM_max )

  # RUM MS
  #--------
    
  # generate text with ms command
  ms_out_file <- "msout.txt"
  ms_run <- paste( "ms", sample_size_total, num_of_loci,  # total sample size & number of loci
                   "-t", theta1,                          # population size in pop early
                   "-I 3", sample_size_early,      
                           sample_size_late_1,
                           sample_size_late_2,      # sample sizes per population
                   "-n 2", x2,                      # population size in pop late 1
                   "-n 3", x3,                      # population size in pop late 2
                   "-m 1 2", mig12,                 # migration rate between early and late 1
                   "-m 2 1", mig21,
                   "-g 1", alpha,                   # growth rate in pop early
                   "-ej", TE, "1 2",                # creation of pop early from pop late 1
                   "-eM", TE, "0",                  # cancel all migration previous to creation of pop early
                   "-ej", TD, "3 2",                # divergence between pop late 1 and 2
                   "-en", TD, "2", xA,              # population size in pop late ancestral
                   ">", ms_out_file)                # output file
  
  # rum ms on system (unix or windows)
  if(.Platform$OS.type == "unix") {
    ms_run <- paste( "./", ms_run, sep="" )
    system( ms_run )
  }else{
    shell( ms_run )
  }

  # READ SIMULATED DATA AND TRANSFORM TO MICROSATELLITE
  #-----------------------------------------------------
   
  # read simulation output (generated with an infinite site model, ISM)
  msout <- read.ms.output(file=ms_out_file)
  
  # transform simulated data from ISM into microsatellite evolving under GSM
  # (generalised stepwise mutation model)
  mutations <- msout$segsites
  simulated_data <- matrix(NA, nrow=sample_size_total, ncol=num_of_loci)
  for(locus in 1:num_of_loci){
    mutation_size <- rgeom(mutations[locus],1-PGSM)+1
    mutation_size <- mutation_size * sample(c(-1,1),mutations[locus],replace=T)
    simulated_data[,locus] <- 100+colSums(t(msout$gametes[[locus]])*mutation_size)
  }
  # add missing data to simulated data
  for(i in 1:nrow(missing_data)){
    simulated_data[missing_data[i,1],missing_data[i,2]]<-NA
  }
  remove(mutations)
  
  # CALCULATE SUMMARY STATISTICS FOR SIMULATED DATA
  #-------------------------------------------------

  # Heterozygosity
  H_early  <- apply(simulated_data[Pop_early ,], 2, function(x) H(as.factor(x)) ) 
  m_H_early <- mean(H_early,na.rm=T)
  v_H_early <- var(H_early,na.rm=T)
  H_late_1 <- apply(simulated_data[Pop_late_1,], 2, function(x) H(as.factor(x)) ) 
  m_H_late_1 <- mean(H_late_1,na.rm=T)
  v_H_late_1 <- var(H_late_1,na.rm=T)
  H_late_2 <- apply(simulated_data[Pop_late_2,], 2, function(x) H(as.factor(x)) ) 
  m_H_late_2 <- mean(H_late_2,na.rm=T)
  v_H_late_2 <- var(H_late_2,na.rm=T)
  H_total  <- apply(simulated_data[          ,], 2, function(x) H(as.factor(x)) ) 
  m_H_total <- mean(H_total,na.rm=T)
  v_H_total <- var(H_total,na.rm=T)
  # Number of alleles
  A_early  <- apply(simulated_data[Pop_early ,], 2, function(x) length(levels(as.factor(x))) ) 
  m_A_early <- mean(A_early,na.rm=T)
  v_A_early <- var(A_early,na.rm=T)
  A_late_1 <- apply(simulated_data[Pop_late_1,], 2, function(x) length(levels(as.factor(x))) ) 
  m_A_late_1 <- mean(A_late_1,na.rm=T)
  v_A_late_1 <- var(A_late_1,na.rm=T)
  A_late_2 <- apply(simulated_data[Pop_late_2,], 2, function(x) length(levels(as.factor(x))) ) 
  m_A_late_2 <- mean(A_late_2,na.rm=T)
  v_A_late_2 <- var(A_late_2,na.rm=T)
  A_total  <- apply(simulated_data[          ,], 2, function(x) length(levels(as.factor(x))) ) 
  m_A_total <- mean(A_total,na.rm=T)
  v_A_total <- var(A_total,na.rm=T)
  
  
  # WRITE PARAMATERS AND SUMMARY STATISTICS TO REFERENCE TABLE
  #------------------------------------------------------------
  write.table( cbind( ## PARAMETERS
      model,      # 0:isolation; 1:isolation with migration
      theta1,     # theta1        (early)
      x2,         # theta2/theta1 (late 1)
      x3,         # theta3/theta1 (late 2)
      xA,         # thetaA/theta1 (ancestral)
      alpha,      # growth rate (early)
      mig12,      # migration
      mig21,      # migration
      TE,         # time split of early from late 1
      TD,         # time split between late 1 and 2
      #### SUMMARY STATISTICS                      
      m_H_early,    # mean (among loci) heterozygosity
      v_H_early,    # variance (among loci) of heterozygosity
      m_H_late_1,
      v_H_late_1,
      m_H_late_2,
      v_H_late_2,
      m_H_total,
      v_H_total,
      m_A_early,   # mean (among loci) number of alleles
      v_A_early,   # variance (among loci) of number of alleles
      m_A_late_1,
      v_A_late_1,
      m_A_late_2,
      v_A_late_2,
      m_A_total,
      v_A_total),
               file=reftable_file,sep=" ",
               quote=F,col.names=F,row.names=F,append=T)
  
} # end for(sim in 1:nsim)

#########################################
# ABC: REJECTION + REGRESSION
#########################################

# read reference table
ref_table <- read.table("reference_table.txt",header=T)
#dim(ref_table)
#head(ref_table)
#summary(ref_table)

# read target summary statistics
target_sumstats<-read.table("target_sumstats.txt",header=T)

# modify model column in reference table to reflect more intuitevely the two models
ref_table[which(ref_table[,1]==0),1] <- "I"    # Isolation (pure divergence)
ref_table[which(ref_table[,1]==1),1] <- "IM"   # Isolation with Migration (divergence with migration)

# define set of summary statistics to be used (currently: all are used)
sumstats_names <- scan(file="target_sumstats.txt",what=character(),nlines=1)

# estimate posterior probabilities of both models
model_selection_result <- postpr(target  = target_sumstats[sumstats_names],
                                 index   = ref_table[,1],
                                 sumstat = ref_table[,sumstats_names],
                                 tol     = tolerance,
                                 method  = "mnlogistic")
summary(model_selection_result)

# separate referece table into two reference tables (for the two models)
ref_tableIM <- ref_table[which(ref_table[,1]=="IM"),]
ref_tableI  <- ref_table[which(ref_table[,1]=="I") ,]
remove(ref_table)

# ISOLATION WITH MIGRATION
#--------------------------
  
# estimate posterior probability distribution of parameter values
abcresultIM <- abc(target  = target_sumstats[sumstats_names],
                   param   = ref_tableIM[,c(2:7,9:10)],
                   sumstat = ref_tableIM[,sumstats_names],
                   tol     = tolerance,
                   method  = "loclinear",
                   transf  = "log")
summary(abcresultIM)

# calculate principal components for summary statistics from simulations
PCA_stats  <- princomp(ref_tableIM[,sumstats_names])
# predict location of real data in PC space
PCA_target <- predict(PCA_stats, target_sumstats[sumstats_names])
# represent graphically PCA to verify that simulations are producing 
# simulations similar to real data
pdf(file="PCA_IM.pdf", width=11.7, height=8.3)
for (pci in 1:7){
  for (pcj in (pci+1):8){
    hbin<-hexbin(PCA_stats$scores[,pci], PCA_stats$scores[,pcj],xbins=100,xlab=paste("PC",pci),ylab=paste("PC",pcj))
    pp<-plot(hbin,legend=FALSE, main="PCA on summary statistics")
    pushHexport(pp$plot.vp)
    grid.points(PCA_target[pci],PCA_target[pcj],pch="*",gp=gpar(cex=2,col="red"))
  }
}
dev.off ( which=dev.cur() )

# ISOLATION WITH MIGRATION
#--------------------------

# estimate posterior probability distribution of parameter values
abcresultI <- abc(target  = target_sumstats[sumstats_names],
                  param   = ref_tableI[,c(2:6,9:10)],
                  sumstat = ref_tableI[,sumstats_names],
                  tol     = tolerance,
                  method  = "loclinear",
                  transf  = "log")
summary(abcresultI)


# calculate principal components for summary statistics from simulations
PCA_stats  <- princomp(ref_tableI[no_NA,sumstats_names])
# predict location of real data in PC space
PCA_target <- predict(PCA_stats, target_sumstats[sumstats_names])
# represent graphically PCA to verify that simulations are producing 
# simulations similar to real data
pdf(file="Sylvia_PCA_I.pdf", width=11.7, height=8.3)
for (pci in 1:7){
  for (pcj in (pci+1):8){
    hbin<-hexbin(PCA_stats$scores[,pci], PCA_stats$scores[,pcj],xbins=100,xlab=paste("PC",pci),ylab=paste("PC",pcj))
    pp<-plot(hbin,legend=FALSE, main="PCA on summary statistics")
    pushHexport(pp$plot.vp)
    grid.points(PCA_target[pci],PCA_target[pcj],pch="*",gp=gpar(cex=2,col="red"))
  }
}
dev.off ( which=dev.cur() )

