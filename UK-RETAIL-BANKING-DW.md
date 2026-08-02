# UK-RETAIL-BANKING-DW — Project Log

A record of the process, steps, and actions taken to build this project, kept alongside the code for anyone reviewing the repo.

## Project Overview

A SQL Server data warehouse portfolio project simulating a UK retail bank that has inconsistent reporting, duplicated customer records, and KPIs that vary by department. Built using **Medallion Architecture** (Bronze -> Silver -> Gold layers) across five simulated source systems (Core Banking, CRM, Loan Management, Complaint Portal, Branch Operations).

## Architecture

- **Bronze Layer** — 6 raw tables (customers, accounts, transactions, loans, complaints, branches), all columns `NVARCHAR` so a load never fails on messy source data
- **Silver Layer** — cleaned, deduplicated, standardized (mixed date formats parsed, casing normalized, numeric fields cast) with `is_*` validity flags rather than deleting bad rows
- **Gold Layer** — star schema (DimCustomer, DimAccount, DimBranch, DimLoan, DimDate + FactTransactions, FactLoans, FactComplaints) plus 4 reporting views for Power BI

Full detail in `docs/data_architecture.md`.

## Build Log

1. `00_init_database.sql` — creates the `UKRetailBankingDW` database and bronze/silver/gold schemas
2. **Bronze layer** — `01_ddl_bronze.sql` (raw table DDL) + `02_load_bronze.sql` (`bronze.load_bronze` stored procedure, BULK INSERT from the 6 CSVs)
3. **Silver layer** — `03_ddl_silver.sql` (cleaned table DDL + `fn_ParseMessyDate` / `fn_ProperCase` helper functions) + `04_load_silver.sql` (`silver.load_silver` — dedup via `ROW_NUMBER()`, date parsing, casing standardization, validity flags)
4. **Gold layer** — `05_ddl_gold.sql` (star schema) + `06_load_gold.sql` (`gold.load_gold` — builds DimDate, loads all dims/facts) + `07_views.sql` (4 reporting views)
5. **Data quality checks** — `08_data_quality_checks.sql`: descriptive counts (duplicates, missing emails, invalid transactions, orphan accounts, impossible interest rates, negative resolution days, row-count reconciliation across all 3 layers)
6. **Automated tests** — `tests/pipeline_tests.sql`: 10 PASS/FAIL assertions (referential integrity between facts and dimensions, no duplicate keys survived into silver, business rule bounds), with a final `RAISERROR` if anything fails — suitable for CI
7. **Business questions** — `09_business_questions.sql`: all 20 business questions (5 each across Customer/Transaction/Loan/Complaint analytics), with assumptions documented inline wherever the brief was ambiguous
8. **Documentation suite** — `docs/data_architecture.md`, `data_integration.md`, `data_mart.md`, `data_catalog.md`, `data_flow.md`, `naming_conventions.md`
9. **Automation** — `run_pipeline.ps1` runs the full pipeline end-to-end; separate deployment scripts were used to push documentation and pipeline scripts from a local machine to GitHub

## Troubleshooting Log

- **PowerShell encoding bug** — an em-dash character in a status message caused Windows PowerShell to misread the file's text encoding, corrupting string parsing for the rest of the script. Fixed by keeping automation scripts to pure ASCII and verifying every embedded file decodes byte-for-byte before use.
- **Folder casing mismatch** — local folders existed as `Docs` / `Scripts` / `Datasets` from earlier manual work, while later automation targeted lowercase names. On Windows' case-insensitive filesystem this caused `git add` to silently skip newly-written files. Fixed by staging with `git add -A` and standardizing on lowercase folder names throughout.
- **OneDrive Desktop redirection** — OneDrive silently redirects `Desktop` to `OneDrive\Desktop`, so scripts referencing the plain path couldn't find files saved under the OneDrive-managed one. Resolved by always confirming the real path before running a script.
- **Uninitialized git folder** — an early clone attempt landed in a folder that was a plain directory, not an actual git repository, causing every `git` command to fail. Fixed by renaming the stale folder aside and performing a clean clone.

## Datasets

6 raw CSV extracts with intentionally seeded data quality issues (mixed date formats, inconsistent casing, duplicate records, invalid values):

| File | Approx. rows |
|---|---|
| customers.csv | 3,165 |
| accounts.csv | 4,951 |
| transactions.csv | 106,575 |
| loans.csv | 1,275 |
| complaints.csv | 970 |
| branches.csv | 32 |

## Status / Next Steps

- Bronze, Silver, and Gold layers all verified loading correctly with matching row counts
- Full pipeline, tests, documentation, and datasets confirmed pushed to `origin/main`
- **Pending:** Power BI dashboard build on top of the gold-layer views

---
*This log is also mirrored in Notion for project tracking.*
