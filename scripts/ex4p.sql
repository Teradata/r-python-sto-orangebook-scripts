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
-- Example 4: System-Wide Parallelism (Python version)
-- File     : ex4p.sql
--
-- Use case:
-- A retail company has 5 stores and retains 3 departments in almost every store
-- We have simulated data of the revenue for each individual department, and we
-- seek to find the global average revenue value per department per store.
-- This is a system-wide task because it requires data from all SQL Engine AMPs.
-- The task takes place in 2 steps, namely a "map" and a "reduce" step that are
-- executed sequentially in 1 query with 2 nested calls to the SCRIPT TO.
--
-- Required input:
-- - "ex4pLoc.py" Python AMP Operations "mapping" script to install in database
-- - "ex4pGlb.py" Python Global Average "reduce" script to install in database
-- - ex4tbl table data from file "ex4data.csv"
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
--
-- Register the script for partial results on AMPs
CALL SYSUIF.REMOVE_FILE('ex4pLoc',1);
CALL SYSUIF.INSTALL_FILE('ex4pLoc','ex4pLoc.py','cz!/root/stoTests/ex4pLoc.py');
--'cz!/root/stoTests/ex4rLoc.r');

-- Register the script for global results across AMPs
CALL SYSUIF.REMOVE_FILE('ex4pGlb',1);
CALL SYSUIF.INSTALL_FILE('ex4pGlb','ex4pGlb.py','cz!/root/stoTests/ex4pGlb.py');
--'cz!/root/stoTests/ex4rGlb.r');

-- The following query is a nested call to the SCRIPT TO. Call the STO twice:
-- The inner call uses Python script to compute the avegage revenue for each 
--                Department across stores.
-- The outer call uses Python script to compute the average revenue across 
--                all Departments and stores.
SELECT CompanyID,
       AllDepts AS Tot_Depts,
       Avg_Dept_Revenue (FORMAT '$$$,$$$,$$$,$$9.99')
FROM SCRIPT(ON (SELECT CompanyID,
                       DepartmentID,
                       Department,
                       AvgRev_Dept,
                       N_Stores
                FROM SCRIPT(ON (SELECT CompanyID,
                                       DepartmentID,
                                       Department,
                                       Revenue AS Rev_Dept
                                FROM ex4tbl)
                            PARTITION BY Department
                            SCRIPT_COMMAND ('python3 ./myDB/ex4pLoc.py')
                            RETURNS ('CompanyID INTEGER, DepartmentID INTEGER, Department VARCHAR(25), AvgRev_Dept FLOAT, N_Stores INTEGER')
                           ) )
            HASH BY CompanyID
            SCRIPT_COMMAND ('python3 ./myDB/ex4pGlb.py')
            RETURNS ('CompanyID INTEGER, AllDepts INTEGER, Avg_Dept_Revenue FLOAT')
           );

-- The following query is a stand-alone version of the inner SCRIPT call.
-- Returns the average revenue per department category across all stores
-- (last column) where each department category is present. 
SELECT CompanyID,
       DepartmentID,
       Department,
       AvgRev_Dept (FORMAT '$$$,$$$,$$$,$$9.99'),
       N_Stores
FROM SCRIPT(ON (SELECT CompanyID,
                       DepartmentID,
                       Department,
                       Revenue AS Rev_Dept
                FROM ex4tbl)
            PARTITION BY Department
            SCRIPT_COMMAND ('python3 ./myDB/ex4pLoc.py')
            RETURNS ('CompanyID INTEGER, DepartmentID INTEGER, Department VARCHAR(25), AvgRev_Dept FLOAT, N_Stores INTEGER')
           );

