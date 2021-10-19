################################################################################
# The contents of this file are Teradata Public Content
# and have been released to the Public Domain.
# Licensed under BSD; see "license.txt" file for more information.
# Copyright (c) 2020 by Teradata
################################################################################
#
# R And Python Analytics with SCRIPT Table Operator
# Orange Book supplementary material
# Alexander Kolovos - August 2021 - v.2.1
#
# Example 2: Clustering
# File     : ex2dataGen.py
#
# Note: Present script is meant to be run on a client machine
#
# Helper module to produce synthetic data set for Example 2.
# Produces the file "ex2data.csv".
#
################################################################################

import numpy
nObs = 10000                       # Number of observations in entire set
nGrp = 10                          # Number of data groups (partitions)
numpy.random.seed(63955)           # Optionally specify a seed for repeatability
obsNums = numpy.arange(1,nObs+1,1)                              # Get obs IDs
obsGrou = numpy.sort(numpy.random.random_integers(1,nGrp,nObs)) # Generate grpID
xCoords = numpy.random.random_sample(nObs)    # Generate x coordinates
yCoords = numpy.random.random_sample(nObs)    # Generate y coordinates
outNums = numpy.vstack((obsNums,xCoords,yCoords,obsGrou)).T
numpy.savetxt("ex2data.csv",outNums,fmt='%d,%f10,%f10,%d')
