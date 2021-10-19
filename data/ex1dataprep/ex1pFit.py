################################################################################
# The contents of this file are Teradata Public Content
# and have been released to the Public Domain.
# Licensed under BSD; see "license.txt" file for more information.
# Copyright (c) 2021 by Teradata
################################################################################
#
# R And Python Analytics with SCRIPT Table Operator
# Orange Book supplementary material
# Alexander Kolovos - August 2021 - v.2.1
#
# Example 1: Scoring (Python version)
# File     : ex1pFit.py
#
# Note: Present script is meant to be run on a client machine
#
# Fit a Ranfom Forests model to a given dataset. Export model information
# to a Python model object to score data in a target SQL Engine database.
# Use case:
# Predict the propensity of a financial services customer base
# to open a credit card account.
#
# The present file creates the Python model object for prediction, and saves it
# into "ex1pMod.out". This task is assumed to take place on a client machine
# where the present script and the data file with the fitting data reside.
# Execute this script in advance of using the scoring script "ex1pSco.py"
# in the database.
#
# Requires sklearn, pandas, numpy, pickle, and base64 add-on packages.
#
# Required input:
# - model fitting data from the file "ex1dataFit.csv"
#
# Output:
# - Python model file "ex1pMod.out". To be imported in the database together
#   with the scoring Python script.
#
################################################################################

# Load dependency packages
from sklearn.ensemble import RandomForestClassifier
import pandas as pd
import numpy as np
import pickle
import base64

# Import the fitting data from CSV file
trainDataDF = pd.read_csv("ex1dataFit.csv", sep=",", index_col=None)
trainDataDF.head()

# Create a classification model training with Random Forests.
# Determine the columns that the predictor accounts for:
predictor_columns = ["tot_income", "tot_age", "tot_cust_years", "tot_children",
                     "female_ind", "single_ind", "married_ind", "separated_ind",
                     "ck_acct_ind", "sv_acct_ind", "ck_avg_bal", "sv_avg_bal",
                     "ck_avg_tran_amt", "sv_avg_tran_amt", "q1_trans_cnt",
                     "q2_trans_cnt", "q3_trans_cnt", "q4_trans_cnt"]

# Note: The Random Forests classifier from the scikit-learn package that you
#       use in the present file must be compatible with the corresponding
#       classifier version in the scikit-learn package that is installed in the
#       database. Python will issue a warning if the classifier versions differ,
#       although different versions may well be compatibe.
#       In case errors may be produced due to different scikit-learn versions
#       on the client and in-nodes, you can try switching your client's
#       scikit-learn version to match in-nodes. You can check the version
#       installed on your client with "pip install scikit-learn==<version>".

# For the classifier, specify the following parameters:
# ntree: n_estimators=10, mtry: max_features=3,
# nodesize: min_samples_leaf=1 (default; skipped)
classifier = RandomForestClassifier(n_estimators=10, max_features=3, random_state=0)
X = trainDataDF[predictor_columns]
y = trainDataDF["cc_acct_ind"]

# Train the Random Forest model to predict Credit Card account ownership based
# upon the specified independent variables.
classifier = classifier.fit(X, y)

# Export the Random Forest model into file
# Note: In the following, we use both pickle (serialize) and base64 (encode)
#       on the model prior to saving it into a file. If model is only pickled,
#       then unplickling in database might produce a pickle AttributeError
#       that claims an "X object has no attribute Y". This is related to
#       namespaces in client and target systems. For some more insight, see:
#       https://docs.python.org/3/library/pickle.html#pickling-class-instances
classifierPkl = pickle.dumps(classifier)
classifierPklB64 = base64.b64encode(classifierPkl)
with open('ex1pMod.out', 'wb') as fOut:   # Using "wb" to write in binary format
    fOut.write(classifierPklB64)
