/*
===============================================================================
Create Database and Schemas
===============================================================================
Script Purpose:
    This script creates a new database named 'UKRetailBankingDW' after checking
    whether it already exists. If the database exists, it is dropped and
    recreated from scratch. The script then creates three schemas inside the
    database — 'bronze', 'silver', and 'gold' — representing the Medallion
    Architecture layers used throughout this project:

        bronze  -> raw, unprocessed data loaded as-is from the source CSVs
                   (customers, accounts, transactions, loans, complaints,
                   branches), including all known data quality issues.
        silver  -> cleansed, standardized, and conformed data (fixed date
                   formats, deduplicated customers, standardized casing, etc.).
        gold    -> business-ready, aggregated views used for reporting and
                   the Power BI dashboard.

    This is the first script in the pipeline and must be run before any of
    the bronze/silver/gold table or view creation scripts.

WARNING:
    Running this script will completely DROP the 'UKRetailBankingDW' database
    if it already exists. ALL data, tables, views, and stored procedures in
    that database will be permanently deleted and cannot be recovered.

    Do NOT run this script against a production or shared environment.
    Make sure you have a backup (or are working in a disposable/local SQL
    Server instance) before executing this script.
===============================================================================
*/

USE master;
GO

-- Drop and recreate the 'UKRetailBankingDW' database if it already exists
IF EXISTS
        (SELECT 1 FROM sys.databases WHERE name = 'UKRetailBankingDW')
BEGIN
    ALTER DATABASE UKRetailBankingDW SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE UKRetailBankingDW;
END;
GO

-- Create the 'UKRetailBankingDW' database
CREATE DATABASE UKRetailBankingDW;
GO

USE UKRetailBankingDW;
GO

-- Create Schemas for the Medallion Architecture
CREATE SCHEMA bronze;
GO

CREATE SCHEMA silver;
GO

CREATE SCHEMA gold;
GO
