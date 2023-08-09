--------------------------------------------------------------------------------
-- The contents of this file are Teradata Public Content
-- and have been released to the Public Domain.
-- Licensed under BSD; see "license.txt" file for more information.
-- Copyright (c) 2023 by Teradata
--------------------------------------------------------------------------------
--
-- R And Python Analytics with SCRIPT Table Operator
-- Orange Book supplementary material
-- Alexander Kolovos - July 2023 - v.2.5
--
-- Example 1: Scoring (Python version)
-- File     : ex1p.sql
--
-- Score input rows from database by using model information from
-- an existing Python object.
-- Use case:
-- Predict the propensity of a financial services customer base
-- to open a credit card account.
--
-- Required input:
-- - "ex1pSco.py" Python scoring script to install in database
-- - "ex1pMod.out" scoring model Python object file to install in database
-- - ex1tblSco table data from file "ex1dataSco.csv"
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
.set width 100

-- Install model file. Adjust names and paths appropriately for your filesystem.
CALL SYSUIF.REMOVE_FILE('ex1pMod',1);
CALL SYSUIF.INSTALL_FILE('ex1pMod','ex1pMod.out','cb!/root/stoTests/ex1pMod.out');

-- Scoring with the model
--
-- Install script. Adjust names and paths appropriately for your filesystem.
CALL SYSUIF.REMOVE_FILE('ex1pSco',1);
CALL SYSUIF.INSTALL_FILE('ex1pSco','ex1pSco.py','cz!/root/stoTests/ex1pSco.py');

-- Run script and save results into a table. Drop the table, if already exists.
DROP TABLE ex1pOutTbl;

CREATE MULTISET TABLE ex1pOutTbl AS (
    SELECT oc1 AS Cust_ID,
           oc2 AS Prob0,
           oc3 AS Prob1,
           oc4 AS Actual
    FROM SCRIPT( ON (SELECT * FROM ex1tblSco)
                 SCRIPT_COMMAND('tdpython3 ./myDB/ex1pSco.py')
                 RETURNS ('oc1 INTEGER, oc2 FLOAT, oc3 FLOAT, oc4 INTEGER')
               ) AS D
) WITH DATA
PRIMARY INDEX (Cust_ID);

-- Segment 2: Scoring with the model (script uses non-iterative data read)
--
-- Install script. Adjust names and paths appropriately for your filesystem.
CALL SYSUIF.REMOVE_FILE('ex1pScoNonIter',1);
CALL SYSUIF.INSTALL_FILE('ex1pScoNonIter','ex1pScoNonIter.py','cz!/root/stoTests/ex1pScoNonIter.py');

-- Run script and save results into a table. Drop the table, if already exists.
DROP TABLE ex1pOutTbl;

CREATE MULTISET TABLE ex1pOutTbl AS (
    SELECT oc1 AS Cust_ID,
           oc2 AS Prob0,
           oc3 AS Prob1,
           oc4 AS Actual
    FROM SCRIPT( ON (SELECT * FROM ex1tblSco)
                 SCRIPT_COMMAND('tdpython3 ./myDB/ex1pScoNonIter.py')
                 RETURNS ('oc1 INTEGER, oc2 FLOAT, oc3 FLOAT, oc4 INTEGER')
               ) AS D
) WITH DATA
PRIMARY INDEX (Cust_ID);

-- Utility query: How many observations are there on each system AMP?
SELECT COUNT(Cust_ID) AS NObs,
       HASHAMP(HASHBUCKET(HASHROW(Cust_ID))) AS HAmp
FROM ex1tblSco
GROUP BY 2;
