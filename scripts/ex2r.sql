--------------------------------------------------------------------------------
-- The contents of this file are Teradata Public Content
-- and have been released to the Public Domain.
-- Licensed under BSD; see "license.txt" file for more information.
-- Copyright (c) 2021 by Teradata
--------------------------------------------------------------------------------
--
-- R And Python Analytics with SCRIPT Table Operator
-- Orange Book supplementary material
-- Alexander Kolovos - October 2021 - v.2.1
--
-- Example 2: Clustering (R version)
-- File     : ex2r.sql
--
-- Use case:
-- Based on Pycluster Workshop example in "Data Analysis with Open Source Tools
-- by Philipp K. Janert. Copyright 2011 Philipp K. Janert, 978-0-596-80235-6
-- Identify a user-specified number of clusters in given data set of points at
-- given locations. Classify each observation of the data set into a cluster,
-- on the basis of the observation coordinates.
--
-- Required input:
-- - "ex2r.r" R script to install in database
-- - ex2tbl table data from file "ex2data.csv"
--
-- In present example, the R script has 1 optional input argument:
-- - n : The number of clusters we want to create (default: n=5)
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

-- Adjust names and path appropriately for your filesystem in the following.
CALL SYSUIF.REMOVE_FILE('ex2r',1);
CALL SYSUIF.INSTALL_FILE('ex2r','ex2r.r','cz!/root/stoTests/ex2r.r');

-- The following hashes the input table by the ObsGroup column to send obs
-- of the same ObsGroup value to the same amp.
-- The RETURNS clause specifies to divide the data into n clusters.
SELECT oc2 AS ObsGrp,
       oc1 AS ObsID,
       oc3 AS ClustID,
       oc4 AS X_Centroid,
       oc5 AS Y_Centroid,
       oc7 AS ObsSilhCoeff
FROM SCRIPT (ON (SELECT * FROM ex2tbl)
             PARTITION BY ObsGroup
             ORDER BY ObsID
             SCRIPT_COMMAND('Rscript --vanilla ./myDB/ex2r.r 7')
             RETURNS ('oc1 INT, oc2 INT, oc3 INT, oc4 FLOAT, oc5 FLOAT, oc6 FLOAT, oc7 FLOAT, oc8 FLOAT')
            ) AS D
ORDER BY ObsGrp, ClustID
WITH AVG(D.oc8) (TITLE 'Avg Silhouette Coefficient') BY ObsGrp;

-- Utility to explore the hash map: Which values of the primary indexed column
-- go to which amp? For illustration, use the ObsID column sequence of values
-- as input to HASH functions.
SELECT DISTINCT ObsGroup,
       HASHAMP(HASHBUCKET(HASHROW(ObsGroup))) AS HAmp
FROM ex2tbl
ORDER BY 1;

-- If data are partitioned in AMPs, then it would show in the following
SELECT partition, COUNT(*)
FROM ex2tbl
GROUP BY 1 ORDER BY 1;
