"""
db.py — Reusable database connection helper.

Connects to the PostgreSQL `sales_DataWarehouse` using credentials
from .env. Provides:
    • get_engine()   → cached SQLAlchemy Engine
    • query_df(sql)  → pd.DataFrame from a raw SQL string or file path
    • get_connection()  → context-managed raw DBAPI connection
"""

from __future__ import annotations

import os
from pathlib import Path
from functools import lru_cache

import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import create_engine, text
from sqlalchemy.engine import Engine

# ── Load .env from project root ──────────────────────────────
_PROJECT_ROOT = Path(__file__).resolve().parent.parent
load_dotenv(_PROJECT_ROOT / ".env")


# ── Engine Factory ───────────────────────────────────────────
@lru_cache(maxsize=1)
def get_engine() -> Engine:
    """Return a cached SQLAlchemy engine for the sales data warehouse."""
    url = (
        f"postgresql+psycopg2://"
        f"{os.environ['PG_USER']}:{os.environ['PG_PASSWORD']}"
        f"@{os.environ.get('PG_HOST', 'localhost')}:{os.environ.get('PG_PORT', '5432')}"
        f"/{os.environ['PG_DB']}"
    )
    return create_engine(
        url,
        connect_args={"options": f"-csearch_path={os.environ.get('PG_SCHEMA', 'gold')}"},
        pool_pre_ping=True,
        echo=False,
    )


# ── Query Helper ─────────────────────────────────────────────
def query_df(sql: str, params: dict | None = None) -> pd.DataFrame:
    """
    Execute SQL and return results as a pandas DataFrame.

    Parameters
    ----------
    sql : str
        A raw SQL string **or** a path to a .sql file.
    params : dict, optional
        Named bind parameters for parameterized queries.

    Returns
    -------
    pd.DataFrame
    """
    # If `sql` points to a .sql file, read its contents.
    sql_path = Path(sql)
    if sql_path.suffix == ".sql" and sql_path.exists():
        sql = sql_path.read_text(encoding="utf-8")

    engine = get_engine()
    with engine.connect() as conn:
        return pd.read_sql(text(sql), conn, params=params)


# ── Raw Connection (context-managed) ─────────────────────────
def get_connection():
    """
    Yield a raw DBAPI connection via a context manager.

    Usage
    -----
    >>> with get_connection() as conn:
    ...     cur = conn.cursor()
    ...     cur.execute("SELECT 1")
    """
    return get_engine().connect()


# ── Quick smoke test ─────────────────────────────────────────
if __name__ == "__main__":
    df = query_df("SELECT current_database(), current_schema(), now()")
    print(df)
    print("[OK] Connection successful.")
