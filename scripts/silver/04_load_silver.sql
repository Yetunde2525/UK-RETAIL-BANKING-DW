/*
===============================================================================
Stored Procedure: silver.load_silver
===============================================================================
Script Purpose:
    Reads from the bronze tables, cleans and standardizes the data, and
    loads the result into the silver tables. Each table is truncated before
    reload, so this procedure can be re-run safely.

    Cleaning performed per entity:

    Customers
      - Remove duplicate customer_id (keeps the first occurrence)
      - Standardize first/last name to title case
      - Parse date_of_birth and customer_since from mixed date formats
      - Validate email format, flag invalid/missing emails rather than
        dropping the row
      - Standardize city casing
      - Cast annual_income to a proper decimal, NULL if not numeric

    Accounts
      - Cast current_balance to decimal
      - Parse open_date from mixed formats

    Transactions
      - Remove duplicate transaction_id
      - Standardize transaction_type (Wdrl/Withdrawal/wdrl -> "Withdrawal", etc.)
      - Cast amount to decimal
      - Flag transactions whose account_id has no matching silver.accounts row
        (is_valid_account = 0) instead of silently dropping them

    Loans
      - Standardize loan_type casing
      - Flag interest rates outside a sane 0-100% range as invalid
      - Parse loan_start_date / loan_end_date

    Complaints
      - Flag negative resolution_days as invalid rather than deleting them
      - Default missing/blank complaint_category to 'Uncategorized'

WARNING:
    This procedure TRUNCATEs every silver table before reloading it. Run
    03_ddl_silver.sql first, and bronze.load_bronze before this.

Usage:
    EXEC silver.load_silver;
===============================================================================
*/

USE UKRetailBankingDW;
GO

CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @start_time DATETIME, @batch_start DATETIME;

    BEGIN TRY
        SET @batch_start = GETDATE();
        PRINT '===============================================';
        PRINT 'Loading Silver Layer';
        PRINT '===============================================';

        -- branches (no dependencies) --------------------------------------
        SET @start_time = GETDATE();
        PRINT '>> Truncating: silver.branches';
        TRUNCATE TABLE silver.branches;
        PRINT '>> Loading:    silver.branches';

        ;WITH deduped AS (
            SELECT *, ROW_NUMBER() OVER (PARTITION BY branch_id ORDER BY (SELECT NULL)) AS rn
            FROM bronze.branches
        )
        INSERT INTO silver.branches (branch_id, branch_name, city, region, opening_date)
        SELECT
            LTRIM(RTRIM(branch_id)),
            LTRIM(RTRIM(branch_name)),
            UPPER(LTRIM(RTRIM(city))),
            LTRIM(RTRIM(region)),
            dbo.fn_ParseMessyDate(opening_date)
        FROM deduped
        WHERE rn = 1;
        PRINT '>> Duration: ' + CAST(DATEDIFF(SECOND, @start_time, GETDATE()) AS NVARCHAR) + ' sec';

        -- customers ---------------------------------------------------------
        SET @start_time = GETDATE();
        PRINT '>> Truncating: silver.customers';
        TRUNCATE TABLE silver.customers;
        PRINT '>> Loading:    silver.customers';

        ;WITH deduped AS (
            SELECT *, ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY (SELECT NULL)) AS rn
            FROM bronze.customers
        )
        INSERT INTO silver.customers (
            customer_id, first_name, last_name, gender, date_of_birth,
            email, is_email_valid, phone_number, address, city, postcode,
            customer_since, employment_status, annual_income
        )
        SELECT
            LTRIM(RTRIM(customer_id)),
            dbo.fn_ProperCase(first_name),
            dbo.fn_ProperCase(last_name),
            LTRIM(RTRIM(gender)),
            dbo.fn_ParseMessyDate(date_of_birth),
            NULLIF(LTRIM(RTRIM(email)), ''),
            CASE WHEN email LIKE '_%@_%._%' AND email NOT LIKE '% %' THEN 1 ELSE 0 END,
            LTRIM(RTRIM(phone_number)),
            LTRIM(RTRIM(address)),
            UPPER(LTRIM(RTRIM(city))),
            UPPER(REPLACE(LTRIM(RTRIM(postcode)), ' ', '')),
            dbo.fn_ParseMessyDate(customer_since),
            LTRIM(RTRIM(employment_status)),
            TRY_CONVERT(DECIMAL(18,2), annual_income)
        FROM deduped
        WHERE rn = 1;
        PRINT '>> Duration: ' + CAST(DATEDIFF(SECOND, @start_time, GETDATE()) AS NVARCHAR) + ' sec';

        -- accounts ------------------------------------------------------------
        SET @start_time = GETDATE();
        PRINT '>> Truncating: silver.accounts';
        TRUNCATE TABLE silver.accounts;
        PRINT '>> Loading:    silver.accounts';

        ;WITH deduped AS (
            SELECT *, ROW_NUMBER() OVER (PARTITION BY account_id ORDER BY (SELECT NULL)) AS rn
            FROM bronze.accounts
        )
        INSERT INTO silver.accounts (
            account_id, customer_id, account_type, branch_id,
            open_date, account_status, current_balance
        )
        SELECT
            LTRIM(RTRIM(account_id)),
            LTRIM(RTRIM(customer_id)),
            LTRIM(RTRIM(account_type)),
            LTRIM(RTRIM(branch_id)),
            dbo.fn_ParseMessyDate(open_date),
            LTRIM(RTRIM(account_status)),
            TRY_CONVERT(DECIMAL(18,2), current_balance)
        FROM deduped
        WHERE rn = 1;
        PRINT '>> Duration: ' + CAST(DATEDIFF(SECOND, @start_time, GETDATE()) AS NVARCHAR) + ' sec';

        -- transactions -----------------------------------------------------
        SET @start_time = GETDATE();
        PRINT '>> Truncating: silver.transactions';
        TRUNCATE TABLE silver.transactions;
        PRINT '>> Loading:    silver.transactions';

        ;WITH deduped AS (
            SELECT *, ROW_NUMBER() OVER (PARTITION BY transaction_id ORDER BY (SELECT NULL)) AS rn
            FROM bronze.transactions
        )
        INSERT INTO silver.transactions (
            transaction_id, account_id, transaction_date, transaction_type,
            amount, merchant_name, transaction_channel, is_valid_account
        )
        SELECT
            LTRIM(RTRIM(d.transaction_id)),
            LTRIM(RTRIM(d.account_id)),
            dbo.fn_ParseMessyDate(d.transaction_date),
            CASE UPPER(LTRIM(RTRIM(d.transaction_type)))
                WHEN 'WDRL'       THEN 'Withdrawal'
                WHEN 'WITHDRAWAL' THEN 'Withdrawal'
                WHEN 'DEP'        THEN 'Deposit'
                WHEN 'DEPOSIT'    THEN 'Deposit'
                WHEN 'DBT'        THEN 'Debit'
                WHEN 'DEBIT'      THEN 'Debit'
                WHEN 'CR'         THEN 'Credit'
                WHEN 'CREDIT'     THEN 'Credit'
                WHEN 'TRF'        THEN 'Transfer'
                WHEN 'TRANSFER'   THEN 'Transfer'
                ELSE dbo.fn_ProperCase(d.transaction_type)
            END,
            TRY_CONVERT(DECIMAL(18,2), d.amount),
            LTRIM(RTRIM(d.merchant_name)),
            LTRIM(RTRIM(d.transaction_channel)),
            CASE WHEN a.account_id IS NOT NULL THEN 1 ELSE 0 END
        FROM deduped d
        LEFT JOIN silver.accounts a ON a.account_id = LTRIM(RTRIM(d.account_id))
        WHERE d.rn = 1;
        PRINT '>> Duration: ' + CAST(DATEDIFF(SECOND, @start_time, GETDATE()) AS NVARCHAR) + ' sec';

        -- loans ----------------------------------------------------------
        SET @start_time = GETDATE();
        PRINT '>> Truncating: silver.loans';
        TRUNCATE TABLE silver.loans;
        PRINT '>> Loading:    silver.loans';

        ;WITH deduped AS (
            SELECT *, ROW_NUMBER() OVER (PARTITION BY loan_id ORDER BY (SELECT NULL)) AS rn
            FROM bronze.loans
        )
        INSERT INTO silver.loans (
            loan_id, customer_id, loan_type, loan_amount, interest_rate,
            is_interest_rate_valid, loan_start_date, loan_end_date, loan_status
        )
        SELECT
            LTRIM(RTRIM(loan_id)),
            LTRIM(RTRIM(customer_id)),
            dbo.fn_ProperCase(loan_type),
            TRY_CONVERT(DECIMAL(18,2), loan_amount),
            TRY_CONVERT(DECIMAL(5,2), interest_rate),
            CASE WHEN TRY_CONVERT(DECIMAL(5,2), interest_rate) BETWEEN 0 AND 100 THEN 1 ELSE 0 END,
            dbo.fn_ParseMessyDate(loan_start_date),
            dbo.fn_ParseMessyDate(loan_end_date),
            LTRIM(RTRIM(loan_status))
        FROM deduped
        WHERE rn = 1;
        PRINT '>> Duration: ' + CAST(DATEDIFF(SECOND, @start_time, GETDATE()) AS NVARCHAR) + ' sec';

        -- complaints --------------------------------------------------------
        SET @start_time = GETDATE();
        PRINT '>> Truncating: silver.complaints';
        TRUNCATE TABLE silver.complaints;
        PRINT '>> Loading:    silver.complaints';

        ;WITH deduped AS (
            SELECT *, ROW_NUMBER() OVER (PARTITION BY complaint_id ORDER BY (SELECT NULL)) AS rn
            FROM bronze.complaints
        )
        INSERT INTO silver.complaints (
            complaint_id, customer_id, complaint_date, complaint_category,
            complaint_status, resolution_days, is_resolution_days_valid, branch_id
        )
        SELECT
            LTRIM(RTRIM(complaint_id)),
            LTRIM(RTRIM(customer_id)),
            dbo.fn_ParseMessyDate(complaint_date),
            ISNULL(NULLIF(LTRIM(RTRIM(complaint_category)), ''), 'Uncategorized'),
            LTRIM(RTRIM(complaint_status)),
            TRY_CONVERT(INT, resolution_days),
            CASE WHEN TRY_CONVERT(INT, resolution_days) >= 0 THEN 1 ELSE 0 END,
            LTRIM(RTRIM(branch_id))
        FROM deduped
        WHERE rn = 1;
        PRINT '>> Duration: ' + CAST(DATEDIFF(SECOND, @start_time, GETDATE()) AS NVARCHAR) + ' sec';

        PRINT '===============================================';
        PRINT 'Silver Layer Load Complete. Total duration: '
              + CAST(DATEDIFF(SECOND, @batch_start, GETDATE()) AS NVARCHAR) + ' sec';
        PRINT '===============================================';
    END TRY
    BEGIN CATCH
        PRINT '===============================================';
        PRINT 'ERROR OCCURRED DURING SILVER LAYER LOAD';
        PRINT 'Error Message: ' + ERROR_MESSAGE();
        PRINT 'Error Number:  ' + CAST(ERROR_NUMBER() AS NVARCHAR);
        PRINT '===============================================';
    END CATCH
END
GO
