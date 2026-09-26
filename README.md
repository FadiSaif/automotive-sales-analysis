# Automotive Sales Analysis

Comprehensive data analytics and business intelligence project for automotive spare parts and commercial aftermarket dealership operations.  
Target warehouse: PostgreSQL `sales_DataWarehouse` → `gold` schema (Dimensional Star Schema / Kimball methodology).

---

## Business Context & Warehouse Architecture

- **Domain:** Automotive Dealership & Commercial Aftermarket Spare Parts Distribution
- **Target Schema:** `gold` (Star Schema)
  - `fact_sales`: Line-item transactional sales grain normalized to SAR currency (18,028 records).
  - `dim_product`: 22,282 parts catalog entries with vehicle compatibility, origin quality, and system classifications.
  - `dim_sales_order`: 1,894 sales invoices with operational status flags (`is_posted`, `is_released`, `payment_mode`).
  - `dim_customer`: Customer master records.
  - `dim_date`: 8-year calendar coverage (2023–2030).
  - `dim_currency`: Pegged SAR conversion dimensions.
  - `dim_sales_center`: Branch distribution center dimension.

---

## Project Structure

```
├── src/
│   └── db.py                        # Reusable database connection pool & query engine
├── queries/
│   ├── executive_kpis.sql           # Monthly realized revenue, AOV, gross margin %, MoM growth
│   ├── product_pareto.sql           # Realized 80/20 product Pareto classification
│   ├── vehicle_origin_performance.sql # Realized Genuine vs Aftermarket performance
│   └── pareto_analysis.sql          # Part category profit Pareto ABC ranking
├── notebooks/
│   └── 01_data_inspection.ipynb     # Audited data quality & schema inspection notebook
├── reports/
│   ├── data_audit_and_assumptions.md # Comprehensive data audit & evidentiary baseline
│   └── sop_upstream_backlog_reconciliation.md # Upstream order backlog reconciliation SOP
├── .env.example                     # Database credentials template
├── requirements.txt                 # Python dependencies
└── .gitignore                       # Zero-data-leakage rules
```

---

## Quick Start

```bash
# 1. Clone & setup
git clone <repo-url> && cd automotive-sales-analysis
python -m venv .venv && .venv\Scripts\activate    # Windows
pip install -r requirements.txt

# 2. Configure credentials
cp .env.example .env       # edit .env with your local PostgreSQL DB credentials

# 3. Smoke test connection
python src/db.py           # outputs current_database, schema, and connection status
```

---

## Data Governance & Standards

- **Operational Realization Boundary:** Realized commercial baseline is strictly filtered by `is_posted = true AND is_released = true` (700,807.44 SAR across 1,090 orders).
- **Zero Data Leakage:** All transactional data and credentials remain in the secure data warehouse. Only queries, analytical code, and aggregated documentation are version controlled.

---

## License

This project is licensed under the [MIT License](LICENSE).
