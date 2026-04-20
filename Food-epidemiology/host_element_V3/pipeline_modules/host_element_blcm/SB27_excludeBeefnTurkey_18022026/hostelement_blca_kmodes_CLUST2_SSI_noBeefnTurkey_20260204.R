# analysis for host elements study
# Zhenke Wu | zhenkewu@umich.edu
# November 18th, 2019
# Modified by Daniel Park | danpark@gwu.edu
# Modified by Maliha Aziz | mlaziz@gwu.edu
# Modified by Edward Sung | edward.sung@gwu.edu
# Modified for cgmlst Kmodes clustering

# Notes by Edward Sung | edward.sung@gwu.edu
# The bugs model takes in the entire csv file as training.
# The "training" column is only used to call which ones to create ouputs/predictions for.
# training==1 means no pred output is generated, training==0 pred outputs are generated.
# This means that a baseline training set needs to be included along with all "new datasets"
# For example, this means when running SB27 samples... dcFUTI and bigFUTI: 011723_any_element_presence_input_bigfuti_dcfuti.csv is included along with the SB27 dataset.


# Additional modifications for reproducibility - Edward (March, 31, 2024)
# Added set.seed(123) to the start
# Modified:
# in_init <- function(){
#   list(a=rep(0,M_fit-1), .RNG.name = "base::Wichmann-Hill", .RNG.seed = 123)
# } 

# Reverted back to no setseed. Kept the setseed as a comment, but moving forward we want the varability that comes from repetition with blcm. - Edward (June, 21, 2024)

# Converted for Cluster2 Usage, changed the column names. - Edward (July 10, 2024)

# Edward (August 6, 2024)
# Added Beef Column as a class 

# Edward (August 18, 2025)
# Maliha added some comments to the modeling section

# Edward (October 21, 2025)
# Removed Beef in this version



#suppressPackageStartupMessages(library(optparse,lib="/GWSPH/groups/liu_price_lab/pegasus_bin/LIBS/R/x86_64-pc-linux-gnu-library/4.1"))
#suppressPackageStartupMessages(library(coda,lib="/GWSPH/groups/liu_price_lab/pegasus_bin/LIBS/R/x86_64-pc-linux-gnu-library/4.1"))
#suppressPackageStartupMessages(library(rjags,lib="/GWSPH/groups/liu_price_lab/pegasus_bin/LIBS/R/x86_64-pc-linux-gnu-library/4.1"))
#suppressPackageStartupMessages(library(R2jags,lib="/GWSPH/groups/liu_price_lab/pegasus_bin/LIBS/R/x86_64-pc-linux-gnu-library/4.1"))
suppressPackageStartupMessages(library(optparse))
suppressPackageStartupMessages(library(coda))
suppressPackageStartupMessages(library(rjags))
suppressPackageStartupMessages(library(R2jags))
suppressPackageStartupMessages(library(label.switching))


rm(list=ls())

## command line options
opt_lst <- list(
  make_option(c("-i","--input_file"),
              help = "Input file name"),
  make_option(c("-o","--output_folder"),
              help = "Output folder name")
)
parser <- OptionParser(option_list = opt_lst,
                       description = "HBLCM\n TO run on pegasus: \nmodule load R/gcc/10.2.0/4.1.1;conda activate jags;sbatch -J blcm -t 1-00:00:00 -p short -N 1 --wrap=\"Rscript hostelement_blca.R -i INPUT_FILE.csv -o OUTPUT_FOLDER\"")
arguments <- parse_args(parser,
                        positional_arguments = TRUE)
opts <- arguments$options

dir.create(opts$o, recursive = TRUE, showWarnings = FALSE)


# read in data:

dat <- read.csv(opts$i)
head(dat)

class_label <- rep(NA,nrow(dat))
for (i in 1:nrow(dat)){
    if (dat$training[i] ==1){
        if (!is.na(dat$Human_CL1[i]) && dat$Human_CL1[i] ==1) class_label[i]=1
        if (!is.na(dat$Human_CL2[i]) && dat$Human_CL2[i] ==1) class_label[i]=2
        if (!is.na(dat$Chicken_CL1[i]) && dat$Chicken_CL1[i] ==1) class_label[i]=3
        if (!is.na(dat$Chicken_CL2[i]) && dat$Chicken_CL2[i] ==1) class_label[i]=4
        if (!is.na(dat$Pork[i]) && dat$Pork[i] ==1) class_label[i]=5}
}
# set.seed(123)
ntrain = nrow(dat)
test_id <- which(dat[1:ntrain,]$training==0)

# the "class_label" dataframe determines the test/train. Y is sent in as a whole since we need output probabilities for the test. there is no class_label value for test set
Y <- as.matrix(dat[1:ntrain,-(1:8)])

result_folder <- opts$o

# fit Bayesian model:
mcmc_options <- list(debugstatus= TRUE,
                     n.chains   = 1,
                     n.itermcmc = 10000, #default=10000
                     n.burnin   = 5000, # default=5000
                     n.thin     = 1,
                     result.folder = result_folder,
                     bugsmodel.dir = result_folder
)

