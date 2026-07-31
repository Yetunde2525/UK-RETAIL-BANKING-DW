# Data Mart

## What counts as "the mart" here

The gold schema is a single integrated warehouse, but it serves four distinct analytical marts — one per business area from the original brief. Each mart is a combination of specific dimensions/facts plus one reporting view, and maps directly to a group of the 20 business questions.

| Mart | Gold objects used | View | Business questions answered |
|---|---|---|---|
| **Customer Mart** | DimCustomer, DimAccount, FactTransactions, FactLoans, FactComplaints | `gold.vw_customer_summary` | Q1–Q5 |
| **Transaction Mart** | FactTransactions, DimAccount, DimBranch, DimDate | `gold.vw_branch_performance` (branch cut) + direct fact queries | Q6–Q10 |
| **Loan Mart** | DimLoan, FactLoans, DimAccount | `gold.vw_loan_performance` | Q11–Q15 |
| **Complaint Mart** | FactComplaints, DimBranch | `gold.vw_complaint_analysis` | Q16–Q20 |

## Why one gold schema instead of four separate marts

The dimensions overlap heavily — `DimCustomer`, `DimBranch`, and `DimDate` are shared across all four marts (a customer who transacts, holds a loan, *and* complains needs one consistent CustomerKey, not four disconnected copies). Splitting into fully independent marts would mean either duplicating those dimensions four times or building conformed dimensions anyway — at which point it's just one warehouse with four consumption-oriented views on top, which is what's here.

## Consumption

- **Power BI dashboard** connects directly to the `gold` schema (views preferred over raw fact/dim tables where a view exists, since the views pre-aggregate the joins).
- **Business analysts / ad-hoc SQL** can query `scripts/business_questions/09_business_questions.sql` directly against facts/dims for anything not already covered by a view.

## Refresh cadence

This project runs as a full batch refresh — every mart is rebuilt from scratch each time `gold.load_gold` runs (via `TRUNCATE` + reload), so there's no incremental/partial mart update to reason about. All four marts are always mutually consistent as of the same load.
