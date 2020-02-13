R And Python Analytics with SCRIPT Table Operator
Orange Book supplementary material
Alexander Kolovos - February 2020 - v.2.0

-------------------------------------------------------------------------------

About

The contents of this file are Teradata Public Content
and have been released to the Public Domain.
Licensed under BSD; see "license.txt" file for more information.
Copyright (c) 2020 by Teradata

-------------------------------------------------------------------------------

Information

The present package is a collection of data, SQL, R and Python scripts to use
with the Orange Book "R And Python Analytics with SCRIPT Table Operator".
The data and scripts implement the examples presented in this Orange Book.
The material provided has been based on research done on Vantage SQL Engine
Version 16.20 systems installed on the SUSE Linux Enterprise Server 12 Service 
Pack 3 (SLES12-SP3) operating system.

The package also includes the Bash shell script "tdstoMemInspect.sh". This is a
utility to probe a SQL Engine node for SCRIPT upper memory threshold based on
a) the current ScriptMemLimit value on the SQL Engine, and
b) memory availability on that node.
This script should be executed on a SQL Engine node of a Vantage system by a
user with administrative rights. See the script file for more details.
The shell script file is located in the bin/ directory of this package.

The following is a listing of all other data and script files included in the
present package to reproduce the examples in the Orange Book. The listing
cites the contents of this package according to the example they appear in the
Orange Book.

All .csv files are text data files; they are located in the data/ directory.
The data/ directory also contains a SQL file with the example 7 input table
definition and data, and directories ex1dataprep/ and ex2dataprep/ with
additional files that are needed if the user wishes to re-create selected
data input used in Examples 1 and 2. See the Orange Book for more details.

All other files are located in the scripts/ directory of this package.

Example 1:

ex1dataFit.csv          Input data for model-fitting scripts (for client)
ex1dataSco.csv          Input data for scoring scripts (6,000 records)
ex1dataSco.fastload     Teradata FastLoad script to upload the example data
ex1pFit.py              Python model fitting script (for client) 
ex1pMod.out             Python object file with scoring model
ex1pSco.py              Python scoring script
ex1pScoIter.py          Python scoring script with iterative data read
ex1p.sql                SQL statements to run the Python scoring script
ex1rFit.r               R model fitting script (for client)
ex1rMod.rds             R object file with scoring model
ex1rSco.r               R scoring script
ex1rScoIter.r           R scoring script with iterative data read
ex1r.sql                SQL statements to run the R scoring script

Example 2:

ex2dataGen.py           Python script to generate input data set for example
ex2data.csv             Input data for the STO (10,000 records)
ex2data.fastload        Teradata FastLoad script to upload the example data
ex2p.py                 Python script for clustering example
ex2p.sql                SQL statements to run the Python script
ex2r.r                  R script for clustering example
ex2r.sql                SQL statements to run the R script

Example 3:

ex3dataFit.csv          Data subset for model fitting (900,000 records)
ex3dataFit.fastload     Teradata FastLoad script to upload fitting data
ex3dataSco.csv          Data subset for scoring (100,000 records)
ex3dataSco.fastload     Teradata FastLoad script to upload scoring data
ex3pFit.py              Python script for the example logistic regression fit
ex3pSco.py              Python scoring script
ex3pScoIter.py          Python scoring script with iterative data read
ex3p.sql                SQL statements to run all Python scripts in example
ex3rFit.r               R script for the example logistic regression fit
ex3rSco.r               R scoring script
ex3rScoIter.r           R scoring script with iterative data read
ex3r.sql                SQL statements to run all R scripts in example
ex3dataMiniFit.csv      Smaller data subset for model fitting (3,000 records)
ex3dataMiniFit.fastload Teradata FastLoad script to upload fitting data
ex3dataMiniSco.csv      Smaller data subset for scoring (300 records)
ex3dataMiniSco.fastload Teradata FastLoad script to upload scoring data

Example 4:

ex4data.csv             Data (21,642 records, business revenue information)
ex4data.fastload        Teradata FastLoad script to upload fitting data
ex4pLoc.py              Python script to compute average in data partitions
ex4pGlb.py              Python script to get global average from partial results
ex4p.sql                SQL statements to run all Python scripts in example
ex4rLoc.r               R script to compute average in data partitions
ex4rGlb.r               R script to compute global average from partial results
ex4r.sql                SQL statements to run all R scripts in example

Example 5:

ex5dataTblDef.sql       Contains the definition and data of the input data table
ex5p.py                 Python script for the linear regression example
ex5p.sql                SQL statements to run the example Python script
ex5r.r                  R script for the linear regression example
ex5r.sql                SQL statements to run the example R script

-------------------------------------------------------------------------------

Changelog

Version 2.0: (20 Jan 2020)
* Transitioned Python code from Python 2 into Python 3
* Now using Fastload scripts and CSV data files throughout to load example
  data to target systems.
* Examples 2 and 4 of version 1.x have been removed.
* Example 3 of version 1.x has been updated to use Python add-ons that are
  currently actively supported.
* Examples 1 and 3 of version 1.x have been expanded to include scripts for
  both R and Python.
* Examples 1 and 3 have been further expanded to include versions where data
  are read in chunks iteratively, for both R and Python.
* All scripts have been revised to work with R v.3.5.1 and Python v.3.6.7.
* Inclusion of the tdstoMemInspect.sh Bash shell script.

Version 1.2: (4 Sep 2015)
* In Example 5:
  - The example now contains a Python version next to the R version.
  - The table created by R script "ex5rFit.r" has been renamed to "ex5modelR"
    to distinguish from "ex5modelPy" produced when using the Python script.
* Example 6 has been extended to include Python script versions.
* Example 7 has been added.

Version 1.1: (16 Apr 2015)
* ex4r.r, l.125: Call to png() has been modified so that plots are produced by
  using the Cairo framework.

Version 1.0: (31 Mar 2015)
* Initial version.

