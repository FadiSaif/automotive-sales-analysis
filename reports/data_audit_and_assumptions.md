# Comprehensive Data Audit and Assumptions Report

**Target Subject:** Commercial Diagnostic and Data Model Integrity Audit  
**Business Unit:** Commercial Dealership & Aftermarket Parts Division (Aden Branch)  
**Target Schema:** `gold` (PostgreSQL Data Warehouse)  
**Period Under Review:** 2023-01-01 to 2025-12-31  

---

## 1. Executive Summary

This data audit establishes the evidentiary baseline for sales performance diagnostics across the `gold` relational schema. Every transactional record, foreign key relationship, arithmetic dependency, and dimensional attribute has been audited against source integrity constraints.

### Key Audit Verdicts

* **Structural Dimensional Integrity (Passed - 100%):** Zero duplicate surrogate keys exist in `gold.fact_sales`, and zero foreign key references are broken or orphaned across any associated dimension table.
* **Operational Revenue Boundary (High Business Risk):** 32.2% of the transactional pipeline (801 orders totaling 333,269.81 SAR) resides in an unposted or unreleased operational state. Excluding these records isolates the confirmed realized baseline at **700,807.44 SAR** across 1,090 orders and 12,325 line items.
* **Pricing & Discount Mechanics (Operational Anomaly):** Active line-level and header-level discounting fields are completely unpopulated (`0.00`). A single record (`fact_sales_key = 14639`) contains a non-decimal percentage input error (`16.5`) that had zero impact on realized revenue.
* **Point-of-Sale Margin Leakage (327 Loss Lines):** Direct losses totaling 2,373 SAR (201 realized lines accounting for -1,150.04 SAR) stem from manual price overrides and an unadjusted fixed exchange rate conversion for Yemeni Rial (YER) transactions.
* **Customer Master Breakdown (Analytical Blocker):** 87.14% of realized turnover is assigned to an unindexed generic entity, with the remaining entries containing ad-hoc descriptive notes. Customer retention, acquisition, and RFM analytics are technically unfeasible on this dataset.

---

## 2. Dimensional Model Architecture & Referential Integrity

Referential integrity was evaluated across 18,028 transactional records in `gold.fact_sales` against all foreign surrogate keys.

| Dimension Table | Foreign Key Column | Nulls | Orphan Keys | Audit Integrity Status |
|:---|:---|:---:|:---:|:---|
| `gold.fact_sales` | `fact_sales_key` (PK) | 0 | 0 | PASSED (100% Unique) |
| `gold.dim_sales_order` | `sales_order_key` | 0 | 0 | PASSED (Zero leakage) |
| `gold.dim_product` | `product_key` | 0 | 0 | PASSED (Zero leakage) |
| `gold.dim_customer` | `customer_key` | 0 | 0 | PASSED (Zero leakage) |
| `gold.dim_date` | `date_key` | 0 | 0 | PASSED (Zero leakage) |
| `gold.dim_sales_center` | `sales_center_key` | 0 | 0 | PASSED (Zero leakage) |
| `gold.dim_currency` | `currency_key` | 0 | 0 | PASSED (Zero leakage) |

All 18,028 line items resolve to valid records in their parent dimensional tables. Key collisions, relational dropouts, and ETL junction errors are zero.

---

## 3. Order Status Classification & Revenue Realization Boundary

The table `gold.dim_sales_order` records execution stages using boolean indicator flags (`is_posted`, `is_released`, `is_cheque`) and categorical invoice codes.

### Operational Status Reconciliation

| Invoice Type | Posted (`is_posted`) | Released (`is_released`) | Cheque (`is_cheque`) | Payment Mode | Orders | Line Items | Invoiced Units | Returned Units | Gross Invoiced (SAR) | Operational Accounting Classification |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---|
| **06** | `true` | `true` | `false` | Cash | 808 | 10,736 | 16,611.00 | 5.00 | 596,444.67 | Confirmed Realized Sale |
| **04** | `true` | `true` | `false` | Cash | 216 | 965 | 1,610.00 | 22.00 | 62,131.81 | Confirmed Realized Sale |
| **26** | `true` | `true` | `false` | Cash | 29 | 556 | 716.00 | 0.00 | 32,913.22 | Confirmed Realized Sale |
| **24** | `true` | `true` | `false` | Cash | 37 | 68 | 218.00 | 0.00 | 9,317.74 | Confirmed Realized Sale |
| **06** | `false` | `false` | `false` | Cash | 665 | 4,615 | 7,017.00 | 0.00 | 244,520.70 | Unposted Order Backlog |
| **04** | `false` | `false` | `false` | Cash | 133 | 895 | 2,014.00 | 139.00 | 78,976.25 | Unposted Order Backlog |
| **26** | `false` | `false` | `false` | Cash | 3 | 142 | 169.00 | 0.00 | 7,422.62 | Unposted Order Backlog |
| **06** | `false` | `false` | `true` | Cheque | 3 | 51 | 74.00 | 0.00 | 2,350.24 | Uncleared Cheque Pipeline |

