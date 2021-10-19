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
# Example 5: Linear Regression with the CALCMATRIX table operator (Python vers.)
# File     : ex5p.py
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
# Requires the numpy and pandas add-on packages.
#
# Required input:
# - ex5tbl table data from file "ex5dataTblDef.sql"
#
# Output:
# - varName: Regression coefficient name
# - B      : Regression coefficient estimated value
#
################################################################################

# Load dependency packages
import pandas as pd
import numpy as np
import sys

DELIMITER='\t'

# The input comes from CALCMATRIX. When in the COMBINE phase with 'COLUMNS'
# output and CALCTYPE set to 'ESSCP' (extended sums of squares and
# cross-product), then output includes following columns:
# INTEGER rownum, VARCHAR(128) rowname, BIGINT c (for count), FLOAT column s
# (for summation), and a FLOAT column for each data column of input.
tbldata = []
colNames = []
while 1:
    try:
        line = input()
        if line == '':   # Exit if user provides blank line
            break
        else:
            allnum = line.split(DELIMITER)
            colNames.append(allnum[1].strip())
            allnum = [float(x.replace(" ","")) for x in allnum[2:]]
            tbldata.append(allnum)
    except (EOFError):   # Exit if reached EOF or CTRL-D
        break

nRec = len(tbldata)

# If the present AMP has no data, then exit this script instance.
if nRec==0:    # not tbldata.size:
    sys.exit()

del allnum

colNames.insert(0,'s')               # Account for sum in current column 2
colNames.insert(0,'c')               # Account for count in current column 1

xCols = colNames[1:len(colNames)-1]  # Include sum and all independ var columns

df = pd.DataFrame(tbldata, columns=colNames)
df.insert(0,'rowname',colNames[2:])  # Prepend the column with row names

# Extract partial X'X
pXX = np.asarray( df.loc[ df['rowname']!='y', xCols ] )
# Extract observation count
obscount = np.asarray( df.loc[ df['rowname']=='y' , 'c'].iat[0] )
# Extract X variable summations
Xsum = np.asarray( df.loc[ df['rowname']!='y', 's' ] )
# Build first row of matrix X'X
XX = np.hstack((obscount, Xsum))
# Append partial X'X
XX = np.vstack((XX, pXX))
# Invert X'X
iXX = np.linalg.inv(XX)

# Extract Y variable summations
Ysum = np.asarray( df.loc[ df['rowname']=='y' , 's'].iat[0] )
# Extract partial X'Y
XY = np.asmatrix( df.loc[ df['rowname']!='y' , 'y'] ).T
XY = np.asarray(XY)
# Build X'Y of matrix
XY = np.vstack((Ysum, XY))
# Multiply inverted X'X * X'Y to obtain coefficients
B = np.dot(iXX,XY)

# Gather names of variables
varName = ['Intercept']
varName.extend(xCols[1:])      # Skip column name of sums

# Export results to the SQL Engine database through standard output
for i in range( 0, len(varName) ):
    print(varName[i], DELIMITER, float(B[i]))
