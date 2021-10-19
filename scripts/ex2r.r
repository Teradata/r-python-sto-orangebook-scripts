################################################################################
# The contents of this file are Teradata Public Content
# and have been released to the Public Domain.
# Licensed under BSD; see "license.txt" file for more information.
# Copyright (c) 2021 by Teradata
################################################################################
#
# R And Python Analytics with SCRIPT Table Operator
# Orange Book supplementary material
# Alexander Kolovos - October 2021 - v.2.1
#
# Example 2: Clustering - (R version)
# File     : ex2r.r
#
# Use case:
# Based on Pycluster Workshop example in "Data Analysis with Open Source Tools"
# by Philipp K. Janert. Copyright 2011 Philipp K. Janert, 978-0-596-80235-6
# Identify a user-specified number of clusters in given data set of points at
# given locations. Classify each observation of the data set into a cluster,
# on the basis of the observation coordinates.
#
# Script accounts for the general scenario that an AMP might have no data.
#
# Requires cluster package.
#
# Required Input:
# - ex2tbl table data from file "ex2data.csv". Contains the variables:
#   ObsID     : The unique ID of each observation
#   X_Coord   : The x coordinate of the observation
#   Y_Coord   : The y coordinate of the observation
#   ObsGroup  : Integer that identifies which group the obs belongs to
#
# Input Parameter:
# n         : The number of clusters we want to create (default: n=5)
#
# Output:
# - X_Centroid: The cluster centroid x coordinate
# - Y_Centroid: The cluster centroid y coordinate
# - isil      : Silhouette coef for each obs (in [-1,1]). Clustering good if =0
# - silhCoef  : Average silhouette coefficient for data set
#
# Note: In the presence of multiple groups of data in the same data set,
#       meaningful cluster analysis on Teradata with the present script can be
#       performed only by operating on same-group observations.
#       For efficient analysis, ensure that each instance of the present script
#       operates on a single data partition.
#
################################################################################

# Load dependency package
# We use the suppressPackageStartupMessages() function to prevent unwanted
# output that may interfere with the output expected by the database.
suppressPackageStartupMessages(library(cluster))
args = commandArgs(trailingOnly=TRUE)

# The present script expects the number of clusters as an input argument.
# If no argument is specified, then use a default number of 5 clusters.
if (length(args) == 0) {
  n = 5
} else if (length(args) >= 1) {
  n = args[1]
}

DELIMITER <- '\t'
stdin <- file(description="stdin",open="r")

inputDF <- data.frame();

# Need to know the type of input columns. Cite them in following vector to feed
# the colClasses argument of the read.table() function.
cv <- c("numeric","numeric","numeric","numeric")
inputDF <- try(read.table(stdin, sep=DELIMITER, flush=TRUE, header=FALSE,
                          quote="", na.strings="", colClasses=cv), silent=TRUE)

close(stdin)

# For AMPs that receive no data, choose to simply quit the script immediately.
if (class(inputDF) == "try-error") {
  inputDF <- NULL
  quit()
}

nObs <- nrow(inputDF)
obsID <- inputDF[,1]
XY_Coords <- inputDF[,2:3]
obsGroup <- inputDF[,4]

# Perform clustering and find centroids
#     predClus is the predicted cluster each observation is assigned to
#     centers are the centroid coordinates for each of the n clusters
kmeansObj <- kmeans(XY_Coords, n, iter.max = 50)
predClus <- kmeansObj$cluster
centers <- kmeansObj$centers
obsCenterX <- numeric(nObs)
obsCenterY <- numeric(nObs)
for (i in 1:nObs) {
  obsCenterX[i] <- centers[predClus[i], 1]
  obsCenterY[i] <- centers[predClus[i], 2]
}

# Assess the clustering quality
#    silhCoeff is the silhouette coefficient for each observation
#    silhScore is the average score for all observations
silhCoeff <- silhouette(predClus, dist(XY_Coords))
silhScore <- mean(silhCoeff[, 3])

# Print output: Current obsID, cluster it belongs to, coordinates of its cluster
# center, silhouette coefficient. Build export data frame:
output <- data.frame(obsID, obsGroup, predClus, obsCenterX, obsCenterY,
                     list(rep(n, nObs)), silhCoeff[, 3],
                     list(rep(silhScore, nObs)))

# Export results to the SQL Engine database through standard output
write.table(output, file=stdout(), col.names=FALSE, row.names=FALSE,
            quote=FALSE, sep=DELIMITER, na="")
