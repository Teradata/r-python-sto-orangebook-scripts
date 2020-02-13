################################################################################
# The contents of this file are Teradata Public Content
# and have been released to the Public Domain.
# Licensed under BSD; see "license.txt" file for more information.
# Copyright (c) 2020 by Teradata
################################################################################
#
# R And Python Analytics with SCRIPT Table Operator
# Orange Book supplementary material
# Alexander Kolovos - January 2020 - v.2.0
#
# Example 1: Scoring (R version)
# File     : ex1rFit.r
#
# Note: Present script is meant to be run on a client machine
#
# Fit a Ranfom Forests model to a given dataset. Export model information
# to an R model object to score data in a target SQL Engine database.
# Use case:
# Predict the propensity of a financial services customer base
# to open a credit card account.
#
# The present file creates the R model object for prediction, and saves it
# into "ex1rMod.rds". This task is assumed to take place on a client machine
# where the present script and the data file with the fitting data reside.
# Execute this script in advance of using the scoring script "ex1rSco.r"
# in the database.
# 
# Requires the randomForest add-on package.
#
# Required input:
# - model fitting data from the file "ex1dataFit.csv"
#
# Output:
# - R model file "ex1rMod.rds". To be imported in the database together
#   with the scoring R script.
#
################################################################################

# Load dependency package
library(randomForest)

# Import the fitting data from CSV file
cv <- c("numeric", "numeric", "numeric", "numeric", "numeric", "numeric",
        "numeric", "numeric", "numeric", "numeric", "numeric", "numeric",
        "numeric", "numeric", "numeric", "numeric", "numeric", "numeric",
        "numeric", "numeric", "numeric", "numeric", "numeric", "numeric",
        "numeric", "numeric", "numeric", "numeric")
trainDataDF <- try( read.table("ex1dataFit.csv", sep=",", flush=TRUE, 
                    header=TRUE, quote="", na.strings="", colClasses=cv) )

# Change the class of the dependent variable to a factor to indicate to
# randomForest that we want to built a classification tree.
trainDataDF$cc_acct_ind = as.factor(trainDataDF$cc_acct_ind)

# For the classifier, specify the following parameters:
# ntree=10, mtry=3, and nodesize=1
RFmodel <- randomForest(formula = (cc_acct_ind ~
                                   tot_income + tot_age + tot_cust_years +
                                   tot_children + female_ind + single_ind +
                                   married_ind + separated_ind +
                                   ca_resident_ind + ny_resident_ind +
                                   tx_resident_ind + il_resident_ind +
                                   az_resident_ind + oh_resident_ind +
                                   ck_acct_ind + sv_acct_ind + ck_avg_bal +
                                   sv_avg_bal + ck_avg_tran_amt +
                                   sv_avg_tran_amt + q1_trans_cnt +
                                   q2_trans_cnt + q3_trans_cnt + q4_trans_cnt),
                         data = trainDataDF,
                         ntree = 10,
                         nodesize = 1,
                         mtry = 3)

RFmodel

# Export the Random Forest model into a file
saveRDS(RFmodel, "ex1rMod.rds")