# write .bug model file:
model_bugfile_name <- "model.bug"
filename   <- file.path(mcmc_options$bugsmodel.dir, model_bugfile_name)

model_text <- "model{
  # Likelihood
  for (i in 1:N){
    for (k in 1:K){
      Y[i,k] ~ dbern(p[eta[i],k])
    }
    eta[i] ~ dcat(pi[1:M_fit])
  }
  
  # --- Prior for Class Proportions (pi) using Softmax ---
  
  # 1. Calculate exponential of 'a' element-wise 
  for (j in 1:M_fit){
    a[j] ~ dnorm(0, 4/9)
    exp_a[j] <- exp(a[j])
  }
  
  # 2. Sum the exponentials (Scalar sum of the vector)
  sum_exp_a <- sum(exp_a[1:M_fit])
  
  # 3. Calculate pi and define Feature Probabilities
  for (j in 1:M_fit){
    pi[j] <- exp_a[j] / sum_exp_a
    
    # Feature probabilities (Logistic transformation)
    for (k in 1:K){
      p[j,k] <- 1/(1+exp(-g[j,k]))
      g[j,k] ~ dnorm(0, 4/9)
    }
  }
} #END OF MODEL."
writeLines(model_text, filename)

# run jags:
library(rjags)
load.module("glm")

M_fit <- 5 # this equals the number of all possible categories
N <- nrow(Y)
K <- ncol(Y)
eta <- as.numeric(class_label)
eta[test_id] <- NA

# ensuring training labels are valid
Y <- as.matrix(Y)
storage.mode(Y) <- "numeric"

# drop dimnames 
dimnames(Y) <- NULL

# Create a named list for the data
jags_data <- list(Y = Y, 
                  M_fit = M_fit, 
                  N = N, 
                  K = K, 
                  eta = eta)
out_parameter <- c("pi","p","eta")

in_init <- function(){
  # list(a=rep(0,M_fit-1), .RNG.name = "base::Wichmann-Hill", .RNG.seed = 123)
  list(a=rep(0,M_fit))
}

curr_data_txt_file <- file.path(mcmc_options$result.folder,"jagsdata.txt")
if(file.exists(curr_data_txt_file)){file.remove(curr_data_txt_file)}

out <- R2jags::jags(data   = jags_data,
                     inits  = in_init,
                     parameters.to.save = out_parameter,
                     model.file = filename,
                     working.directory = mcmc_options$result.folder,
                     n.iter         = as.integer(mcmc_options$n.itermcmc),
                     n.burnin       = as.integer(mcmc_options$n.burnin),
                     n.thin         = as.integer(mcmc_options$n.thin),
                     n.chains       = as.integer(mcmc_options$n.chains),
                     DIC            = FALSE)


#Obtain the posterior samples from JAGS output:


#put into mem instead of out with text file:
res_mcmc <- as.mcmc(out)
#mcmc_options has n.chains = 1, so grabbing just the first element
res <- res_mcmc[[1]]


#Obtain the chain histories:
print_res <- function(x,coda_res) plot(coda_res[,grep(x,colnames(coda_res))])
get_res   <- function(x,coda_res) coda_res[,grep(x,colnames(coda_res))]


p_samples <- as.matrix(get_res("p", res))

# dimensions: iterations x (M_fit * K)
dim(p_samples)

n_iter <- nrow(p_samples)

p_array <- out$BUGSoutput$sims.list$p
#classes are the second ele in the stephens function, so we change it

# changed from [Iterations, Classes(5), MGEs(17)]
# to [Iterations, MGEs(17), Classes(5)]
p_array <- aperm(p_array, c(1, 3, 2))


#Stephens relabeling
steph <- stephens(p_array)

eta_samples <- out$BUGSoutput$sims.list$eta

eta_relab <- eta_samples

for (i in 1:n_iter) {
  perm <- steph$permutations[i, ]
  eta_relab[i, ] <- perm[eta_samples[i, ]]
}
# 
print_res("eta",res)
# 
# 
# ind_ord <- order(pi_vec) 
# retain_ind <- grep("^p",rownames(out$summary))
# posterior_table <- cbind(c(pi_vec[ind_ord],p_mat[ind_ord,]),round(out$summary[retain_ind,],3))
# colnames(posterior_table)[1] <- "truth"

mat_test <- eta_relab[, test_id]

v1 <- apply(mat_test,2,function(v) mean(v==1))
v2 <- apply(mat_test,2,function(v) mean(v==2))
v3 <- apply(mat_test,2,function(v) mean(v==3))
v4 <- apply(mat_test,2,function(v) mean(v==4))
v5 <- apply(mat_test,2,function(v) mean(v==5))



res_dat <- cbind(v1,v2,v3,v4,v5,dat[test_id,1:10])
colnames(res_dat)[1:5] <- c("pred_Human_CL1","pred_Human_CL2",
                            "pred_Chicken_CL1","pred_Chicken_CL2",
                            "pred_Pork")

filename_pred <- file.path(opts$o, "blcm_output_pred_scores.csv")
write.csv(res_dat, filename_pred, row.names = FALSE)
