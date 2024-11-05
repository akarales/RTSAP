from fastapi import FastAPI, HTTPException
from sqlalchemy import create_engine, text
import os
from datetime import datetime, timedelta
import pandas as pd

app = FastAPI(title="RTSAP API")

def get_db_url():
    return f"postgresql://{os.getenv("DB_USER")}:{os.getenv("DB_PASSWORD")}@{os.getenv("DB_HOST")}:{os.getenv("DB_PORT")}/{os.getenv("DB_NAME")}"

engine = create_engine(get_db_url())

@app.get("/")
async def root():
    return {"message": "RTSAP API is running"}

@app.get("/api/v1/health")
async def health_check():
    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        return {"status": "healthy"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/v1/prices/{symbol}")
async def get_stock_prices(symbol: str, interval: str = "5m", limit: int = 100):
    try:
        query = f"""
            SELECT * FROM stock_analytics 
            WHERE symbol = :symbol
            ORDER BY window_end DESC 
            LIMIT :limit
        """
        df = pd.read_sql(text(query), engine, params={"symbol": symbol, "limit": limit})
        return df.to_dict(orient="records")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
