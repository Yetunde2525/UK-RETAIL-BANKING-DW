/*
===============================================================================
Pipeline Tests
===============================================================================
Script Purpose:
    Automated PASS/FAIL assertions for the ETL pipeline — distinct from
    scripts/checks/08_data_quality_checks.sql, which reports descriptive
    counts for humans to read. This script is meant to be run after every
    reload (or wired into a CI job / scheduled task): it prints PASS or FAIL
    for each check, and RAISERRORs at the end if anything failed, so an
    automated caller gets a non-zero exit code.

    Run this after bronze.load_bronze, silver.load_silver, and
    gold.load_gold have all completed successfully.

Usage:
    sqlcmd -S <server> -d UKRetailBankingDW -i tests\pipeline_tests.sql -b
===============================================================================
*/

USE UKRetailBankingDW;
GO

SET NOCOUNT ON;
DECLARE @failures INT = 0;
DECLARE @total INT = 0;

-- TEST 1: no duplicate customer_id survived dedup into silver --------------
SET @total += 1;
IF EXISTS (SELECT customer_id FROM silver.customers GROUP BY customer_id HAVING COUNT(*) > 1)
BEGIN
    PRINT 'FAIL (1): duplicate customer_id found in silver.customers';
    SET @failures += 1;
END ELSE PRINT 'PASS (1): silver.customers has no duplicate customer_id';

-- TEST 2: no duplicate account_id survived dedup into silver ---------------
SET @total += 1;
IF EXISTS (SELECT account_id FROM silver.accounts GROUP BY account_id HAVING COUNT(*) > 1)
BEGIN
    PRINT 'FAIL (2): duplicate account_id found in silver.accounts';
    SET @failures += 1;
END ELSE PRINT 'PASS (2): silver.accounts has no duplicate account_id';

-- TEST 3: no duplicate transaction_id survived dedup into silver -----------
SET @total += 1;
IF EXISTS (SELECT transaction_id FROM silver.transactions GROUP BY transaction_id HAVING COUNT(*) > 1)
BEGIN
    PRINT 'FAIL (3): duplicate transaction_id found in silver.transactions';
    SET @failures += 1;
END ELSE PRINT 'PASS (3): silver.transactions has no duplicate transaction_id';

-- TEST 4: dedup can only shrink row counts, never grow them ----------------
SET @total += 1;
IF (SELECT COUNT(*) FROM silver.customers) > (SELECT COUNT(*) FROM bronze.customers)
BEGIN
    PRINT 'FAIL (4): silver.customers has MORE rows than bronze.customers';
    SET @failures += 1;
END ELSE PRINT 'PASS (4): silver.customers row count <= bronze.customers row count';

-- TEST 5: every FactTransactions.CustomerKey exists in DimCustomer ---------
SET @total += 1;
IF EXISTS (
    SELECT 1 FROM gold.FactTransactions ft
    LEFT JOIN gold.DimCustomer c ON c.CustomerKey = ft.CustomerKey
    WHERE ft.CustomerKey IS NOT NULL AND c.CustomerKey IS NULL
)
BEGIN
    PRINT 'FAIL (5): FactTransactions has orphan CustomerKey values';
    SET @failures += 1;
END ELSE PRINT 'PASS (5): FactTransactions.CustomerKey is fully covered by DimCustomer';

-- TEST 6: every FactTransactions.AccountKey exists in DimAccount -----------
SET @total += 1;
IF EXISTS (
    SELECT 1 FROM gold.FactTransactions ft
    LEFT JOIN gold.DimAccount a ON a.AccountKey = ft.AccountKey
    WHERE ft.AccountKey IS NOT NULL AND a.AccountKey IS NULL
)
BEGIN
    PRINT 'FAIL (6): FactTransactions has orphan AccountKey values';
    SET @failures += 1;
END ELSE PRINT 'PASS (6): FactTransactions.AccountKey is fully covered by DimAccount';

-- TEST 7: every FactComplaints.BranchKey (where present) exists in DimBranch
SET @total += 1;
IF EXISTS (
    SELECT 1 FROM gold.FactComplaints fc
    LEFT JOIN gold.DimBranch b ON b.BranchKey = fc.BranchKey
    WHERE fc.BranchKey IS NOT NULL AND b.BranchKey IS NULL
)
BEGIN
    PRINT 'FAIL (7): FactComplaints has orphan BranchKey values';
    SET @failures += 1;
END ELSE PRINT 'PASS (7): FactComplaints.BranchKey is fully covered by DimBranch';

-- TEST 8: DimLoan.interest_rate is always within 0-100 or NULL -------------
SET @total += 1;
IF EXISTS (SELECT 1 FROM gold.DimLoan WHERE interest_rate NOT BETWEEN 0 AND 100)
BEGIN
    PRINT 'FAIL (8): DimLoan has an interest_rate outside 0-100';
    SET @failures += 1;
END ELSE PRINT 'PASS (8): all DimLoan.interest_rate values are within 0-100 (or NULL)';

-- TEST 9: FactComplaints.ResolutionDays is never negative ------------------
SET @total += 1;
IF EXISTS (SELECT 1 FROM gold.FactComplaints WHERE ResolutionDays < 0)
BEGIN
    PRINT 'FAIL (9): FactComplaints has a negative ResolutionDays value';
    SET @failures += 1;
END ELSE PRINT 'PASS (9): no negative ResolutionDays values in FactComplaints';

-- TEST 10: all four gold views return at least one row ----------------------
SET @total += 1;
IF (SELECT COUNT(*) FROM gold.vw_customer_summary) = 0
   OR (SELECT COUNT(*) FROM gold.vw_branch_performance) = 0
   OR (SELECT COUNT(*) FROM gold.vw_loan_performance) = 0
   OR (SELECT COUNT(*) FROM gold.vw_complaint_analysis) = 0
BEGIN
    PRINT 'FAIL (10): one or more gold views returned zero rows';
    SET @failures += 1;
END ELSE PRINT 'PASS (10): all four gold views return data';

-- Summary -------------------------------------------------------------------
PRINT '===============================================';
PRINT CAST((@total - @failures) AS NVARCHAR) + ' / ' + CAST(@total AS NVARCHAR) + ' tests passed';
PRINT '===============================================';

IF @failures > 0
BEGIN
    RAISERROR('Pipeline tests failed: %d of %d checks did not pass. See PASS/FAIL lines above.', 16, 1, @failures, @total);
END
GO
