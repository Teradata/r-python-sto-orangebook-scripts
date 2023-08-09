################################################################################
# The contents of this file are Teradata Public Content
# and have been released to the Public Domain.
# Licensed under BSD; see "license.txt" file for more information.
# Copyright (c) 2023 by Teradata
################################################################################
#
# R And Python Analytics with SCRIPT Table Operator
# Orange Book supplementary material
# Alexander Kolovos - July 2023 - v.2.5
#
# Example 3: Multiple Models Fitting and Scoring: Fitting module (R version)
# File     : ex3rFit.r
#
# Use case:
# Using simulated data for a retail store:
# Model fitting step ("ex3rFit.r"): Fit a model to each one of specified
#   product IDs, each featuring 5 dependent variables x1,...,x5. Return the
#   model information back to Vantage, and store it in a table.
# Model scoring step ("ex3rSco.r"): Score a set of records for each one
#   of the product IDs.
# The R scripts perform each step for one individual product ID whose
# data reside on the corresponding AMP. Scaling is achieved by
# - (on the SQL side) partitioning the input data for each product ID onto
#   individual AMPs.
# - (on the Pyhton script side) executing the same script across all AMPS,
#   thus operating simultaneously on mutiple product IDs.
#
# Script accounts for the general scenario that an AMP might have no data.
#
# Requires the caTools add-on package.
#
# Required input:
# - ex3tblFit table data from file "ex3dataFit.csv" for fitting step.
#
# Output:
# - p_id        : Product ID
# - modelSerB64 : Python model information in a serialized + encoded format
#
################################################################################

# Load dependency package
# We use the suppressPackageStartupMessages() function to prevent unwanted
# output that may interfere with the output expected by the database.
suppressPackageStartupMessages(library(caTools))

DELIMITER <- '\t'
stdin <- file(description="stdin", open="r")

inputDF <- data.frame();

# Know your data: You must know in advance the number and data types of the
# incoming columns from the Teradata database! Use this information in following:
cv <- c("numeric","numeric","numeric","numeric","numeric","numeric","numeric")
inputDF <- try(read.table(stdin, sep=DELIMITER, flush=TRUE, header=FALSE,
                          quote="", na.strings="", colClasses=cv), silent=TRUE)

close(stdin)

# For AMPs that receive no data, exit the script instance gracefully
if (nrow(inputDF) == 0 || class(inputDF) == "try-error") {
    inputDF <- NULL
    quit()
}

nObs <- nrow(inputDF)

p_id <- inputDF[,1];
x1   <- inputDF[,2];
x2   <- inputDF[,3];
x3   <- inputDF[,4];
x4   <- inputDF[,5];
x5   <- inputDF[,6];
y    <- inputDF[,7];

dataDF <- data.frame(x1, x2, x3, x4, x5);
colnames(dataDF) <- c("x1", "x2", "x3", "x4", "x5")

# Fit a model to the given data
# We use the suppressWarnings() function to prevent unwanted
# output that may interfere with the output expected by the database.
myModel <- suppressWarnings( glm(y ~ x1 + x2 + x3 + x4 + x5,
                                 data = dataDF, family = "binomial") )
# names(myModel) provides the list of possible arguments to extract

# Serialize the model and then encode the model to base64 from serialized
# raw. Plain serialization creates newline characters ("\n"), and when
# passed to Teradata they create multiples rows instead of a single-line CLOB.
modelSer <- serialize(myModel, NULL, TRUE)
# Use the "caTools" library to encode the model to base64 from serialized raw.
# Alternatively, rawToChar() function could be used to encode the model to a
# string. Alas, rawToChar() creates newline characters ("\n"), and when
# passed to Teradata they create multiples lines instead of a single CLOB.
modelSerB64 <- base64encode(modelSer)

# Export results to the SQL Engine database through standard output
cat(p_id[1], "\t", modelSerB64, "\n")
