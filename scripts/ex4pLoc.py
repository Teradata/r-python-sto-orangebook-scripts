################################################################################
# The contents of this file are Teradata Public Content
# and have been released to the Public Domain.
# Licensed under BSD; see "license.txt" file for more information.
# Copyright (c) 2020 by Teradata
################################################################################
#
# R And Python Analytics with the SCRIPT Table Operator
# Orange Book supplementary material
# Alexander Kolovos - January 2020 - v.2.0
#
# Example 4: System-Wide Parallelism - AMP Operations module (Python version)
# File     : ex4pLoc.py
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
# - ex4tbl table data from the file "ex4data.csv"
# 
# Output:
# - CompanyID   : The ID of the example company
# - DepartmentID: The ID of the present department
# - dptname     : Name of the preseent department
# - deptMeanRev : Average revenue of the present department
# - nRows       : Number of records that determine the average revenue
#
################################################################################

# Load dependency packages
import pandas as pd
import sys

DELIMITER = '\t'

# Know your data: You must know in advance the number and data types of the 
# incoming columns from the SQL Engine database! 
# For this script, the input expected format is:
# 0: ObsID, 1: X coordinate, 2: Y coordinate, 3: ObsGroup
colNames = ['CompanyID', 'DepartmentID', 'Department', 'Revenue']
# Of the above input columns, CompanyID and DepartmentID are integers, the
# Department is a string, and Revenue is a float variable.
# If any numbers are streamed in scientific format that contains blanks i
# (such as "1 E002" for 100), the following Lambda functions remove blanks 
# from the input string so that Python interprets the number correctly.
sciStrToFloat = lambda x: float("".join(x.split()))
sciStrToInt = lambda x: int(float("".join(x.split())))
# Use these Lambda functions in the following converters for each input column.
converters = {0: sciStrToInt,
              1: sciStrToInt,
              3: sciStrToFloat}

### Ingest the input data
###
dfIn = pd.read_csv(sys.stdin, sep=DELIMITER, header=None, names=colNames,
                   index_col=False, iterator=False, converters=converters)

# For AMPs that receive no data, exit the script instance gracefully.
if dfIn.empty:
    sys.exit()

# We need average revenue for present department. Round value to 2 decimals.
nRows = dfIn.shape[0]
# Note: Older Python versions might throw an error if attempting to use
#       dfIn.Revenue.mean().round(2)
#       Circumventing issue by doing explicitly:
deptMeanRev = dfIn.Revenue.mean()
deptMeanRev = round(deptMeanRev, 2)

# Export results to the SQL Engine database through standard output
print(dfIn.at[0, 'CompanyID'], DELIMITER, 
      dfIn.at[0, 'DepartmentID'], DELIMITER,
      dfIn.at[0, 'Department'], DELIMITER,
      deptMeanRev, DELIMITER, nRows)
