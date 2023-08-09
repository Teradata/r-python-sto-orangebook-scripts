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
# Example 2: Clustering
# File     : ex2dataGen.py
#
# Note: Present script is meant to be run on a client machine
#
# Helper module to produce synthetic data set for Example 2.
# Produces the file "ex2data.csv".
#
# Changelog:
#   v.2.5: Replaced deprecated random.random_integers() function
#          with random.default_rng.integers()
#
################################################################################

import numpy as np
nObs = 10000                                 # Number of observations in entire set
nGrp = 10                                    # Number of data groups (partitions)
# Create an numpy Generator instance. Use a seed for repeatability
rng = np.random.default_rng(seed=63955)
obsNums = np.arange(1,nObs+1,1)                # Get obs IDs
obsGrou = np.sort(rng.integers(1,nGrp+1,nObs)) # Generate grpID
xCoords = np.random.random_sample(nObs)        # Generate x coordinates
yCoords = np.random.random_sample(nObs)        # Generate y coordinates
outNums = np.vstack((obsNums,xCoords,yCoords,obsGrou)).T
np.savetxt("ex2data.csv",outNums,fmt='%d,%f10,%f10,%d')
