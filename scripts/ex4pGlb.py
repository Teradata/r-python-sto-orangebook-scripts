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
# Example 4: System-Wide Parallelism - Global Average module (Python version)
# File     : ex4pGlb.py
#
# Use case:
# A retail company has 5 stores and retains 3 departments in almost every store.
# We have simulated data of the revenue for each individual department, and we
# seek to find the global average revenue value per department per store.
# This is a system-wide task because it requires data from all SQL Engine AMPs.
# The task takes place in 2 steps, namely a "map" and a "reduce" step:
# In the "map" step, the Python AMP Operations module "ex4pLoc.py" computes the
#   average revenue per department whose data are assigned on the local AMP.
# In the "reduce" step, the Python Global Average module "ex4pGlb.py" combines
#   the partial results from all AMPs to reduce them to the final answer.
#
# Script accounts for the general scenario that an AMP might have no data.
#
# Requires pandas, numpy, and statsmodels add-on package.
#
# Required input:
# - output from script "ex4pLoc.py"
#
# Output:
# - compID   : The ID of the example company
# - nStores  : Number of company stores over which averaging takes place
# - avgGlobal: Global average revenue per department per store
#
#o##############################################################################

# Load dependency packages
import pandas as pd
import numpy as np
import sys

DELIMITER = '\t'

# Know your data: You must know in advance the number and data types of the
# incoming columns from the SQL Engine database!
# For this script, the input expected format is:
# 0: ObsID, 1: X coordinate, 2: Y coordinate, 3: ObsGroup
colNames = ['CompanyID', 'DepartmentID', 'Department',
            'AvgRev_Dept', 'N_Stores']
# Of the above input columns, CompanyID and DepartmentID are integers, the
# Department is a string, and the AvgRev_Dept is a float variable. The
# number of stores N_Stores is an integer, but for the tasks that follow
# it is convenient to interpret it as a float variable.
# If any numbers are streamed in scientific format that contains blanks i
# (such as "1 E002" for 100), the following Lambda functions remove blanks
# from the input string so that Python interprets the number correctly.
sciStrToFloat = lambda x: float("".join(x.split()))
sciStrToInt = lambda x: int(float("".join(x.split())))
# Use these Lambda functions in the following converters for each input column.
converters = {0: sciStrToInt,
              1: sciStrToInt,
              3: sciStrToFloat,
              4: sciStrToFloat}

### Ingest the input data
###
dfIn = pd.read_csv(sys.stdin, sep=DELIMITER, header=None, names=colNames,
                   index_col=False, iterator=False, converters=converters)

# For AMPs that receive no data, exit the script instance gracefully.
if dfIn.empty:
    sys.exit()

if dfIn.shape[0] == 1:
    avgGlobal = dfIn.at[0, 'AvgRev_Dept']
else:
    # Total number of stores
    nStores = dfIn['N_Stores'].sum()
    # Weigh each partial average on the basis of nStores
    dfIn['weights'] = dfIn['N_Stores'].div(nStores)
    # Obtain global average
    avgGlobal = dfIn['AvgRev_Dept'].dot(dfIn['weights'])

# Export results to the SQL Engine database through standard output
print(dfIn.at[0, 'CompanyID'], DELIMITER, nStores, DELIMITER, avgGlobal)
