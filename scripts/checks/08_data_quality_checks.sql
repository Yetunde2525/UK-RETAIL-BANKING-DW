/*
===============================================================================
Data Quality Checks
===============================================================================
Script Purpose:
    Informational SELECTs only — nothing here modifies data, so this script
    is safe to run repeatedly at any point after silver.load_silver and
    gold.load_gold have run. Use it to sanity-check the pipeline and to
    quote real numbers in your README / project write-up.
===============================================================================
*/

USE UKRetailBankingDW;
GO

-- 1. Duplicate customer_id count in bronze (before dedup) -------------------
SELECT
    COUNT(*) - COUNT(DISTINCT customer_id) AS duplicate_customer_rows
FROM bronze.customers;
GO

-- 2. Missing / blank email count (post-clean, in silver) ---------------------
SELECT
    COUNT(*) AS total_customers,
    SUM(CASE WHEN email IS NULL THEN 1 ELSE 0 END) AS missing_email_count,
    SUM(CASE WHEN is_email_valid = 0 THEN 1 ELSE 0 END) AS invalid_email_count
FROM silver.customers;
GO

-- 3. Invalid transaction count (no matching account, or unparseable date) ---
SELECT
    COUNT(*) AS total_transactions,
    SUM(CASE WHEN is_valid_account = 0 THEN 1 ELSE 0 END) AS invalid_account_ref_count,
    SUM(CASE WHEN transaction_date IS NULL THEN 1 ELSE 0 END) AS unparseable_date_count,
    SUM(CASE WHEN amount IS NULL THEN 1 ELSE 0 END) AS non_numeric_amount_count
FROM silver.transactions;
GO

-- 4. Account reconciliation: bronze row count vs silver row count -----------
SELECT
    (SELECT COUNT(*) FROM bronze.accounts) AS bronze_account_rows,
    (SELECT COUNT(*) FROM silver.accounts) AS silver_account_rows,
    (SELECT COUNT(*) FROM bronze.accounts) - (SELECT COUNT(*) FROM silver.accounts)
        AS rows_removed_as_duplicates;
GO

-- 5. Orphan accounts: accounts referencing a customer_id that doesn't exist -
SELECT COUNT(*) AS orphan_account_count
FROM silver.accounts a
LEFT JOIN silver.customers c ON c.customer_id = a.customer_id
WHERE c.customer_id IS NULL;
GO

-- 6. Loans with an impossible interest rate (outside 0-100%) ---------------
SELECT COUNT(*) AS invalid_interest_rate_count
FROM silver.loans
WHERE is_interest_rate_valid = 0;
GO

-- 7. Complaints with a negative resolution_days (data entry errors) ---------
SELECT COUNT(*) AS negative_resolution_days_count
FROM silver.complaints
WHERE is_resolution_days_valid = 0;
GO

-- 8. Row-count parity check across the whole pipeline (bronze -> silver -> gold)
SELECT 'customers'    AS entity, (SELECT COUNT(*) FROM bronze.customers)    AS bronze_rows, (SELECT COUNT(*) FROM silver.customers)    AS silver_rows, (SELECT COUNT(*) FROM gold.DimCustomer)      AS gold_rows
UNION ALL
SELECT 'accounts',        (SELECT COUNT(*) FROM bronze.accounts),     (SELECT COUNT(*) FROM silver.accounts),     (SELECT COUNT(*) FROM gold.DimAccount)
UNION ALL
SELECT 'transactions',    (SELECT COUNT(*) FROM bronze.transactions), (SELECT COUNT(*) FROM silver.transactions), (SELECT COUNT(*) FROM gold.FactTransactions)
UNION ALL
SELECT 'loans',           (SELECT COUNT(*) FROM bronze.loans),        (SELECT COUNT(*) FROM silver.loans),        (SELECT COUNT(*) FROM gold.FactLoans)
UNION ALL
SELECT 'complaints',      (SELECT COUNT(*) FROM bronze.complaints),   (SELECT COUNT(*) FROM silver.complaints),   (SELECT COUNT(*) FROM gold.FactComplaints)
UNION ALL
SELECT 'branches',        (SELECT COUNT(*) FROM bronze.branches),     (SELECT COUNT(*) FROM silver.branches),     (SELECT COUNT(*) FROM gold.DimBranch);
GO
