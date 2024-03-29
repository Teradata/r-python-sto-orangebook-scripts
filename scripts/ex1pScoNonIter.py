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
# Example 1: Scoring (Python version)
# File     : ex1pScoNonIter.py
#
# Score input rows from database by using model information from
# an existing Python model object.
# Use case:
# Predict the propensity of a financial services customer base
# to open a credit card account.
#
# Script performs identical task as ex1pSco.py. In present version, data
# are not read in chunks (practice not recommended for In-Database execution).
# Script accounts for the general scenario that an AMP might have no data.
#
# Requires numpy, pandas, scikitlearn, pickle, and base64 add-on packages.
#
# Required input:
# - ex1tblSco table data from file "ex1dataSco.csv"
# - scoring model saved in Python model object "ex1pMod.out"
#
# Output:
# - cust_id    : The customer ID
# - Prob0      : Probability that a customer does not open an account
# - Prob1      : Probability that a customer opens an account
# - cc_acct_ind: [Actual outcome]
#
################################################################################

# Load dependency packages
import sys
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
import pickle
import base64
import warnings

# pickle will issue a caution warning, if model pickling was done with
# different library version than used here. The following disables any warnings
# that might otherwise show in the scriptlog files on the Advanced SQL Engine
# nodes in this case. Yet, do keep an eye for incompatible pickle versions.
warnings.filterwarnings("ignore")

# Read input
DELIMITER = '\t'

# Know your data: You must know in advance the number and data types of the
# incoming columns from the SQL Engine database!
# For this script, the input expected format is:
# 0: p_id, 1-5: indep vars, 6: dep var, 7: nRow, 8: model (if nRow==1), NULL o/w
colNames = ['cust_id', 'tot_income', 'tot_age', 'tot_cust_years',
           'tot_children', 'female_ind',
           'single_ind', 'married_ind', 'separated_ind',
           'ca_resident_ind', 'ny_resident_ind', 'tx_resident_ind',
           'il_resident_ind', 'az_resident_ind', 'oh_resident_ind',
           'ck_acct_ind', 'sv_acct_ind', 'cc_acct_ind',
           'ck_avg_bal', 'sv_avg_bal', 'cc_avg_bal', 'ck_avg_tran_amt',
           'sv_avg_tran_amt', 'cc_avg_tran_amt', 'q1_trans_cnt',
           'q2_trans_cnt', 'q3_trans_cnt', 'q4_trans_cnt']
# Of the above input columns, the following ones are of type float: tot_income,
# ck_avg_bal, sv_avg_bal, cc_avg_bal, ck_avg_tran_amt, sv_avg_tran_amt, and
# cc_avg_tran_amt. The rest are integer variables.
# If any numbers are streamed in scientific format that contains blanks i
# (such as "1 E002" for 100), the following Lambda functions remove blanks
# from the input string so that Python interprets the number correctly.
sciStrToFloat = lambda x: float("".join(x.split()))
sciStrToInt = lambda x: int(float("".join(x.split())))
# Use these Lambda functions in the following converters for each input column.
converters = { 0: sciStrToInt,
               1: sciStrToFloat,
               2: sciStrToInt,
               3: sciStrToInt,
               4: sciStrToInt,
               5: sciStrToInt,
               6: sciStrToInt,
               7: sciStrToInt,
               8: sciStrToInt,
               9: sciStrToInt,
              10: sciStrToInt,
              11: sciStrToInt,
              12: sciStrToInt,
              13: sciStrToInt,
              14: sciStrToInt,
              15: sciStrToInt,
              16: sciStrToInt,
              17: sciStrToInt,
              18: sciStrToFloat,
              19: sciStrToFloat,
              20: sciStrToFloat,
              21: sciStrToFloat,
              22: sciStrToFloat,
              23: sciStrToFloat,
              24: sciStrToInt,
              25: sciStrToInt,
              26: sciStrToInt,
              27: sciStrToInt}

# Load model from input file
fIn = open('myDB/ex1pMod.out', 'rb')   # 'rb' for reading binary file
classifierPklB64 = fIn.read()
fIn.close()

# Decode and unserialize from imported format
classifierPkl = base64.b64decode(classifierPklB64)
classifier = pickle.loads(classifierPkl)

# Score the test table data with the given model
predictor_columns = ["tot_income", "tot_age", "tot_cust_years", "tot_children",
                     "female_ind", "single_ind", "married_ind", "separated_ind",
                     "ck_acct_ind", "sv_acct_ind", "ck_avg_bal", "sv_avg_bal",
                     "ck_avg_tran_amt", "sv_avg_tran_amt", "q1_trans_cnt",
                     "q2_trans_cnt", "q3_trans_cnt", "q4_trans_cnt"]

### Ingest and process the rest of the input data rows
###
dfToScore = pd.read_csv(sys.stdin, sep=DELIMITER, header=None, names=colNames,
                        index_col=False, iterator=False, converters=converters)

# For AMPs that receive no data, exit the script instance gracefully.
if dfToScore.empty:
    sys.exit()

# Specify the rows to be scored by the model and call the predictor.
X_test = dfToScore[predictor_columns]
PredictionProba = classifier.predict_proba(X_test)

#dfToScore = pd.concat([dfToScore, pd.DataFrame(data=PredictionProba,
#                       columns=['Prob0', 'Prob1'])], axis=1)

# Export results to the SQL Engine database through standard output
for i in range(0, dfToScore.shape[0]):
    print(dfToScore.at[i, 'cust_id'], DELIMITER,
          PredictionProba[i, 0], DELIMITER,
          PredictionProba[i, 1], DELIMITER,
          dfToScore.at[i, 'cc_acct_ind'])

#for index, row in dfToScore.iterrows():
#    print(row['cust_id'], DELIMITER, row['Prob0'], DELIMITER,
#          row['Prob1'], DELIMITER, row['cc_acct_ind'])
