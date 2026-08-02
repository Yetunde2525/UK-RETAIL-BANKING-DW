/*
===============================================================================
Stored Procedure: gold.load_gold
===============================================================================
Script Purpose:
    Builds the DimDate calendar table (if empty) and loads all dimension and
    fact tables in the gold star schema from the silver layer.

    Only clean rows are carried into the facts:
      - FactTransactions excludes transactions whose account_id didn't match
        any account (is_valid_account = 0 in silver).
      - FactLoans/DimLoan carries the is_interest_rate_valid flag through as
        NULL interest_rate rather than dropping the loan.
      - FactComplaints carries resolution_days through as NULL when invalid
        rather than dropping the complaint.

WARNING:
    This procedure TRUNCATEs every gold table before reloading it. Run
    05_ddl_gold.sql first, and silver.load_silver before this.

Usage:
    EXEC gold.load_gold;
===============================================================================
*/

USE UKRetailBankingDW;
GO

CREATE OR ALTER PROCEDURE gold.load_gold AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @start_time DATETIME, @batch_start DATETIME;

    BEGIN TRY
        SET @batch_start = GETDATE();
        PRINT '===============================================';
        PRINT 'Loading Gold Layer';
        PRINT '===============================================';

        -- DimDate: build once, covering 2000-01-01 to 2035-12-31 -----------
        IF NOT EXISTS (SELECT 1 FROM gold.DimDate)
        BEGIN
            SET @start_time = GETDATE();
            PRINT '>> Building: gold.DimDate';

            ;WITH n AS (
                SELECT TOP (13150) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS rn
                FROM sys.all_objects a CROSS JOIN sys.all_objects b
            ),
            dates AS (
                SELECT DATEADD(DAY, rn, '2000-01-01') AS FullDate FROM n
            )
            INSERT INTO gold.DimDate (DateKey, FullDate, [Day], [Month], MonthName, Quarter, [Year], WeekdayName)
            SELECT
                CONVERT(INT, FORMAT(FullDate, 'yyyyMMdd')),
                FullDate,
                DAY(FullDate),
                MONTH(FullDate),
                DATENAME(MONTH, FullDate),
                DATEPART(QUARTER, FullDate),
                YEAR(FullDate),
                DATENAME(WEEKDAY, FullDate)
            FROM dates;
            PRINT '>> Duration: ' + CAST(DATEDIFF(SECOND, @start_time, GETDATE()) AS NVARCHAR) + ' sec';
        END

        -- DimCustomer --------------------------------------------------------
        SET @start_time = GETDATE();
        PRINT '>> Truncating: gold.DimCustomer';
        TRUNCATE TABLE gold.DimCustomer;
        PRINT '>> Loading:    gold.DimCustomer';
        INSERT INTO gold.DimCustomer (
            customer_id, first_name, last_name, gender, date_of_birth, age,
            email, employment_status, annual_income, city, postcode, customer_since
        )
        SELECT
            customer_id, first_name, last_name, gender, date_of_birth,
            CASE WHEN date_of_birth IS NOT NULL
                 THEN DATEDIFF(YEAR, date_of_birth, GETDATE())
                      - CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, date_of_birth, GETDATE()), date_of_birth) > GETDATE()
                             THEN 1 ELSE 0 END
                 ELSE NULL END,
            email, employment_status, annual_income, city, postcode, customer_since
        FROM silver.customers;
        PRINT '>> Duration: ' + CAST(DATEDIFF(SECOND, @start_time, GETDATE()) AS NVARCHAR) + ' sec';

        -- DimBranch ----------------------------------------------------------
        SET @start_time = GETDATE();
        PRINT '>> Truncating: gold.DimBranch';
        TRUNCATE TABLE gold.DimBranch;
        PRINT '>> Loading:    gold.DimBranch';
        INSERT INTO gold.DimBranch (branch_id, branch_name, city, region, opening_date)
        SELECT branch_id, branch_name, city, region, opening_date
        FROM silver.branches;
        PRINT '>> Duration: ' + CAST(DATEDIFF(SECOND, @start_time, GETDATE()) AS NVARCHAR) + ' sec';

        -- DimAccount --------------------------------------------------------
        SET @start_time = GETDATE();
        PRINT '>> Truncating: gold.DimAccount';
        TRUNCATE TABLE gold.DimAccount;
        PRINT '>> Loading:    gold.DimAccount';
        INSERT INTO gold.DimAccount (account_id, CustomerKey, account_type, BranchKey, account_status, open_date)
        SELECT
            a.account_id, c.CustomerKey, a.account_type, b.BranchKey, a.account_status, a.open_date
        FROM silver.accounts a
        LEFT JOIN gold.DimCustomer c ON c.customer_id = a.customer_id
        LEFT JOIN gold.DimBranch b ON b.branch_id = a.branch_id;
        PRINT '>> Duration: ' + CAST(DATEDIFF(SECOND, @start_time, GETDATE()) AS NVARCHAR) + ' sec';

        -- DimLoan --------------------------------------------------------
        SET @start_time = GETDATE();
        PRINT '>> Truncating: gold.DimLoan';
        TRUNCATE TABLE gold.DimLoan;
        PRINT '>> Loading:    gold.DimLoan';
        INSERT INTO gold.DimLoan (loan_id, loan_type, loan_status, interest_rate, loan_start_date, loan_end_date)
        SELECT
            loan_id, loan_type, loan_status,
            CASE WHEN is_interest_rate_valid = 1 THEN interest_rate ELSE NULL END,
            loan_start_date, loan_end_date
        FROM silver.loans;
        PRINT '>> Duration: ' + CAST(DATEDIFF(SECOND, @start_time, GETDATE()) AS NVARCHAR) + ' sec';

        -- FactTransactions (clean rows only) ---------------------------------
        SET @start_time = GETDATE();
        PRINT '>> Truncating: gold.FactTransactions';
        TRUNCATE TABLE gold.FactTransactions;
        PRINT '>> Loading:    gold.FactTransactions';
        INSERT INTO gold.FactTransactions (
            transaction_id, CustomerKey, AccountKey, DateKey, Amount,
            TransactionType, MerchantName, TransactionChannel
        )
        SELECT
            t.transaction_id, acc.CustomerKey, acc.AccountKey,
            CONVERT(INT, FORMAT(t.transaction_date, 'yyyyMMdd')),
            t.amount, t.transaction_type, t.merchant_name, t.transaction_channel
        FROM silver.transactions t
        JOIN gold.DimAccount acc ON acc.account_id = t.account_id
        WHERE t.is_valid_account = 1 AND t.transaction_date IS NOT NULL;
        PRINT '>> Duration: ' + CAST(DATEDIFF(SECOND, @start_time, GETDATE()) AS NVARCHAR) + ' sec';

        -- FactLoans ------------------------------------------------------
        SET @start_time = GETDATE();
        PRINT '>> Truncating: gold.FactLoans';
        TRUNCATE TABLE gold.FactLoans;
        PRINT '>> Loading:    gold.FactLoans';
        INSERT INTO gold.FactLoans (LoanKey, CustomerKey, DateKey, LoanAmount)
        SELECT
            dl.LoanKey, c.CustomerKey,
            CONVERT(INT, FORMAT(l.loan_start_date, 'yyyyMMdd')),
            l.loan_amount
        FROM silver.loans l
        JOIN gold.DimLoan dl ON dl.loan_id = l.loan_id
        LEFT JOIN gold.DimCustomer c ON c.customer_id = l.customer_id
        WHERE l.loan_start_date IS NOT NULL;
        PRINT '>> Duration: ' + CAST(DATEDIFF(SECOND, @start_time, GETDATE()) AS NVARCHAR) + ' sec';

        -- FactComplaints --------------------------------------------------
        SET @start_time = GETDATE();
        PRINT '>> Truncating: gold.FactComplaints';
        TRUNCATE TABLE gold.FactComplaints;
        PRINT '>> Loading:    gold.FactComplaints';
        INSERT INTO gold.FactComplaints (
            CustomerKey, BranchKey, DateKey, ComplaintCategory, ComplaintStatus, ResolutionDays
        )
        SELECT
            c.CustomerKey, b.BranchKey,
            CONVERT(INT, FORMAT(cp.complaint_date, 'yyyyMMdd')),
            cp.complaint_category, cp.complaint_status,
            CASE WHEN cp.is_resolution_days_valid = 1 THEN cp.resolution_days ELSE NULL END
        FROM silver.complaints cp
        LEFT JOIN gold.DimCustomer c ON c.customer_id = cp.customer_id
        LEFT JOIN gold.DimBranch b ON b.branch_id = cp.branch_id
        WHERE cp.complaint_date IS NOT NULL;
        PRINT '>> Duration: ' + CAST(DATEDIFF(SECOND, @start_time, GETDATE()) AS NVARCHAR) + ' sec';

        PRINT '===============================================';
        PRINT 'Gold Layer Load Complete. Total duration: '
              + CAST(DATEDIFF(SECOND, @batch_start, GETDATE()) AS NVARCHAR) + ' sec';
        PRINT '===============================================';
    END TRY
    BEGIN CATCH
        PRINT '===============================================';
        PRINT 'ERROR OCCURRED DURING GOLD LAYER LOAD';
        PRINT 'Error Message: ' + ERROR_MESSAGE();
        PRINT 'Error Number:  ' + CAST(ERROR_NUMBER() AS NVARCHAR);
        PRINT '===============================================';
    END CATCH
END
GO