### Classification Rules

1. **Realized Sales Pipeline:** Strictly defined as `is_posted = true AND is_released = true`. Cumulative realized revenue is **700,807.44 SAR** across 1,090 distinct order headers and 12,325 line items.
2. **Operational Backlog (Unposted):** 801 orders totaling **330,919.57 SAR** are marked as unposted (`is_posted = false`). These represent administrative processing bottlenecks or unfinalized orders.
3. **Uncleared Cheque Risk:** 3 orders totaling **2,350.24 SAR** remain unreleased pending bank clearance.
4. **Distortion Hazard:** Failing to filter by `is_posted = true AND is_released = true` inflates reported commercial baseline turnover by **47.55%**.

---

## 4. Arithmetic Reconciliation & Pricing Mechanics

### Column Functionality Audit

* **`net_price_sar` Inactivity:** The column `net_price_sar` is populated with `0.0000` throughout the transactional dataset. It must not be referenced in downstream reporting logic.
* **True Revenue Equation:** Line item revenue follows a single un-discounted derivation:
  $$\text{line\_total\_sar} = \text{quantity} \times \text{unit\_price\_sar}$$
* **Discount Structure Inactivity:** `discount_amount_sar` and `header_discount_pct` are consistently `0.00`. Realized pricing reflects direct entry values rather than structured promotional deductions.
* **The Invalid Discount Outlier:** Exactly 1 row (`fact_sales_key = 14639`, `sales_order_key = 884`) was flagged with `discount_pct = 16.5`. Analysis confirms this was an unparsed percentage entry (16.5% entered as an integer). Because `discount_amount_sar = 0.00` and `line_total_sar = 8 \times 0.3632 = 2.9056\text{ SAR}`, the field had zero commercial impact.
* **VAT Framework:** `vat_amount_sar = 0.00` across 100% of all transactional lines. Invoiced turnover directly equals net commercial revenue.

---

## 5. Value Boundary Anomaly Audit

Boundary thresholds were executed across all numerical columns to detect corrupted entries.

| Measure Tested | Boundary Rule | Violations Detected | Operational Root Cause |
|:---|:---|:---:|:---|
| `quantity` | $\le 0$ | 0 | PASSED |
| `returned_quantity` | $< 0$ | 0 | PASSED |
| `returned_quantity` | $> \text{quantity}$ | 0 | PASSED |
| `unit_price_sar` | $< 0$ | 0 | PASSED |
| `unit_cost_sar` | $< 0$ | 0 | PASSED |
| `discount_pct` | $< 0\text{ or } > 1$ | 1 | Manual input error (`fact_sales_key = 14639`) |
| `discount_amount_sar` | $< 0$ | 0 | PASSED |
| Unit Margin Loss | $unit\_cost\_sar > unit\_price\_sar$ | 327 | Manual price overrides and fixed currency conversion drag |

### Analysis of the 327 Negative Margin Transactions

1. **Posting Distribution:**
   - **Unposted Orders:** 126 lines accounting for -1,223.37 SAR in prospective margin loss.
   - **Realized Orders:** 201 lines accounting for **-1,150.04 SAR** in confirmed gross margin erosion.
2. **Quality/Origin Spread:** Losses are not isolated to a single procurement tier. Realized losses span Chinese (-398.53 SAR), Genuine (-328.77 SAR), Korean (-264.25 SAR), and Other (-158.49 SAR) parts categories.
3. **Core Contributing Drivers:**
   - **Counter Price Overrides:** Individual parts exhibit extreme manual discounts below cost at the point of sale. (e.g., Timing Belt `24312-26050` sold at 48.43 SAR against a unit cost of 122.02 SAR; Steering Repair Kit `57790-1E000M` sold at 7.26 SAR against a cost of 44.50 SAR).
   - **Currency Multiplier Friction:** Over 95% of negative margin occurrences are settled under Currency `01` (YER) with a static scalar exchange rate of `0.0024`. When replacement inventory costs rise in SAR while counter retail prices in YER remain static, converted sales prices fall below recorded unit costs.
4. **Materiality:** Total realized losses (-1,150.04 SAR) represent **0.16%** of realized revenue. This is an administrative point-of-sale control issue rather than a structural threat to solvency.

---

