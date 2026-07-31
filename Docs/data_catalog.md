# Data Catalog

A column-level reference for every table in the warehouse, layer by layer.

---

## Bronze Layer — raw, as-loaded (all columns `NVARCHAR`, no transformation)

### bronze.customers
| Column | Source | Notes |
|---|---|---|
| customer_id | customers.csv | Natural key |
| first_name | customers.csv | |
| last_name | customers.csv | |
| gender | customers.csv | |
| date_of_birth | customers.csv | Mixed date formats as received |
| email | customers.csv | |
| phone_number | customers.csv | |
| address | customers.csv | |
| city | customers.csv | Inconsistent casing as received |
| postcode | customers.csv | |
| customer_since | customers.csv | Mixed date formats as received |
| employment_status | customers.csv | |
| annual_income | customers.csv | May contain non-numeric/invalid values |

### bronze.accounts
account_id, customer_id, account_type, branch_id, open_date, account_status, current_balance

### bronze.transactions
transaction_id, account_id, transaction_date, transaction_type, amount, merchant_name, transaction_channel

### bronze.loans
loan_id, customer_id, loan_type, loan_amount, interest_rate, loan_start_date, loan_end_date, loan_status

### bronze.complaints
complaint_id, customer_id, complaint_date, complaint_category, complaint_status, resolution_days, branch_id

### bronze.branches
branch_id, branch_name, city, region, opening_date

---

## Silver Layer — cleaned, standardized, validated

Every silver table keeps **all** rows from bronze (nothing is silently dropped). Instead, validity is tracked with `is_*` flag columns so bad rows can be filtered downstream rather than disappearing without a trace.

### silver.customers
| Column | Type | Transformation |
|---|---|---|
| customer_id | NVARCHAR(20) PK | Deduplicated (first occurrence kept) |
| first_name / last_name | NVARCHAR(50) | Title-cased via `dbo.fn_ProperCase` |
| gender | NVARCHAR(20) | Trimmed |
| date_of_birth | DATE | Parsed via `dbo.fn_ParseMessyDate` |
| email | NVARCHAR(100) | Trimmed |
| is_email_valid | BIT | Basic pattern check |
| phone_number, address | NVARCHAR | Trimmed |
| city | NVARCHAR(50) | Uppercased for consistency |
| postcode | NVARCHAR(20) | Uppercased, spaces removed |
| customer_since | DATE | Parsed via `dbo.fn_ParseMessyDate` |
| employment_status | NVARCHAR(50) | Trimmed |
| annual_income | DECIMAL(18,2) | Cast via `TRY_CONVERT`, NULL if non-numeric |

### silver.accounts
account_id (PK), customer_id, account_type, branch_id, open_date (parsed DATE), account_status, current_balance (DECIMAL)

### silver.transactions
| Column | Notes |
|---|---|
| transaction_id | PK, deduplicated |
| account_id | |
| transaction_date | Parsed DATE |
| transaction_type | Standardized (`Wdrl`/`WITHDRAWAL`/`wdrl` → `Withdrawal`, etc.) |
| amount | DECIMAL |
| merchant_name, transaction_channel | |
| is_valid_account | 1 if account_id matches a row in silver.accounts, else 0 |

### silver.loans
loan_id (PK), customer_id, loan_type (title-cased), loan_amount (DECIMAL), interest_rate (DECIMAL), **is_interest_rate_valid** (1 if 0–100%, else 0), loan_start_date / loan_end_date (parsed DATE), loan_status

### silver.complaints
complaint_id (PK), customer_id, complaint_date (parsed DATE), complaint_category (defaults to `'Uncategorized'` if blank), complaint_status, resolution_days, **is_resolution_days_valid** (1 if ≥ 0, else 0), branch_id

### silver.branches
branch_id (PK), branch_name, city (uppercased), region, opening_date (parsed DATE)

---

## Gold Layer — star schema for reporting

### Dimensions
| Table | Grain | Key columns |
|---|---|---|
| DimDate | One row per calendar day, 2000-01-01 to 2035-12-31 | DateKey (yyyyMMdd, PK) |
| DimCustomer | One row per customer | CustomerKey (PK), customer_id, **age** (computed from date_of_birth) |
| DimBranch | One row per branch | BranchKey (PK), branch_id |
| DimAccount | One row per account | AccountKey (PK), account_id, CustomerKey (FK), BranchKey (FK) |
| DimLoan | One row per loan | LoanKey (PK), loan_id, interest_rate (NULL if flagged invalid in silver) |

### Facts
| Table | Grain | Measures |
|---|---|---|
| FactTransactions | One row per valid transaction (excludes `is_valid_account = 0` rows) | Amount |
| FactLoans | One row per loan with a parseable start date | LoanAmount |
| FactComplaints | One row per complaint with a parseable date | ResolutionDays (NULL if flagged invalid) |

### Views (`gold.vw_*`)
| View | Purpose |
|---|---|
| vw_customer_summary | One row per customer — accounts, balances, transactions, loans, complaints |
| vw_branch_performance | One row per branch — volume, complaint load |
| vw_loan_performance | One row per loan type — volume, avg size, avg rate, default rate |
| vw_complaint_analysis | One row per branch/category — volume, avg resolution time, status mix |
