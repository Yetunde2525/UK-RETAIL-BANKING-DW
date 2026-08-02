# Naming Conventions

Consistent naming makes the pipeline predictable to navigate — you should be able to guess an object's name (and roughly what it does) without opening it. These are the conventions actually used throughout this repo.

## Schemas

| Schema | Purpose |
|---|---|
| `bronze` | Raw landing tables |
| `silver` | Cleaned/conformed tables |
| `gold` | Star schema + reporting views |
| `dbo` | Shared helper functions used across layers (`fn_ParseMessyDate`, `fn_ProperCase`) |

## Tables

| Layer | Convention | Example |
|---|---|---|
| Bronze | `snake_case`, matches the source CSV name exactly | `bronze.customers` ← `customers.csv` |
| Silver | Same name as bronze, same schema-per-layer pattern | `silver.customers` |
| Gold dimensions | `PascalCase`, prefixed `Dim` | `gold.DimCustomer` |
| Gold facts | `PascalCase`, prefixed `Fact` | `gold.FactTransactions` |

## Columns

| Convention | Applies to | Example |
|---|---|---|
| `snake_case` | All bronze/silver columns, and natural-key/attribute columns carried into gold | `customer_id`, `annual_income`, `transaction_date` |
| `PascalCase` | Surrogate keys and gold-only derived/extension columns | `CustomerKey`, `TransactionType`, `ResolutionDays` |
| `is_<condition>` (BIT) | Validity flags introduced in silver | `is_email_valid`, `is_valid_account`, `is_interest_rate_valid` |
| `<Entity>Key` | Surrogate primary key on every gold dimension, and the matching foreign key on facts | `BranchKey`, `LoanKey`, `DateKey` |

## Stored procedures

Pattern: `<schema>.load_<schema>` — the schema name doubles as the description of what gets loaded.
- `bronze.load_bronze`
- `silver.load_silver`
- `gold.load_gold`

## Views

Pattern: `gold.vw_<subject>` — always lowercase snake_case after the `vw_` prefix, always in the `gold` schema since views only exist at the reporting layer.
- `gold.vw_customer_summary`, `gold.vw_branch_performance`, `gold.vw_loan_performance`, `gold.vw_complaint_analysis`

## Functions

Pattern: `dbo.fn_<Verb><Noun>` — lives in `dbo` since these are cross-layer utilities, not tied to one schema's data.
- `dbo.fn_ParseMessyDate`, `dbo.fn_ProperCase`

## Scripts and folders

Pattern: `<NN>_<description>.sql`, zero-padded two-digit prefix, grouped into a folder per layer — the number alone tells you execution order across the *entire* pipeline, not just within a folder.

```
scripts/
├── 00_init_database.sql
├── bronze/01_ddl_bronze.sql, 02_load_bronze.sql
├── silver/03_ddl_silver.sql, 04_load_silver.sql
├── gold/05_ddl_gold.sql, 06_load_gold.sql, 07_views.sql
├── checks/08_data_quality_checks.sql
└── business_questions/09_business_questions.sql
```

`tests/` and `docs/` sit outside this numbering since they aren't part of the run sequence — they're verification and reference material, run/read independently.

## Booleans vs. flags vs. status strings

- Use a `BIT` `is_*` column when the check is binary and machine-derived (valid/invalid).
- Use a free-text `*_status` column (e.g. `account_status`, `loan_status`, `complaint_status`) when the value is a business-defined state with more than two possible values, sourced from upstream rather than computed here.
