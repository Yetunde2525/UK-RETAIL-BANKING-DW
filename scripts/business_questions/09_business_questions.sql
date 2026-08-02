/*
===============================================================================
Business Questions — 20 Queries Against the Gold Layer
===============================================================================
Script Purpose:
    Answers the 20 business questions from the project brief, grouped into
    Customer, Transaction, Loan, and Complaint analytics. Every query runs
    against the gold star schema (facts/dims) or the reporting views.

    A few questions require an assumption because the brief doesn't pin down
    an exact definition (e.g. "active customer", "churn", "approval rate").
    Each assumption is stated in a comment directly above the query so it's
    easy to change if your definition differs.
===============================================================================
*/

USE UKRetailBankingDW;
GO

-- ============================================================================
-- CUSTOMER ANALYTICS
-- ============================================================================

-- Q1: How many active customers does the bank have?
-- Assumption: "active" = has at least one account with account_status = 'Active'
SELECT COUNT(DISTINCT a.CustomerKey) AS active_customers
FROM gold.DimAccount a
WHERE a.account_status = 'Active';
GO

-- Q2: Which age group generates the highest transaction volume?
SELECT
    CASE
        WHEN c.age < 25 THEN 'Under 25'
        WHEN c.age BETWEEN 25 AND 34 THEN '25-34'
        WHEN c.age BETWEEN 35 AND 44 THEN '35-44'
        WHEN c.age BETWEEN 45 AND 54 THEN '45-54'
        WHEN c.age BETWEEN 55 AND 64 THEN '55-64'
        WHEN c.age >= 65 THEN '65+'
        ELSE 'Unknown'
    END AS age_group,
    COUNT(ft.TransactionKey) AS transaction_count,
    SUM(ft.Amount)           AS total_transaction_amount
FROM gold.FactTransactions ft
JOIN gold.DimCustomer c ON c.CustomerKey = ft.CustomerKey
GROUP BY
    CASE
        WHEN c.age < 25 THEN 'Under 25'
        WHEN c.age BETWEEN 25 AND 34 THEN '25-34'
        WHEN c.age BETWEEN 35 AND 44 THEN '35-44'
        WHEN c.age BETWEEN 45 AND 54 THEN '45-54'
        WHEN c.age BETWEEN 55 AND 64 THEN '55-64'
        WHEN c.age >= 65 THEN '65+'
        ELSE 'Unknown'
    END
ORDER BY transaction_count DESC;
GO

-- Q3: Which customer segment holds the highest account balances?
-- Assumption: "segment" = employment_status
SELECT
    c.employment_status,
    COUNT(DISTINCT a.AccountKey) AS total_accounts,
    SUM(sa.current_balance)      AS total_balance
FROM gold.DimCustomer c
JOIN gold.DimAccount a ON a.CustomerKey = c.CustomerKey
JOIN silver.accounts sa ON sa.account_id = a.account_id
GROUP BY c.employment_status
ORDER BY total_balance DESC;
GO

-- Q4: What is the customer retention rate?
-- Assumption: "retained" = customer_since more than 12 months ago AND still
-- has at least one Active account
SELECT
    CAST(SUM(CASE WHEN c.customer_since <= DATEADD(YEAR, -1, GETDATE())
                   AND a.account_status = 'Active' THEN 1 ELSE 0 END) AS FLOAT)
        / NULLIF(COUNT(DISTINCT c.CustomerKey), 0) AS retention_rate
FROM gold.DimCustomer c
LEFT JOIN gold.DimAccount a ON a.CustomerKey = c.CustomerKey;
GO

-- Q5: Which customers are at risk of churn?
-- Assumption: "at risk" = no transaction in the 6 months prior to the most
-- recent transaction date in the dataset (rather than GETDATE(), since this
-- is historical/synthetic data)
;WITH ref_date AS (
    SELECT MAX(dd.FullDate) AS max_date FROM gold.FactTransactions ft
    JOIN gold.DimDate dd ON dd.DateKey = ft.DateKey
),
last_activity AS (
    SELECT ft.CustomerKey, MAX(dd.FullDate) AS last_transaction_date
    FROM gold.FactTransactions ft
    JOIN gold.DimDate dd ON dd.DateKey = ft.DateKey
    GROUP BY ft.CustomerKey
)
SELECT c.CustomerKey, c.customer_id, c.first_name, c.last_name, la.last_transaction_date
FROM gold.DimCustomer c
JOIN last_activity la ON la.CustomerKey = c.CustomerKey
CROSS JOIN ref_date r
WHERE la.last_transaction_date < DATEADD(MONTH, -6, r.max_date)
ORDER BY la.last_transaction_date ASC;
GO

