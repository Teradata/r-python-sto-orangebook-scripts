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
# Example 3: Multiple Models Fitting and Scoring: Fitting module (Python vers.)
# File     : ex3pFit.py
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
# - (on the Pyhton script side) executing the same script across all AMPS,
#   thus operating simultaneously on mutiple product IDs.
#
# Script accounts for the general scenario that an AMP might have no data.
# 
# Requires numpy, pandas, statsmodels, pickle, and base64 add-on packages.
#
# Required input:
# - ex3tblFit table data from file "ex3dataFit.csv" for fitting step.
# 
# Output:
# - p_id        : Product ID
# - modelSerB64 : Python model information in a pickled + serialized format
#
################################################################################

# Load dependency packages
import pandas as pd
import statsmodels.api as sm
import numpy as np
import sys
import pickle
import base64

if len(sys.argv) < 2:
    modelSaveName = 'ex3savedModel'
else:
    modelSaveName = str(sys.argv[1])

DELIMITER='\t'

# Know your data: You must know in advance the number and data types of the 
# incoming columns from the SQL Engine database! 
# For this script, the input expected format is:
# 0: p_id, 1-5: indep vars, 6: dep var, 7: nRow, 8: model (if nRow==1), NULL o/w
colNames = ['p_id','x1','x2','x3','x4','x5','y']

# All input columns are float numbers.
# If any numbers are streamed in scientific format that contains blanks i
# (such as "1 E002" for 100), the following Lambda function removes blanks 
# from the input string so that Python interprets the number correctly.
sciStrToFloat = lambda x: float("".join(x.split()))
# Use the Lambda function in the following converters for each input column.
converters = {0: sciStrToFloat,
              1: sciStrToFloat,
              2: sciStrToFloat,
              3: sciStrToFloat,
              4: sciStrToFloat,
              5: sciStrToFloat,
              6: sciStrToFloat}

### Ingest and process the rest of the input data rows
###
df = pd.read_csv(sys.stdin, sep=DELIMITER, header=None, names=colNames,
                 index_col=False, iterator=False, converters=converters)

# For AMPs that receive no data, exit the script instance gracefully.
if df.empty:
    sys.exit()

# Create object with intercept and independent variables. The intercept column
# must be present to use the object in the StatsModels GLM() in the following. 
dfx = df.loc[:,'x1':'x5']
dfx.insert(0,'Intercept',1.0)
# Create object with dependent variable
dfy = df.loc[:,'y']
# Use GLM in statsmodels for binomial general linear modeling.
logit = sm.GLM(dfy, dfx, family = sm.families.Binomial()) 

# Fit the model. Use disp=0 in the parenthesis to prevent sterr output.
fitResult = logit.fit(disp=0)

# Serialize the model and then encode the model to base64 from serialized
# raw. Plain serialization creates newline characters ("\n"), and when
# passed to Teradata they create multiples rows instead of a single-line CLOB.
modelSer = pickle.dumps(fitResult)
modelSerB64 = base64.b64encode(modelSer)

# Export results to the SQL Engine database through standard output
print(df.loc[0]['p_id'], DELIMITER, modelSerB64)
