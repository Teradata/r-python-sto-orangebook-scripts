--------------------------------------------------------------------------------
-- The contents of this file are Teradata Public Content
-- and have been released to the Public Domain.
-- Licensed under BSD; see "license.txt" file for more information.
-- Copyright (c) 2020 by Teradata
--------------------------------------------------------------------------------
--
-- R And Python Analytics with SCRIPT Table Operator
-- Orange Book supplementary material
-- Alexander Kolovos - February 2020 - v.2.0
--
-- Example 5: Linear Regression with the CALCMATRIX table operator (R version)
-- File: ex5r.sql
--
-- (Adapted from the Teradata Developer Exchange online example by Mike Watzke:
--  http://developer.teradata.com/extensibility/articles/
--  in-database-linear-regression-using-the-calcmatrix-table-operator)
--
-- Use case:
-- A simple example of linear regression with one dependent and two independent
-- variables (univariate, multiple variable regression). For the regression
-- computations, we need to calculate the sums of squares and cross-products 
-- matrix of the data. The example illustrates how to use the CALCMATRIX table
-- operator for this task. The script returns the estimates of the regression 
-- coefficients.
-- 
-- Required input:
-- - "ex5r.r" R script to install in database
-- - ex5tbl table data from file "ex5dataTblDef.sql"
--
-- Reminder: In case of errors, you can find the STO full standard error output
--   for each node in the corresponding node file:
--   /var/opt/teradata/tdtemp/uiflib/scriptlog
--   Administrative user privilege may be required to read the above file(s).
--   Alternatively, query the file contents as a standard database user with:
--   SELECT DISTINCT SUBSTR(scriptlog, 1, index(scriptlog, 'Vproc')-1) ||
--       SUBSTR(scriptlog, 1+ regexp_instr(scriptlog, ':', 1,3)) AS script_log
--   FROM SCRIPT (
--            SCRIPT_COMMAND ('tail /var/opt/teradata/tdtemp/uiflib/scriptlog')
--            RETURNS ('scriptlog VARCHAR(256)') );
--
--------------------------------------------------------------------------------

DATABASE myDB;
SET SESSION SEARCHUIFDBPATH = myDB;

.set errorout stdout
.set width 200

-- Adjust names and path appropriately for your filesystem in the following.
CALL SYSUIF.REMOVE_FILE('ex5r',1);
CALL SYSUIF.INSTALL_FILE('ex5r','ex5r.r','cz!/root/stoTests/ex5r.r');

-- Use an R script to perform linear regression on the data provided 
-- in table ex5tbl. The needed sum of squares and cross products is computed
-- by intermediately calling the CALCMATRIX table operator and asking for the
-- 'ESSCP' calculation type.
SELECT oc1 AS Coefficient, 
       oc2 AS cValue
FROM SCRIPT( ON( SELECT * 
                 FROM CALCMATRIX 
                      (ON (SELECT SESSION AS ampkey, D1.* 
                           FROM CALCMATRIX (ON (SELECT * FROM ex5tbl)
                                            USING PHASE('LOCAL') ) AS D1 )
                       HASH BY ampkey
                       USING PHASE('COMBINE') CALCTYPE('ESSCP') ) AS D2 )
             SCRIPT_COMMAND('Rscript --vanilla ./myDB/ex5r.r')
             RETURNS ('oc1 VARCHAR(20), oc2 FLOAT')
           ) AS D;