-- ============================================================================
-- TRANSACTION ANALYTICS
-- ============================================================================

-- Q6: Which branches process the highest transaction volume?
SELECT branch_name, region, total_transactions, total_transaction_amount
FROM gold.vw_branch_performance
ORDER BY total_transactions DESC;
GO

-- Q7: What are the monthly transaction trends?
SELECT
    dd.[Year], dd.[Month], dd.MonthName,
    COUNT(ft.TransactionKey) AS transaction_count,
    SUM(ft.Amount)           AS total_amount
FROM gold.FactTransactions ft
JOIN gold.DimDate dd ON dd.DateKey = ft.DateKey
GROUP BY dd.[Year], dd.[Month], dd.MonthName
ORDER BY dd.[Year], dd.[Month];
GO

-- Q8: Which transaction channels are most used?
SELECT TransactionChannel, COUNT(*) AS transaction_count, SUM(Amount) AS total_amount
FROM gold.FactTransactions
GROUP BY TransactionChannel
ORDER BY transaction_count DESC;
GO

-- Q9: What is the average transaction value by region?
SELECT b.region, AVG(ft.Amount) AS avg_transaction_value, COUNT(*) AS transaction_count
FROM gold.FactTransactions ft
JOIN gold.DimAccount a ON a.AccountKey = ft.AccountKey
JOIN gold.DimBranch b ON b.BranchKey = a.BranchKey
GROUP BY b.region
ORDER BY avg_transaction_value DESC;
GO

-- Q10: Which merchants receive the highest transaction amounts?
SELECT TOP 20 MerchantName, COUNT(*) AS transaction_count, SUM(Amount) AS total_amount
FROM gold.FactTransactions
WHERE MerchantName IS NOT NULL AND MerchantName <> ''
GROUP BY MerchantName
ORDER BY total_amount DESC;
GO

-- ============================================================================
-- LOAN ANALYTICS
-- ============================================================================

-- Q11: Which loan products generate the highest revenue?
-- Assumption: "revenue" is approximated as loan_amount * interest_rate / 100
-- (annualized interest income proxy — not a full amortization calculation)
SELECT
    dl.loan_type,
    SUM(fl.LoanAmount * dl.interest_rate / 100.0) AS estimated_annual_interest_revenue,
    COUNT(*) AS loan_count
FROM gold.DimLoan dl
JOIN gold.FactLoans fl ON fl.LoanKey = dl.LoanKey
WHERE dl.interest_rate IS NOT NULL
GROUP BY dl.loan_type
ORDER BY estimated_annual_interest_revenue DESC;
GO

-- Q12: What is the average loan size?
SELECT AVG(LoanAmount) AS overall_avg_loan_size
FROM gold.FactLoans;
GO
-- ...and broken out by loan type:
SELECT loan_type, AVG(fl.LoanAmount) AS avg_loan_amount
FROM gold.DimLoan dl
JOIN gold.FactLoans fl ON fl.LoanKey = dl.LoanKey
GROUP BY loan_type
ORDER BY avg_loan_amount DESC;
GO

-- Q13: Which regions have the highest loan uptake?
-- Assumption: a loan is attributed to the region of the customer's
-- first/lowest-key account, since loans aren't tied to a branch directly
;WITH customer_region AS (
    SELECT a.CustomerKey, MIN(b.region) AS region
    FROM gold.DimAccount a
    JOIN gold.DimBranch b ON b.BranchKey = a.BranchKey
    GROUP BY a.CustomerKey
)
SELECT cr.region, COUNT(*) AS loan_count, SUM(fl.LoanAmount) AS total_loan_amount
FROM gold.FactLoans fl
JOIN customer_region cr ON cr.CustomerKey = fl.CustomerKey
GROUP BY cr.region
ORDER BY loan_count DESC;
GO

-- Q14: What is the loan approval rate?
-- Assumption: check which loan_status values actually exist in your data
-- first (run the SELECT DISTINCT below), then treat any "Rejected"/"Declined"
-- style status as not approved. As loaded, this dataset's statuses are
-- Active/Paid Off/Defaulted — i.e. every row already represents an approved
-- loan, so this query reports the status mix rather than a true approval rate.
SELECT DISTINCT loan_status FROM silver.loans;
GO
SELECT
    loan_status,
    COUNT(*) AS loan_count,
    CAST(COUNT(*) AS FLOAT) / SUM(COUNT(*)) OVER () AS pct_of_total
