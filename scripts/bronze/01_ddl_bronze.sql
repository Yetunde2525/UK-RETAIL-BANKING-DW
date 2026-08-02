/*
===============================================================================
DDL Script: Create Bronze Tables
===============================================================================
Script Purpose:
    This script creates the tables in the 'bronze' schema, dropping existing
    tables first if they already exist. Bronze tables are the raw landing
    zone for the six source CSVs (customers, accounts, transactions, loans,
    complaints, branches) — data is loaded exactly as it comes from source,
    with no cleaning, casting, or transformation applied.

    All columns are deliberately typed as NVARCHAR. The source data contains
    known quality issues (mixed date formats, inconsistent casing, invalid
    or non-numeric values in numeric-looking fields, etc.), so storing
    everything as text guarantees the raw load never fails. Type casting,
    date parsing, deduplication, and standardization all happen downstream
    in the 'silver' layer scripts.

WARNING:
    Running this script will DROP all existing tables in the 'bronze' schema
    if they already exist. All data in those tables will be permanently lost.
    Run 'init_database.sql' first if the database/schemas do not exist yet.
===============================================================================
*/

USE UKRetailBankingDW;
GO

-- ============================================================================
-- bronze.customers
-- ============================================================================
IF OBJECT_ID('bronze.customers', 'U') IS NOT NULL
    DROP TABLE bronze.customers;
GO

CREATE TABLE bronze.customers (
    customer_id        NVARCHAR(20),
    first_name          NVARCHAR(50),
    last_name           NVARCHAR(50),
    gender              NVARCHAR(20),
    date_of_birth        NVARCHAR(20),
    email                NVARCHAR(100),
    phone_number         NVARCHAR(20),
    address              NVARCHAR(200),
    city                 NVARCHAR(50),
    postcode             NVARCHAR(20),
    customer_since       NVARCHAR(20),
    employment_status    NVARCHAR(50),
    annual_income        NVARCHAR(20)
);
GO

-- ============================================================================
-- bronze.accounts
-- ============================================================================
IF OBJECT_ID('bronze.accounts', 'U') IS NOT NULL
    DROP TABLE bronze.accounts;
GO

CREATE TABLE bronze.accounts (
    account_id          NVARCHAR(20),
    customer_id         NVARCHAR(20),
    account_type        NVARCHAR(50),
    branch_id           NVARCHAR(20),
    open_date           NVARCHAR(20),
    account_status      NVARCHAR(20),
    current_balance     NVARCHAR(20)
);
GO

-- ============================================================================
-- bronze.transactions
-- ============================================================================
IF OBJECT_ID('bronze.transactions', 'U') IS NOT NULL
    DROP TABLE bronze.transactions;
GO

CREATE TABLE bronze.transactions (
    transaction_id      NVARCHAR(20),
    account_id          NVARCHAR(20),
    transaction_date    NVARCHAR(20),
    transaction_type    NVARCHAR(20),
    amount              NVARCHAR(20),
    merchant_name       NVARCHAR(100),
    transaction_channel NVARCHAR(30)
);
GO

-- ============================================================================
-- bronze.loans
-- ============================================================================
IF OBJECT_ID('bronze.loans', 'U') IS NOT NULL
    DROP TABLE bronze.loans;
GO

CREATE TABLE bronze.loans (
    loan_id             NVARCHAR(20),
    customer_id         NVARCHAR(20),
    loan_type           NVARCHAR(50),
    loan_amount         NVARCHAR(20),
    interest_rate       NVARCHAR(20),
    loan_start_date     NVARCHAR(20),
    loan_end_date       NVARCHAR(20),
    loan_status         NVARCHAR(20)
);
GO

-- ============================================================================
-- bronze.complaints
-- ============================================================================
IF OBJECT_ID('bronze.complaints', 'U') IS NOT NULL
    DROP TABLE bronze.complaints;
GO

CREATE TABLE bronze.complaints (
    complaint_id        NVARCHAR(20),
    customer_id         NVARCHAR(20),
    complaint_date       NVARCHAR(20),
    complaint_category  NVARCHAR(50),
    complaint_status    NVARCHAR(20),
    resolution_days     NVARCHAR(10),
    branch_id           NVARCHAR(20)
);
GO

-- ============================================================================
-- bronze.branches
-- ============================================================================
IF OBJECT_ID('bronze.branches', 'U') IS NOT NULL
    DROP TABLE bronze.branches;
GO

CREATE TABLE bronze.branches (
    branch_id           NVARCHAR(20),
    branch_name         NVARCHAR(100),
    city                NVARCHAR(50),
    region              NVARCHAR(50),
    opening_date        NVARCHAR(20)
);
GO
