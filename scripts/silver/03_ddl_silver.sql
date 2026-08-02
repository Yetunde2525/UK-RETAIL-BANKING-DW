/*
===============================================================================
DDL Script: Create Silver Tables + Helper Functions
===============================================================================
Script Purpose:
    Creates two reusable scalar functions used throughout the silver
    transformation logic, then creates the six silver tables that hold
    cleaned, standardized, and validated versions of the bronze data.

    Silver tables keep every row from bronze (nothing is deleted here) but
    add validity flags (is_email_valid, is_valid_account, etc.) so that bad
    records can be filtered out downstream in the gold layer, instead of
    silently disappearing.

Helper Functions:
    dbo.fn_ParseMessyDate  -> tries multiple date formats (ISO, dd/MM/yyyy,
                              dd-MMM-yyyy) and returns a proper DATE, or NULL
                              if none of them match.
    dbo.fn_ProperCase      -> title-cases a single name/word
                              (e.g. 'ADAM' / 'adam' -> 'Adam').

WARNING:
    Running this script will DROP all existing tables in the 'silver' schema
    if they already exist, and will replace the two helper functions if
    they already exist. Run 00_init_database.sql and the bronze scripts
    first.
===============================================================================
*/

USE UKRetailBankingDW;
GO

-- ============================================================================
-- Helper function: parse messy/mixed-format date strings
-- ============================================================================
CREATE OR ALTER FUNCTION dbo.fn_ParseMessyDate (@input NVARCHAR(50))
RETURNS DATE
AS
BEGIN
    DECLARE @result DATE;
    SET @input = LTRIM(RTRIM(@input));

    IF @input IS NULL OR @input = ''
        RETURN NULL;

    -- ISO format: yyyy-MM-dd
    SET @result = TRY_CONVERT(DATE, @input, 23);
    IF @result IS NOT NULL RETURN @result;

    -- British format: dd/MM/yyyy
    SET @result = TRY_CONVERT(DATE, @input, 103);
    IF @result IS NOT NULL RETURN @result;

    -- Textual formats: dd-MMM-yyyy, dd MMM yyyy, etc. (British culture)
    SET @result = TRY_PARSE(@input AS DATE USING 'en-GB');
    IF @result IS NOT NULL RETURN @result;

    RETURN NULL;
END
GO

-- ============================================================================
-- Helper function: title-case a single word / name
-- ============================================================================
CREATE OR ALTER FUNCTION dbo.fn_ProperCase (@input NVARCHAR(100))
RETURNS NVARCHAR(100)
AS
BEGIN
    IF @input IS NULL OR LTRIM(RTRIM(@input)) = ''
        RETURN NULL;

    RETURN UPPER(LEFT(LTRIM(RTRIM(@input)), 1))
         + LOWER(SUBSTRING(LTRIM(RTRIM(@input)), 2, LEN(@input)));
END
GO

-- ============================================================================
-- silver.branches
-- ============================================================================
IF OBJECT_ID('silver.branches', 'U') IS NOT NULL DROP TABLE silver.branches;
GO
CREATE TABLE silver.branches (
    branch_id       NVARCHAR(20)  NOT NULL PRIMARY KEY,
    branch_name     NVARCHAR(100),
    city            NVARCHAR(50),
    region          NVARCHAR(50),
    opening_date    DATE NULL,
    dwh_create_date DATETIME2 NOT NULL DEFAULT SYSDATETIME()
);
GO

-- ============================================================================
-- silver.customers
-- ============================================================================
IF OBJECT_ID('silver.customers', 'U') IS NOT NULL DROP TABLE silver.customers;
GO
CREATE TABLE silver.customers (
    customer_id       NVARCHAR(20) NOT NULL PRIMARY KEY,
    first_name        NVARCHAR(50),
    last_name         NVARCHAR(50),
    gender            NVARCHAR(20),
    date_of_birth     DATE NULL,
    email             NVARCHAR(100) NULL,
    is_email_valid    BIT NOT NULL DEFAULT 0,
    phone_number      NVARCHAR(20),
    address           NVARCHAR(200),
    city              NVARCHAR(50),
    postcode          NVARCHAR(20),
    customer_since    DATE NULL,
    employment_status NVARCHAR(50),
    annual_income     DECIMAL(18,2) NULL,
    dwh_create_date   DATETIME2 NOT NULL DEFAULT SYSDATETIME()
);
GO

-- ============================================================================
-- silver.accounts
-- ============================================================================
IF OBJECT_ID('silver.accounts', 'U') IS NOT NULL DROP TABLE silver.accounts;
GO
CREATE TABLE silver.accounts (
    account_id       NVARCHAR(20) NOT NULL PRIMARY KEY,
    customer_id      NVARCHAR(20),
    account_type     NVARCHAR(50),
    branch_id        NVARCHAR(20),
    open_date        DATE NULL,
    account_status   NVARCHAR(20),
    current_balance  DECIMAL(18,2) NULL,
    dwh_create_date  DATETIME2 NOT NULL DEFAULT SYSDATETIME()
);
GO

-- ============================================================================
-- silver.transactions
-- ============================================================================
IF OBJECT_ID('silver.transactions', 'U') IS NOT NULL DROP TABLE silver.transactions;
GO
CREATE TABLE silver.transactions (
    transaction_id      NVARCHAR(20) NOT NULL PRIMARY KEY,
    account_id          NVARCHAR(20),
    transaction_date    DATE NULL,
    transaction_type    NVARCHAR(20),
    amount              DECIMAL(18,2) NULL,
    merchant_name       NVARCHAR(100),
    transaction_channel NVARCHAR(30),
    is_valid_account    BIT NOT NULL DEFAULT 0,
    dwh_create_date     DATETIME2 NOT NULL DEFAULT SYSDATETIME()
);
GO

-- ============================================================================
-- silver.loans
-- ============================================================================
IF OBJECT_ID('silver.loans', 'U') IS NOT NULL DROP TABLE silver.loans;
GO
CREATE TABLE silver.loans (
    loan_id               NVARCHAR(20) NOT NULL PRIMARY KEY,
    customer_id           NVARCHAR(20),
    loan_type             NVARCHAR(50),
    loan_amount           DECIMAL(18,2) NULL,
    interest_rate         DECIMAL(5,2) NULL,
    is_interest_rate_valid BIT NOT NULL DEFAULT 0,
    loan_start_date       DATE NULL,
    loan_end_date         DATE NULL,
    loan_status           NVARCHAR(20),
    dwh_create_date       DATETIME2 NOT NULL DEFAULT SYSDATETIME()
);
GO

-- ============================================================================
-- silver.complaints
-- ============================================================================
IF OBJECT_ID('silver.complaints', 'U') IS NOT NULL DROP TABLE silver.complaints;
GO
CREATE TABLE silver.complaints (
    complaint_id            NVARCHAR(20) NOT NULL PRIMARY KEY,
    customer_id             NVARCHAR(20),
    complaint_date          DATE NULL,
    complaint_category      NVARCHAR(50),
    complaint_status        NVARCHAR(20),
    resolution_days         INT NULL,
    is_resolution_days_valid BIT NOT NULL DEFAULT 0,
    branch_id               NVARCHAR(20),
    dwh_create_date         DATETIME2 NOT NULL DEFAULT SYSDATETIME()
);
GO
