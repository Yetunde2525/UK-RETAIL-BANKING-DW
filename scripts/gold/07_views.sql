/*
===============================================================================
Views: Reporting Layer (on top of the Gold star schema)
===============================================================================
Script Purpose:
    Creates four business-facing views used for reporting and as the source
    for the Power BI dashboard. These sit on top of the gold star schema and
    should be refreshed (implicitly, since views aren't materialized) any
    time gold.load_gold has been re-run.

Views:
    gold.vw_customer_summary   - one row per customer: accounts, balances,
                                  transaction activity, loans, complaints
    gold.vw_branch_performance - one row per branch: account/transaction
                                  volume, complaint load, region
    gold.vw_loan_performance   - one row per loan type: volume, average size,
                                  average interest rate, status mix
    gold.vw_complaint_analysis - one row per branch/category: complaint
                                  volume, average resolution time, status mix
===============================================================================
*/

USE UKRetailBankingDW;
GO

-- ============================================================================
CREATE OR ALTER VIEW gold.vw_customer_summary AS
SELECT
    c.CustomerKey,
    c.customer_id,
    c.first_name,
    c.last_name,
    c.age,
    c.employment_status,
    c.annual_income,
    c.city,
    c.customer_since,
    COUNT(DISTINCT a.AccountKey)                       AS total_accounts,
    ISNULL(MAX(bal.current_balance_sum), 0)            AS total_balance,
    COUNT(DISTINCT ft.TransactionKey)                  AS total_transactions,
    ISNULL(SUM(ft.Amount), 0)                          AS total_transaction_amount,
    COUNT(DISTINCT fl.FactLoanKey)                     AS total_loans,
    ISNULL(SUM(fl.LoanAmount), 0)                      AS total_loan_amount,
    COUNT(DISTINCT fc.ComplaintKey)                    AS total_complaints
FROM gold.DimCustomer c
LEFT JOIN gold.DimAccount a ON a.CustomerKey = c.CustomerKey
LEFT JOIN (
    SELECT da.CustomerKey, SUM(sa.current_balance) AS current_balance_sum
    FROM gold.DimAccount da
    JOIN silver.accounts sa ON sa.account_id = da.account_id
    GROUP BY da.CustomerKey
) bal ON bal.CustomerKey = c.CustomerKey
LEFT JOIN gold.FactTransactions ft ON ft.CustomerKey = c.CustomerKey
LEFT JOIN gold.FactLoans fl ON fl.CustomerKey = c.CustomerKey
LEFT JOIN gold.FactComplaints fc ON fc.CustomerKey = c.CustomerKey
GROUP BY
    c.CustomerKey, c.customer_id, c.first_name, c.last_name, c.age,
    c.employment_status, c.annual_income, c.city, c.customer_since;
GO

-- ============================================================================
CREATE OR ALTER VIEW gold.vw_branch_performance AS
SELECT
    b.BranchKey,
    b.branch_id,
    b.branch_name,
    b.city,
    b.region,
    COUNT(DISTINCT a.AccountKey)      AS total_accounts,
    COUNT(DISTINCT ft.TransactionKey) AS total_transactions,
    ISNULL(SUM(ft.Amount), 0)         AS total_transaction_amount,
    COUNT(DISTINCT fc.ComplaintKey)   AS total_complaints,
    AVG(CAST(fc.ResolutionDays AS FLOAT)) AS avg_resolution_days
FROM gold.DimBranch b
LEFT JOIN gold.DimAccount a ON a.BranchKey = b.BranchKey
LEFT JOIN gold.FactTransactions ft ON ft.AccountKey = a.AccountKey
LEFT JOIN gold.FactComplaints fc ON fc.BranchKey = b.BranchKey
GROUP BY b.BranchKey, b.branch_id, b.branch_name, b.city, b.region;
GO

-- ============================================================================
CREATE OR ALTER VIEW gold.vw_loan_performance AS
SELECT
    dl.loan_type,
    COUNT(*)                                              AS total_loans,
    AVG(fl.LoanAmount)                                     AS avg_loan_amount,
    AVG(dl.interest_rate)                                  AS avg_interest_rate,
    SUM(CASE WHEN dl.loan_status = 'Active'   THEN 1 ELSE 0 END) AS active_count,
    SUM(CASE WHEN dl.loan_status = 'Paid Off' THEN 1 ELSE 0 END) AS paid_off_count,
    SUM(CASE WHEN dl.loan_status = 'Defaulted' THEN 1 ELSE 0 END) AS defaulted_count,
    CAST(SUM(CASE WHEN dl.loan_status = 'Defaulted' THEN 1 ELSE 0 END) AS FLOAT)
        / NULLIF(COUNT(*), 0) AS default_rate
FROM gold.DimLoan dl
JOIN gold.FactLoans fl ON fl.LoanKey = dl.LoanKey
GROUP BY dl.loan_type;
GO

-- ============================================================================
CREATE OR ALTER VIEW gold.vw_complaint_analysis AS
SELECT
    b.region,
    b.branch_name,
    fc.ComplaintCategory,
    COUNT(*)                              AS total_complaints,
    AVG(CAST(fc.ResolutionDays AS FLOAT)) AS avg_resolution_days,
    SUM(CASE WHEN fc.ComplaintStatus = 'Open'       THEN 1 ELSE 0 END) AS open_count,
    SUM(CASE WHEN fc.ComplaintStatus = 'Escalated'  THEN 1 ELSE 0 END) AS escalated_count,
    SUM(CASE WHEN fc.ComplaintStatus = 'Resolved'   THEN 1 ELSE 0 END) AS resolved_count
FROM gold.FactComplaints fc
LEFT JOIN gold.DimBranch b ON b.BranchKey = fc.BranchKey
GROUP BY b.region, b.branch_name, fc.ComplaintCategory;
GO
