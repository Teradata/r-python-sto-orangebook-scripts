--------------------------------------------------------------------------------
-- The contents of this file are Teradata Public Content
-- and have been released to the Public Domain.
-- Licensed under BSD; see "license.txt" file for more information.
-- Copyright (c) 2020 by Teradata
--------------------------------------------------------------------------------
--
-- R And Python Analytics with the SCRIPT Table Operator
-- Orange Book supplementary material
-- Alexander Kolovos - January 2020 - v.2.0
--
-- Example 5: Linear Regression with the CALCMATRIX table operator
-- File     : ex5dataTblDef.sql
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
-- This SQL script provides the ex5tbl table data required for the example.
--
--------------------------------------------------------------------------------

CREATE TABLE ex5tbl (x1 INTEGER, x2 INTEGER, y INTEGER);
INSERT INTO ex5tbl VALUES (1,2,5);
INSERT INTO ex5tbl VALUES (2,7,14);
INSERT INTO ex5tbl VALUES (3,6,15);
INSERT INTO ex5tbl VALUES (4,15,20);
INSERT INTO ex5tbl VALUES (5,10,25);
INSERT INTO ex5tbl VALUES (6,12,30);

