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
# Example 5: Linear Regression with the CALCMATRIX table operator (R version)
# File     : ex5r.r
#
# (Adapted from the Teradata Developer Exchange online example by Mike Watzke:
#  http://developer.teradata.com/extensibility/articles/
#  in-database-linear-regression-using-the-calcmatrix-table-operator)
#
# Use case:
# A simple example of linear regression with one dependent and two independent
# variables (univariate, multiple variable regression). For the regression
# computations, we need to calculate the sums of squares and cross-products
# matrix of the data. The example illustrates how to use the CALCMATRIX table
# operator for this task. The script returns the estimates of the regression
# coefficients.
#
# Script accounts for the general scenario that an AMP might have no data.
#
# Required input:
# - ex5tbl table data from file "ex5dataTblDef.sql"
#
# Output:
# - varName: Regression coefficient name
# - B      : Regression coefficient estimated value
#
################################################################################

DELIMITER='\t'

stdin <- file(description="stdin",open="r")

inputDF <- data.frame();

# Need to know in advance the type of all input columns. Cite them in following
# vector to feed the colClasses argument of the read.table() function.
cv <- c("numeric","character","numeric","numeric","numeric","numeric","numeric")
inputDF <- try(read.table(stdin, sep=DELIMITER, flush=TRUE, header=FALSE,
                      quote="", na.strings="", colClasses=cv, strip.white=TRUE),
               silent=TRUE)

close(stdin)

# For AMPs that receive no data, choose to simply quit the script immediately.
if (nrow(inputDF) == 0 || class(inputDF) == "try-error") {
    inputDF <- NULL
    quit()
}

nObs <- nrow(inputDF)
colnames(inputDF) <- c('rownum', 'rowname', 'c', 's', 'x1', 'x2', 'y')

# Determine the position of the independent variable columns
xcols <- which(!names(inputDF) %in% c('rownum','rowname','c','y'))
# Extract partial X'X
pXX <- inputDF[ inputDF[['rowname']] != 'y' , c(xcols)]
# Extract observation count
obscount <- inputDF[ inputDF[['rowname']] == 'y' , c('c')]
# Extract X variable summations
Xsum <- inputDF[ inputDF[['rowname']] != 'y' , c('s')]
# Build first row of matrix X'X
XX <- data.matrix(obscount)
XX <- cbind(XX, t(data.matrix(Xsum)))
# Append partial X'X
XX <- rbind(XX, data.matrix(pXX))
# Invert X'X
iXX <-solve(XX)

# Extract Y variable summations
Ysum <- inputDF[ inputDF[['rowname']] == 'y' , c('s')]
# Extract partial X'Y
XY <- inputDF[ inputDF[['rowname']] != 'y' , 'y']
# Build X'Y of matrix
XY <- rbind(data.matrix(Ysum), data.matrix(XY))
# Multiply inverted X'X * X'Y to obtain coefficients
B <- iXX %*% XY

# Gather names of variables
varName <- inputDF[ inputDF[['rowname']] != 'y' , c('rowname')]
varName <- c("Intercept", varName)

# Build export data frame:
output <- data.frame(varName, B)

# Export results to the SQL Engine database through standard output
write.table(output, file=stdout(), col.names=FALSE, row.names=FALSE,
            quote=FALSE, sep="\t", na="")