## 6. Temporal Bounds and Execution Dimensions

### Temporal Bounds

* **Sales Date Range (`dim_date.full_date`):** Bounded between **2023-01-01** and **2025-12-31**.
* **Future Dated Sales:** 0 records identified.
* **Pre-2020 Obsolete Records:** 0 records identified.
* **Settlement Due Dates (`dim_sales_order.due_date_key`):** Range between `20240101` and `20251231`.

### Sales Centers and Execution Reps

* **Single Physical Sales Center:** 100% of realized revenue originates from `sales_center_code = '01'`. Cross-branch comparative analysis is inapplicable.
* **Unassigned Sales Representatives:** The field `salesman_code` in `dim_sales_order` is consistently unpopulated across the dataset. Individual sales rep scorecards, performance rankings, and commission reconciliations cannot be produced from this dimensional model.

---

## 7. Customer Master Data Breakdown & Analytical Exclusion

Inspection of `dim_customer` reveals complete operational compromise of the customer dimension:

| Customer Code | Recorded Customer Name | Orders Handled | Total Realized Turnover (SAR) | Share of Revenue | Operational Finding |
|:---:|:---|:---:|:---:|:---:|:---|
| `NULL` | `0.0035714285 الجمعة 22/4/2022` | 476 | 610,690.62 | 87.14% | Default POS cash walk-in catch-all |
| `16` | فاتورة مبيعات آجــــــلة 21950-1C900 | 17 | 13,114.50 | 1.87% | Transaction description / Part number |
| `51` | فاتورة اجلة سوناتا - صالح بتاريخ9/3/2026 | 33 | 12,277.16 | 1.75% | Free-text counter memo |
| `21` | فاتورة مبيعات آجــــــلة 2026/1/26 | 19 | 9,116.02 | 1.30% | Date stamp memo |
| `82` | فاتورة مبيعات آجــــــلة كرسي مكينة خلفي | 4 | 5,256.50 | 0.75% | Part description memo |
| `Remaining` | Various descriptive text memos | 291 | 50,352.64 | 7.20% | Mixed OTC transaction notes |

### Formal Analytical Limitation Statement

* **Customer Retention, RFM, and Acquisition are Excluded:** Because 87.14% of turnover is mapped to a single dummy master record, calculating cohort retention, repeat purchase frequency, or churn yields mathematically invalid and commercially deceptive metrics.
* **Credit Risk:** Receivables categorized under "Credit Sales" (`فاتورة مبيعات آجــــــلة`) lack verified commercial entity profiles, generating immediate audit exposure for debt collection.

---

## 8. Standardized KPI Definitions

The following validated logic governs all subsequent reporting phases:

| Commercial KPI Standard | Standard Business Formula & SQL Formulation |
|:---|:---|
| **Realized Gross Turnover** | `SUM(fs.line_total_sar) WHERE dso.is_posted = true AND dso.is_released = true` |
| **Cost of Goods Sold (COGS)** | `SUM(fs.quantity * fs.unit_cost_sar) WHERE dso.is_posted = true AND dso.is_released = true` |
| **Realized Gross Margin SAR** | `SUM(fs.line_total_sar - (fs.quantity * fs.unit_cost_sar)) WHERE dso.is_posted = true AND dso.is_released = true` |
| **Realized Gross Margin %** | `(Realized Gross Margin SAR / Realized Gross Turnover SAR) * 100` |
| **Average Order Value (AOV)** | `Realized Gross Turnover SAR / COUNT(DISTINCT dso.sales_order_key)` |
| **Product Return Rate %** | `(SUM(fs.returned_quantity) / NULLIF(SUM(fs.quantity), 0)) * 100` |
| **Unposted Backlog Exposure** | `SUM(fs.line_total_sar) WHERE dso.is_posted = false` |

---

## 9. Immediate Technical & Data Governance Remediation

1. **ERP Point-of-Sale Validation Control:** Configure an automated block in the sales transaction module preventing cashiers from finalizing line items where $unit\_price\_sar < unit\_cost\_sar$.
2. **Customer Master Mandate:** Restrict write-access to the generic catch-all customer account (`0.0035714285...`). Require unique customer profile creation (name, phone number, commercial registry) for all wholesale and credit invoices (`فاتورة مبيعات آجــــــلة`).
3. **Backlog Purge:** Provide the 801 unposted transactions (330,919.57 SAR) to branch management to either finalize posting or delete stale draft records to restore accurate stock availability.
4. **Dynamic Currency Rate Architecture:** Replace the fixed static exchange rate scalar (`0.0024`) in `dim_currency` with a daily or weekly effective exchange rate table to eliminate artificial negative margin conversions.
