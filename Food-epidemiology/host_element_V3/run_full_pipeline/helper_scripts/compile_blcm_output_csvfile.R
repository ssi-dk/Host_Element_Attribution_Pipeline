suppressPackageStartupMessages(library(tidyverse))
suppressPackageStartupMessages(library(optparse))

## command line options
opt_lst <- list(
  make_option(c("-b","--blcm_preds"),
              help = "blcm analysis output (some_name)_pred_scores"),
  make_option(c("-m","--mlst"),
              help ="mlst analysis output"),
  make_option(c("-f","--fimh"),
              help = "fimh analysis output"),
  make_option(c("-e","--elem"),
              help = "element presence"),
  make_option(c("-o","--output"),
              help = "this is the output location of the input")
)

# build the argument parser
parser <- OptionParser(option_list = opt_lst,
                       description = "script to create final output from Bayesian latent class analysis")
# Read command line arguments
arguments <- parse_args(parser,
                        positional_arguments = TRUE)
#store the parsed option values
opts <- arguments$options

#get the args
pred_scores_file <- opts$blcm_preds
mlst_file <- opts$mlst
elements_file <- opts$elem
fimh_file <- opts$fimh
output_dir <- opts$output

#read files
pred_scores <- read_csv(pred_scores_file)
mlst_df <- read_tsv(mlst_file)
elements_df <- read_tsv(elements_file)
fimh_df <- read_tsv(fimh_file)

#remove SB27s (subject to change)
SB27s <- c("SB2710442057","SB277889789","SB277889526","SB2710441567","SB2710196256","SB2713433758","SB2710445196","SB279408555", "SB278791245",
           "SB2710442286", "SB278791765", "SB2710441360", "SB278791760","SB2710442350", "SB277889522","SB2710445222", "SB2710442237", "SB2713434428",
           "SB2710196251", "SB2710445200")
print("removing 20 SB27s from test set:")
print(SB27s)

pred_scores <- pred_scores[!(pred_scores$Sample_Name %in% SB27s),]
#renaming col for streamlining
colnames(fimh_df)[1] <- "Sample_Name"
colnames(elements_df)[1] <- "Sample_Name"

#generating output
blcm_analysis_df <- pred_scores %>%
  transmute(
    Sample_Name,
    kmodes_CL1 = CL1,
    kmodes_CL2 = CL2,
    MLST,
    Human_pred = pred_Human_CL1 + pred_Human_CL2,
    Meat_pred = pred_Chicken_CL1 + pred_Chicken_CL2 + pred_Pork,
    Class_Human = ifelse(Human_pred >= 0.8, 1, 0),
    Class_Animal = ifelse(Meat_pred >= 0.8, 1, 0),
    FZEC = ifelse(Human_CL1 + Human_CL2 + Class_Animal == 2, 1, 0)
  ) %>%
  left_join(fimh_df, by = "Sample_Name") %>%
  left_join(elements_df, by = "Sample_Name") %>%
  select(Sample_Name, kmodes_CL1, kmodes_CL2, MLST, fimHtype,
         Human_pred, Meat_pred, Class_Human, Class_Animal, FZEC,
         EL18, EL19, EL35, EL44, EL45, EL46, #Human attributed elements
         EL37, EL38, EL39, EL40, # Animal attributed elements
         EL2, EL3, EL36, EL41, EL42, EL43, EL50) # Weakly animal attributed elements

print("element attribution fyi:")
print("Human attributed elements: EL18 EL19 EL35 EL44 EL45 EL46")
print("Animal attributed elements: EL37 EL38 EL39 EL40")
print("Weakly animal attributed elements: EL2 EL3 EL36 EL41 EL42 EL43 EL50 ")

write.csv(
  blcm_analysis_df,
  file = file.path(output_dir, "blcm_analysis.csv"),
  row.names = F,
  quote = T
)