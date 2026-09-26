# Automotive Sales Analysis

Data analytics project for **Hyundai Bin Abdulwali** automotive parts sales data.  
Upstream warehouse: PostgreSQL `sales_DataWarehouse` → `gold` schema (Star Schema / Kimball).

> **Data Pipeline & Warehouse →** [FadiSaif/DataPipeline_DataWarehouse](https://github.com/FadiSaif/DataPipeline_DataWarehouse)

---

## Project Structure

```
├── src/
│   └── db.py              # Reusable database connection helper
├── queries/
│   ├── executive_kpis.sql          # Monthly revenue, AOV, margin %
│   ├── product_pareto.sql          # 80/20 SKU analysis
│   └── vehicle_origin_performance.sql  # Genuine vs. Aftermarket
├── notebooks/             # Jupyter exploration notebooks
├── reports/               # Generated HTML / PDF reports
├── .env.example           # Database credentials template
├── requirements.txt       # Python dependencies
└── .gitignore             # Zero-data-leakage rules
```

## Quick Start

```bash
# 1. Clone & setup
git clone <repo-url> && cd automotive-sales-analysis
python -m venv venv && venv\Scripts\activate    # Windows
pip install -r requirements.txt

# 2. Configure credentials
cp .env.example .env       # then edit .env with your DB creds

# 3. Smoke test
python src/db.py           # should print current_database, schema, timestamp
```

## Security

All business data is **private** and excluded from version control via `.gitignore`.  
Never commit `.csv`, `.parquet`, `.env`, or any data exports.

## License

MIT — see [LICENSE](LICENSE). Business data remains proprietary.
