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
-- Example 3: Multiple Models Fitting and Scoring (R version)
-- File     : ex3r.sql
--
-- Use case:
-- Using simulated data for a retail store:
-- Model fitting step ("ex3rFit.r"): Fit a model to each one of specified
--   product IDs, each featuring 5 dependent variables x1,...,x5. Return the 
--   model information back to Vantage, and store it in a table.
-- Model scoring step ("ex3rSco.r"): Score a set of records for each one
--   of the product IDs.
--
-- Required input:
--   Model fitting step:
--   - "ex3rFit.r" fitting R script to install in database
--   - ex3tblFit table data from file "ex3dataFit.csv" to install in database
-- Model scoring step:
--   - "ex3rSco.r" scoring R script to install in database
--   - ex3tblSco table data from file "ex3dataSco.csv" to install in database
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

-- Segment 1: Model fitting
--
-- Adjust names and path appropriately for your filesystem in the following.
CALL SYSUIF.REMOVE_FILE('ex3rFit',1);
CALL SYSUIF.INSTALL_FILE('ex3rFit','ex3rFit.r','cz!/root/stoTests/ex3rFit.r');

-- Use following statement, if applicable, to remove existing table version
DROP TABLE ex3modelR;

-- Use R script to fit one model per Product IDi; save all as CLOBs in TD table
CREATE TABLE ex3modelR AS (
    SELECT oc1 AS p_id,
           oc2 AS r_model
    FROM SCRIPT ( ON (SELECT * FROM ex3tblFit)
                  PARTITION BY p_id
                  SCRIPT_COMMAND('Rscript --vanilla ./myDB/ex3rFit.r')
                  RETURNS ('oc1 VARCHAR(20), oc2 CLOB')
                ) AS d
) WITH DATA
PRIMARY INDEX (p_id);

-- Segment 2: Scoring with models
--
-- Adjust names and path appropriately for your filesystem in the following.
CALL SYSUIF.REMOVE_FILE('ex3rSco',1);
CALL SYSUIF.INSTALL_FILE('ex3rSco','ex3rSco.r','cz!/root/stoTests/ex3rSco.r');

-- Run script and save results into a table. Drop the table, if already exists.
DROP TABLE ex3rOutTbl;

-- Use R script to score series of records for each Product ID according to
-- corresponding saved models. The "ORDER BY nRow" clause is crucial in the
-- following to provide correctly the model information in first row of input
CREATE MULTISET TABLE ex3rOutTbl AS (
    SELECT oc1 AS p_id,
           oc2 AS Prediction,
           oc3 AS x1, 
           oc4 AS x2, 
           oc5 AS x3, 
           oc6 AS x4, 
           oc7 AS x5
    FROM SCRIPT( ON(SELECT s.*,
                           CASE WHEN nRow=1 THEN m.r_model ELSE null END 
                    FROM (SELECT x.*,
                                 row_number() OVER (PARTITION BY x.p_id ORDER BY x.p_id) AS nRow
                          FROM ex3tblSco x) AS s, ex3modelR m 
                    WHERE s.p_id = m.p_id)
                 PARTITION BY s.p_id
                 ORDER BY nRow
                 SCRIPT_COMMAND('Rscript --vanilla ./myDB/ex3rSco.r')
                 RETURNS ('oc1 INTEGER, oc2 FLOAT, oc3 FLOAT, oc4 FLOAT, oc5 FLOAT, oc6 FLOAT, oc7 FLOAT')
               ) AS d
) WITH DATA
PRIMARY INDEX (p_id);

-- Segment 3: Scoring with models (script uses iterative data read)
--
-- Adjust names and path appropriately for your filesystem in the following.
CALL SYSUIF.REMOVE_FILE('ex3rScoIter',1);
CALL SYSUIF.INSTALL_FILE('ex3rScoIter','ex3rScoIter.r','cz!/root/stoTests/ex3rScoIter.r');

-- Run script and save results into a table. Drop the table, if already exists.
DROP TABLE ex3rOutTbl;

-- Use R script to score series of records for each Product ID according to
-- corresponding saved models. The "ORDER BY nRow" clause is crucial in the
-- following to provide correctly the model information in first row of input
CREATE MULTISET TABLE ex3rOutTbl AS (
    SELECT oc1 AS p_id,
           oc2 AS Prediction,
           oc3 AS x1,
           oc4 AS x2,
           oc5 AS x3,
           oc6 AS x4,
           oc7 AS x5
    FROM SCRIPT( ON(SELECT s.*,
                           CASE WHEN nRow=1 THEN m.r_model ELSE null END
                    FROM (SELECT x.*,
                                 row_number() OVER (PARTITION BY x.p_id ORDER BY x.p_id) AS nRow
                          FROM ex3tblSco x) AS s, ex3modelR m
                    WHERE s.p_id = m.p_id)
                 PARTITION BY s.p_id
                 ORDER BY nRow
                 SCRIPT_COMMAND('Rscript --vanilla ./myDB/ex3rScoIter.r')
                 RETURNS ('oc1 INTEGER, oc2 FLOAT, oc3 FLOAT, oc4 FLOAT, oc5 FLOAT, oc6 FLOAT, oc7 FLOAT')
               ) AS d
) WITH DATA
PRIMARY INDEX (p_id);
                                                              71,1          98%