FROM silver.loans
GROUP BY loan_status;
GO

-- Q15: What is the default rate by loan type?
SELECT loan_type, total_loans, defaulted_count, default_rate
FROM gold.vw_loan_performance
ORDER BY default_rate DESC;
GO

-- ============================================================================
-- COMPLAINT ANALYTICS
-- ============================================================================

-- Q16: Which branches receive the most complaints?
SELECT branch_name, region, COUNT(*) AS complaint_count
FROM gold.FactComplaints fc
JOIN gold.DimBranch b ON b.BranchKey = fc.BranchKey
GROUP BY branch_name, region
ORDER BY complaint_count DESC;
GO

-- Q17: What are the most common complaint categories?
SELECT ComplaintCategory, COUNT(*) AS complaint_count
FROM gold.FactComplaints
GROUP BY ComplaintCategory
ORDER BY complaint_count DESC;
GO

-- Q18: What is the average resolution time?
SELECT AVG(CAST(ResolutionDays AS FLOAT)) AS avg_resolution_days
FROM gold.FactComplaints
WHERE ResolutionDays IS NOT NULL;
GO
-- ...and broken out by category:
SELECT ComplaintCategory, AVG(CAST(ResolutionDays AS FLOAT)) AS avg_resolution_days
FROM gold.FactComplaints
WHERE ResolutionDays IS NOT NULL
GROUP BY ComplaintCategory
ORDER BY avg_resolution_days DESC;
GO

-- Q19: Which regions have the highest complaint rates?
-- Assumption: rate = complaints per customer with an account in that region
;WITH region_customers AS (
    SELECT b.region, COUNT(DISTINCT a.CustomerKey) AS customer_count
    FROM gold.DimAccount a
    JOIN gold.DimBranch b ON b.BranchKey = a.BranchKey
    GROUP BY b.region
),
region_complaints AS (
    SELECT b.region, COUNT(*) AS complaint_count
    FROM gold.FactComplaints fc
    JOIN gold.DimBranch b ON b.BranchKey = fc.BranchKey
    GROUP BY b.region
)
SELECT
    rc.region,
    rc.complaint_count,
    reg.customer_count,
    CAST(rc.complaint_count AS FLOAT) / NULLIF(reg.customer_count, 0) AS complaints_per_customer
FROM region_complaints rc
JOIN region_customers reg ON reg.region = rc.region
ORDER BY complaints_per_customer DESC;
GO

-- Q20: Is there a relationship between complaints and customer churn?
-- Assumption: "churn" reuses the Q5 definition (no transaction in the 6
-- months prior to the dataset's most recent transaction date). Compares
-- the churn rate of customers who have filed at least one complaint vs
-- those who haven't.
;WITH ref_date AS (
    SELECT MAX(dd.FullDate) AS max_date FROM gold.FactTransactions ft
    JOIN gold.DimDate dd ON dd.DateKey = ft.DateKey
),
last_activity AS (
    SELECT ft.CustomerKey, MAX(dd.FullDate) AS last_transaction_date
    FROM gold.FactTransactions ft
    JOIN gold.DimDate dd ON dd.DateKey = ft.DateKey
    GROUP BY ft.CustomerKey
),
churn_flag AS (
    SELECT c.CustomerKey,
        CASE WHEN la.last_transaction_date < DATEADD(MONTH, -6, r.max_date) OR la.last_transaction_date IS NULL
             THEN 1 ELSE 0 END AS is_churned
    FROM gold.DimCustomer c
    LEFT JOIN last_activity la ON la.CustomerKey = c.CustomerKey
    CROSS JOIN ref_date r
),
complaint_flag AS (
    SELECT DISTINCT CustomerKey FROM gold.FactComplaints WHERE CustomerKey IS NOT NULL
)
SELECT
    CASE WHEN cf.CustomerKey IS NOT NULL THEN 'Has complained' ELSE 'Never complained' END AS complaint_group,
    COUNT(*) AS customer_count,
    SUM(chf.is_churned) AS churned_count,
    CAST(SUM(chf.is_churned) AS FLOAT) / COUNT(*) AS churn_rate
FROM churn_flag chf
LEFT JOIN complaint_flag cf ON cf.CustomerKey = chf.CustomerKey
GROUP BY CASE WHEN cf.CustomerKey IS NOT NULL THEN 'Has complained' ELSE 'Never complained' END;
GO
