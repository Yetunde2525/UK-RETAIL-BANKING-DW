/*
===============================================================================
DDL Script: Create Gold Star Schema
===============================================================================
Script Purpose:
    Creates the dimension and fact tables that make up the gold-layer star
    schema, populated from the silver layer by gold.load_gold.

    A few low-cardinality descriptive columns were added on top of the
    original brief's column lists (marked "extension" below) so that the
    20 business questions are answerable directly from the star schema
    without extra joins back to silver. Everything named in the original
    brief is present as specified.

Dimensions:  DimDate, DimCustomer, DimBranch, DimAccount, DimLoan
Facts:       FactTransactions, FactLoans, FactComplaints

WARNING:
    Running this script will DROP all existing tables in the 'gold' schema
    if they already exist. Run the bronze and silver scripts first.
===============================================================================
*/

USE UKRetailBankingDW;
GO

-- ============================================================================
-- gold.DimDate
-- ============================================================================
IF OBJECT_ID('gold.DimDate', 'U') IS NOT NULL DROP TABLE gold.DimDate;
GO
CREATE TABLE gold.DimDate (
    DateKey      INT NOT NULL PRIMARY KEY,   -- yyyymmdd
    FullDate     DATE NOT NULL,
    [Day]        INT,
    [Month]      INT,
    MonthName    NVARCHAR(20),
    Quarter      INT,
    [Year]       INT,
    WeekdayName  NVARCHAR(20)
);
GO

-- ============================================================================
-- gold.DimCustomer
-- ============================================================================
IF OBJECT_ID('gold.DimCustomer', 'U') IS NOT NULL DROP TABLE gold.DimCustomer;
GO
CREATE TABLE gold.DimCustomer (
    CustomerKey       INT IDENTITY(1,1) PRIMARY KEY,
    customer_id       NVARCHAR(20) NOT NULL,
    first_name        NVARCHAR(50),
    last_name         NVARCHAR(50),
    gender            NVARCHAR(20),
    date_of_birth     DATE NULL,
    age               INT NULL,             -- extension: needed for Q2 (age group)
    email             NVARCHAR(100),
    employment_status NVARCHAR(50),
    annual_income     DECIMAL(18,2),
    city              NVARCHAR(50),
    postcode          NVARCHAR(20),
    customer_since    DATE NULL
);
GO

-- ============================================================================
-- gold.DimBranch
-- ============================================================================
IF OBJECT_ID('gold.DimBranch', 'U') IS NOT NULL DROP TABLE gold.DimBranch;
GO
CREATE TABLE gold.DimBranch (
    BranchKey    INT IDENTITY(1,1) PRIMARY KEY,
    branch_id    NVARCHAR(20) NOT NULL,
    branch_name  NVARCHAR(100),
    city         NVARCHAR(50),
    region       NVARCHAR(50),
    opening_date DATE NULL
);
GO

-- ============================================================================
-- gold.DimAccount
-- ============================================================================
IF OBJECT_ID('gold.DimAccount', 'U') IS NOT NULL DROP TABLE gold.DimAccount;
GO
CREATE TABLE gold.DimAccount (
    AccountKey     INT IDENTITY(1,1) PRIMARY KEY,
    account_id     NVARCHAR(20) NOT NULL,
    CustomerKey    INT,                       -- extension: avoids re-joining to DimCustomer
    account_type   NVARCHAR(50),
    BranchKey      INT,
    account_status NVARCHAR(20),
    open_date      DATE NULL
);
GO

-- ============================================================================
-- gold.DimLoan
-- ============================================================================
IF OBJECT_ID('gold.DimLoan', 'U') IS NOT NULL DROP TABLE gold.DimLoan;
GO
CREATE TABLE gold.DimLoan (
    LoanKey         INT IDENTITY(1,1) PRIMARY KEY,
    loan_id         NVARCHAR(20) NOT NULL,
    loan_type       NVARCHAR(50),
    loan_status     NVARCHAR(20),
    interest_rate   DECIMAL(5,2),           -- extension: needed for Q11-Q15
    loan_start_date DATE NULL,
    loan_end_date   DATE NULL
);
GO

-- ============================================================================
-- gold.FactTransactions
-- ============================================================================
IF OBJECT_ID('gold.FactTransactions', 'U') IS NOT NULL DROP TABLE gold.FactTransactions;
GO
CREATE TABLE gold.FactTransactions (
    TransactionKey      INT IDENTITY(1,1) PRIMARY KEY,
    transaction_id       NVARCHAR(20) NOT NULL,  -- extension: degenerate dimension
    CustomerKey          INT,
    AccountKey           INT,
    DateKey              INT,
    Amount               DECIMAL(18,2),
    TransactionType      NVARCHAR(20),           -- extension: needed for Q8
    MerchantName         NVARCHAR(100),          -- extension: needed for Q10
    TransactionChannel   NVARCHAR(30)            -- extension: needed for Q8
);
GO

-- ============================================================================
-- gold.FactLoans
-- ============================================================================
IF OBJECT_ID('gold.FactLoans', 'U') IS NOT NULL DROP TABLE gold.FactLoans;
GO
CREATE TABLE gold.FactLoans (
    FactLoanKey  INT IDENTITY(1,1) PRIMARY KEY,  -- extension: fact's own surrogate key
    LoanKey      INT,
    CustomerKey  INT,
    DateKey      INT,                            -- keyed to loan_start_date
    LoanAmount   DECIMAL(18,2)
);
GO

-- ============================================================================
-- gold.FactComplaints
-- ============================================================================
IF OBJECT_ID('gold.FactComplaints', 'U') IS NOT NULL DROP TABLE gold.FactComplaints;
GO
CREATE TABLE gold.FactComplaints (
    ComplaintKey       INT IDENTITY(1,1) PRIMARY KEY,
    CustomerKey        INT,
    BranchKey          INT,
    DateKey            INT,
    ComplaintCategory  NVARCHAR(50),   -- extension: needed for Q17
    ComplaintStatus    NVARCHAR(20),   -- extension: needed for Q16-Q20
    ResolutionDays     INT             -- extension: needed for Q18
);
GO
