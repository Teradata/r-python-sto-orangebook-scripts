################################################################################
# The contents of this file are Teradata Public Content
# and have been released to the Public Domain.
# Licensed under BSD; see "license.txt" file for more information.
# Copyright (c) 2020 by Teradata
################################################################################
#
# R And Python Analytics with SCRIPT Table Operator
# Orange Book supplementary material
# Alexander Kolovos - February 2020 - v.2.0
#
# Example 3: Multiple Models Fitting and Scoring: Scoring module (Python vers.)
# File     : ex3pSco.py
# 
# Use case:
# Using simulated data for a retail store:
# Model fitting step ("ex3pFit.py"): Fit a model to each one of specified
#   product IDs, each featuring 5 dependent variables x1,...,x5. Return the 
#   model information back to Vantage, and store it in a table.
# Model scoring step ("ex3pSco.py"): Score a set of records for each one
#   of the product IDs.
# The Python scripts perform each step for one individual product ID whose
# data reside on the corresponding AMP. Scaling is achieved by
# - (on the SQL side) partitioning the input data for each product ID onto
#   individual AMPs.
# - (on the Python script side) executing the same script across all AMPS,
#   thus operating simultaneously on mutiple product IDs.
#
# Script accounts for the general scenario that an AMP might have no data.
# 
# Requires numpy, pandas, statsmodels, pickle, and base64 add-on packages.
#
# Required input:
# - ex3tblSco table data from file "ex3dataSco.csv" for scoring step.
# 
# Output:
# - p_id     : Product ID
# - predicted: Score value for input row
# - x1       : Model parameter x1
# - x2       : Model parameter x2
# - x3       : Model parameter x3
# - x4       : Model parameter x4
# - x5       : Model parameter x5
#
################################################################################

# Load dependency packages
import pandas as pd
import statsmodels.api as sm
import numpy as np
import sys
import pickle
import base64

DELIMITER = '\t'

rowToScore = []

# Know your data: You must know in advance the number and data types of the 
# incoming columns from the SQL Engine database! 
# For this script, the input expected format is:
# 0: p_id, 1-5: indep vars, 6: dep var, 7: nRow, 8: model (if nRow==1), NULL o/w
colNames = ['p_id', 'x1', 'x2', 'x3', 'x4', 'x5', 'y']
# Of the above input columns, the first is of integer type; the rest are floats.
# If any numbers are streamed in scientific format that contains blanks i
# (such as "1 E002" for 100), the following Lambda functions remove blanks 
# from the input string so that Python interprets the number correctly.
sciStrToFloat = lambda x: float("".join(x.split()))
sciStrToInt = lambda x: int(float("".join(x.split())))
# Use these Lambda functions in the following converters for each input column.
converters = {1: sciStrToFloat,
              2: sciStrToFloat,
              3: sciStrToFloat,
              4: sciStrToFloat,
              5: sciStrToFloat}
# Specify which columns to use from the data read by the script.
usecols = [1, 2, 3, 4, 5]

# Start by reading just the first streamed row of data. It is expected to be
# longer than the others by 2 columns. The serialized model information is
# the last input argument. Get this single row with input().
try:
    line = input()
    # If the first row of data is blank, the AMP has no data. Exit gracefully.
    if line == '':   
        sys.exit()
    else:
        allArgs = line.split(DELIMITER)
        allNum = [float(x.replace(" ","")) for x in allArgs[0:7]]
        rowToScore = allNum[1:6]
        modelInSer64 = allArgs[8]
        p_id = allArgs[0]
except (EOFError):   # Exit gracefully if no input received at all
    sys.exit()

# The input model is expected to be a string in encoded, serialized raw format.
# Follow the inverse process to obtain the model. First, decode the CLOB from
# base64 into serialized raw. Then, unserialize.
modelInSer64 = modelInSer64.partition("'")[2]
modelIn = base64.b64decode(modelInSer64)
glmModel = pickle.loads(modelIn)

### Ingest and process the rest of the input data rows
###
dfToScore = pd.read_csv(sys.stdin, sep=DELIMITER, header=None, names=colNames,
                        index_col=False, iterator=False,
                        converters=converters, usecols=usecols)

# Add to the top the extra row that was read first
dfToScore.loc[-1] = rowToScore
dfToScore.index = dfToScore.index+1
dfToScore = dfToScore.sort_index()

# Add intercept or the object cannot be used for prediction
dfToScore.insert(0,'Intercept',1.0)

predicted = glmModel.predict(dfToScore)

# Export results to to the Databse through standard output
for i in range( 0, len(predicted) ):
    print(p_id, DELIMITER, float(predicted[i]), DELIMITER, \
          dfToScore.iat[i,1], DELIMITER, dfToScore.iat[i,2], DELIMITER, \
          dfToScore.iat[i,3], DELIMITER, dfToScore.iat[i,4], DELIMITER, \
          dfToScore.iat[i,5])
