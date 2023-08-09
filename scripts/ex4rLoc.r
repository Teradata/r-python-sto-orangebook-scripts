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
# Example 4: System-Wide Parallelism - AMP Operations module (R version)
# File     : ex4rLoc.r
#
# Use case:
# A retail company has 5 stores and retains 3 departments in almost every store.
# We have simulated data of the revenue for each individual department, and we
# seek to find the global average revenue value per department per store.
# This is a system-wide task because it requires data from all SQL Engine AMPs.
# The task takes place in 2 steps, namely a "map" and a "reduce" step:
# In the "map" step, the R AMP Operations module "ex4rLoc.r" computes the
#   average revenue per department whose data are assigned on the local AMP.
# In the "reduce" step, the R Global Average module "ex4rGlb.r" combines
#   the partial results from all AMPs to reduce them to the final answer.
#
# Script accounts for the general scenario that an AMP might have no data.
#
# Required input:
# - ex4tbl table data from the file "ex4data.csv"
#
# Output:
# - CompanyID     : The ID of the example company
# - DepartmentID  : The ID of the present department
# - Department    : Name of the preseent department
# - avgDeptRevenue: Average revenue of the present department
# - nObs          : Number of records that determine the average revenue
#
################################################################################

DELIMITER <- '\t'
stdin <- file(description="stdin",open="r")

inputDF <- data.frame();

# Know your data: You must know in advance the number and data types of the
# incoming columns from the SQL Engine database!

cv <- c("numeric", "numeric", "character", "numeric")
inputDF <- try(read.table(stdin, sep=DELIMITER, flush=TRUE, header=FALSE,
                          quote="", na.strings="", colClasses=cv), silent=TRUE)

close(stdin)

# For AMPs that receive no data, choose to simply quit the script immediately.
if (nrow(inputDF) == 0 || class(inputDF) == "try-error") {
    inputDF <- NULL
    quit()
}

nObs <- nrow(inputDF)
avgDeptRevenue <- round(mean(inputDF[,4], na.rm=TRUE), digits=2)
CompanyID <- inputDF[1,1]
DepartmentID <- inputDF[1,2]
Department <- inputDF[1,3]

# Build export data frame:
output <- data.frame(CompanyID, DepartmentID, Department, avgDeptRevenue, nObs)

# Export results to the SQL Engine database through standard output
write.table(output, file=stdout(), col.names=FALSE, row.names=FALSE,
            quote=FALSE, sep=DELIMITER, na="")
