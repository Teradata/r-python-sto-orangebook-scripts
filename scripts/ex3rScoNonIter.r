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
# Example 3: Multiple Models Fitting and Scoring: Scoring module (R version)
# File     : ex3rScoNonIter.r
#
# Use case:
# Using simulated data for a retail store:
# Model fitting step ("ex3rFit.r"): Fit a model to each one of specified
#   product IDs, each featuring 5 dependent variables x1,...,x5. Return the
#   model information back to Vantage, and store it in a table.
# Model scoring step ("ex3rSco.r"): Score a set of records for each one
#   of the product IDs.
# The R scripts perform each step for one individual product ID whose
# data reside on the corresponding AMP. Scaling is achieved by
# - (on the SQL side) partitioning the input data for each product ID onto
#   individual AMPs.
# - (on the R script side) executing the same script across all AMPS,
#   thus operating simultaneously on mutiple product IDs.
#
# Script performs identical task as ex3rSco.r. In present version, data
# are not read in chunks (practice not recommended for In-Database execution).
# Script accounts for the general scenario that an AMP might have no data.
#
# Requires the caTools add-on package.
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

# Load dependency package
# We use the suppressPackageStartupMessages() function to prevent unwanted
# output that may interfere with the output expected by the database.
suppressPackageStartupMessages(library(caTools))

DELIMITER <- '\t'
stdin <- file(description="stdin",open="r")

inputDF <- data.frame();

# Know your data: You must know in advance the number and data types of the
# incoming columns from the SQL Engine database!
# For this script, the input expected format is:
# 0: p_id, 1-5: indep vars, 6: dep var, 7: nRow, 8: model (if nRow==1), NULL o/w
cv <- c("numeric","numeric","numeric","numeric","numeric","numeric","numeric",
        "numeric","character")

# Start by reading just the first streamed row of data. It is expected to be
# longer than the others by 2 columns. The serialized model information is
# the last input argument. Get this single row with readLines().
input <- readLines(stdin, n=1, ok=TRUE)
if (length(input) != 0) { # IF input line not empty

    dt1 <- unlist(strsplit(input, split=DELIMITER))
    # If input contains string columns, too, then rbind alone does not work!
    # Splitting a string and putting the components into a data frame produces
    # a single-column data frame. We need each component in a separate column,
    # so we take the transpose of the single column
    dt2 <- as.data.frame(t(dt1), stringsAsFactors=FALSE)
    # The products of strsplit are all of type character. We must know ini
    # advance whether input data contain any numeric variables and explicitly
    # specify them.
    # If any numbers are streamed in scientific format that contains blanks i
    # (such as "1 E002" for 100), then remove blanks from the input string with
    # the gsub() function so that R interprets the number correctly.
    dt3 <- transform(dt2, V1=as.numeric(gsub(" ","",V1)), V2=as.numeric(gsub(" ","",V2)),
                          V3=as.numeric(gsub(" ","",V3)), V4=as.numeric(gsub(" ","",V4)),
                          V5=as.numeric(gsub(" ","",V5)), V6=as.numeric(gsub(" ","",V6)),
                          V7=as.numeric(gsub(" ","",V7)), V8=as.numeric(gsub(" ","",V8)))
    inputDF <- dt3[,1:7];   # Save first row of numeric data to score
    modelInInit <- dt3[1,9];           # Save serialized form of model

    remove('dt1', 'dt2', 'dt3')

} else {

    # For AMPs that receive no data, exit the corresponding script instance.
    inputDF <- NULL
    quit()

} # END IF input line not empty

### Extract the model before we continue data ingesting and scoring
###

# The CLOB string that contains the model might have blanks in the beginning or
# trailing the string. Remove them.
trim <- function (x) gsub("^\\s+|\\s+$", "", x)
modelIn <- trim(modelInInit)

# The input model is expected to be a string in encoded, serialized raw format.
# Follow the inverse process to obtain the model. First, decode the CLOB from
# base64 into serialized raw by using the "caTools" library. Then, unserialize.
modelInSer <- base64decode(modelIn, "raw")
glmModel <- unserialize(modelInSer)

### Ingest and process the rest of the input data rows
###

# Read remaining input rows directly with read.table(). We only need the
# numeric values from the rest of the input, and read.table() is efficient.
# The "silent" option prevents producing an error message in case input only
# contains the one row that was read earlier.
dt4 <- try(read.table(stdin, sep=DELIMITER, flush=TRUE, header=FALSE,
                      quote="", na.strings="", colClasses=cv),
                      silent=TRUE)
if (class(dt4) == "try-error") {
    # Reached the end of the stream
    inputDF <- NULL
    quit()
}

# Append the remaining rows of numeric data to score
inputDF <- rbind(inputDF, dt4[,1:7]);

# Number of records to score
nObs <- nrow(inputDF)

p_id <- inputDF[,1];
x1   <- inputDF[,2];
x2   <- inputDF[,3];
x3   <- inputDF[,4];
x4   <- inputDF[,5];
x5   <- inputDF[,6];

# Summon the individual records and perform scoring by using the model
dataDF <- data.frame(x1, x2, x3, x4, x5);
colnames(dataDF) <- c("x1", "x2", "x3", "x4", "x5")

Predicted <- suppressWarnings( predict(glmModel, newdata=dataDF,
                                       type="response") );

# Build export data frame:
Scores <- data.frame(p_id, Predicted, x1, x2, x3, x4, x5)

# Export results to the Database through standard output.
write.table(Scores, file=stdout(), col.names=FALSE, row.names=FALSE,
            quote=FALSE, sep=DELIMITER, na="")
