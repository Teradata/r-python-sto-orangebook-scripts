## R and Python Analytics with SCRIPT Table Operator
### Orange Book supplementary material

A companion collection of R and Python for the Teradata Orange Book "**R and Python Analytics with SCRIPT Table Operator**". The current script bundle is v.2.5 in support of revision 4.4.0 or later of the Orange Book.

### R and Python In-nodes in Vantage

Since Teradata Database v.15.00, the SCRIPT Table Operator (STO) can be used to execute R and Python scripts natively in the database nodes.  A related Orange Book has been written as a guide to use data stored in the Analytics Database in analytics applications with R and Python through the STO on Vantage Enterprise and Vantage Core systems.  This Orange Book provides

* detailed steps about setting up R and Python on a Vantage system Analytics Database
* adding functionality to these languages by means of add-on library packages
* selected examples that illustrate how to compose and execute R and Python scripts under the STO for common analytical tasks
* best practices, tips and guidelines about executing R and Python scripts in Analytics Database nodes
* best practices, tips and guidelines about preserving Analytics Database resources when using the SCRIPT and/or ExecR Table Operators

The present repo houses the R and Python scripts and corresponding data sets for the Orange Book examples. Simply download the material and use it against a target Analytics Database on a Vantage Enterprise or Vantage Core system.  Details about script installation and usage are available in the Orange Book.

### Table of Contents

The present package comprises of the following folders and files. See the README file in each one of those folders for more specific information.

* README.txt
* license.txt
* bin/
    + tdstoMemInspect.sh
* data/
    * ex1dataprep/
        + ex1dataFit.csv
        + ex1pFit.py
        + ex1rFit.r
    + ex1dataSco.csv
    + ex1dataSco.fastload
    * ex2dataprep/
        + ex2dataGen.py
    + ex2data.csv
    + ex2data.fastload
    + ex3dataFit.csv
    + ex3dataFit.fastload
    + ex3dataMiniFit.csv
    + ex3dataMiniFit.fastload
    + ex3dataMiniSco.csv
    + ex3dataMiniSco.fastload
    + ex3dataSco.csv
    + ex3dataSco.fastload
    + ex4data.csv
    + ex4data.fastload
    + ex5dataTblDef.sql
* scripts/
    + ex1pMod.out
    + ex1pSco.py
    + ex1pScoNonIter.py
    + ex1p.sql
    + ex1rMod.rds
    + ex1rSco.r
    + ex1rScoNonIter.r
    + ex1r.sql
    + ex2p.py
    + ex2p.sql
    + ex2r.r
    + ex2r.sql
    + ex3pFit.py
    + ex3pSco.py
    + ex3pScoNonIter.py
    + ex3p.sql
    + ex3rFit.r
    + ex3rSco.r
    + ex3rScoNonIter.r
    + ex3r.sql
    + ex4pGlb.py
    + ex4pLoc.py
    + ex4p.sql
    + ex4rGlb.r
    + ex4rLoc.r
    + ex4r.sql
    + ex5p.py
    + ex5p.sql
    + ex5r.r
    + ex5r.sql
