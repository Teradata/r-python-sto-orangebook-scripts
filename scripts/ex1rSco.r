################################################################################
# The contents of this file are Teradata Public Content
# and have been released to the Public Domain.
# Licensed under BSD; see "license.txt" file for more information.
# Copyright (c) 2020 by Teradata
################################################################################
#
# R And Python Analytics with SCRIPT Table Operator
# Orange Book supplementary material
# Alexander Kolovos - February 2020 - v.2.0
#
# Example 1: Scoring (R version)
# File     : ex1rSco.r
#
# Score input rows from database by using model information from
# an existing R model object.
# Use case: 
# Predict the propensity of a financial services customer base
# to open a credit card account.
#
# Script accounts for the general scenario that an AMP might have no data.
#
# Requires the randomForest add-on package.
#
# Required input:
# - ex1tblSco table data from file "ex1dataSco.csv"
# - scoring model saved in R model object "ex1rMod.rds"
#
# Output:
# - cust_id    : The customer ID 
# - Prob0      : Probability that a customer does not open an account
# - Prob1      : Probability that a customer opens an account
# - cc_acct_ind: [Actual outcome]
#
################################################################################

# Load dependency package
# We use the suppressPackageStartupMessages() function to prevent unwanted
# output that may interfere with the output expected by the database.
suppressPackageStartupMessages(library(randomForest))

DELIMITER ='\t'
stdin <- file(description="stdin",open="r")

inputDF <- data.frame();

# A list with the column names of the input data
cn <- c("cust_id", "tot_income", "tot_age", "tot_cust_years", "tot_children",
        "female_ind", "single_ind", "married_ind", "separated_ind",
        "ca_resident_ind", "ny_resident_ind", "tx_resident_ind",
        "il_resident_ind", "az_resident_ind", "oh_resident_ind", "ck_acct_ind",
        "cc_acct_ind", "sv_acct_ind", "ck_avg_bal", "sv_avg_bal", "cc_avg_bal",
        "ck_avg_tran_amt", "sv_avg_tran_amt", "cc_avg_tran_amt", "q1_trans_cnt",
        "q2_trans_cnt", "q3_trans_cnt", "q4_trans_cnt")

# Know your data: You must know in advance the number and data types of the 
# incoming columns from the SQL Engine database!
ct <- c("integer", "double", "integer", "integer", "integer", "integer",
        "integer", "integer", "integer", "integer", "integer", "integer",
        "integer", "integer", "integer", "integer", "factor", "integer",
        "double", "double", "double", "double", "double", "double", "integer",
        "integer", "integer", "integer")

# Read the scoring model information
ScoringModel <- readRDS("./myDB/ex1rMod.rds")

### Ingest and process the input data rows
###
inputDF <- try(read.table(stdin, sep=DELIMITER, flush=TRUE, header=FALSE, 
                          quote="", na.strings="", colClasses=ct, col.names=cn),
               silent=TRUE)
close(stdin)

# If AMP has no data, stream ended, or issue occured, quit gracefully.
if (nrow(inputDF) == 0 || class(inputDF) == "try-error") {
  inputDF <- NULL
  quit()
}

Predicted <- suppressWarnings( predict(ScoringModel, newdata=inputDF, 
                                       type="vote") );

# Build export data frame:
Scores <- data.frame(inputDF$cust_id, Predicted, inputDF$cc_acct_ind)

# Export results to the SQL Engine database through standard output
write.table(Scores, file=stdout(), col.names=FALSE, row.names=FALSE,
            quote=FALSE, sep=DELIMITER, na="")
