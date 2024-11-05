import os
import json
import time
from datetime import datetime
from kafka import KafkaProducer
import yfinance as yf

def create_producer():
    return KafkaProducer(
        bootstrap_servers=os.getenv("KAFKA_BOOTSTRAP_SERVERS", "localhost:9092"),
        value_serializer=lambda v: json.dumps(v).encode("utf-8")
    )

def fetch_stock_data(symbol: str) -> dict:
    """Fetch real-time stock data using yfinance"""
    try:
        stock = yf.Ticker(symbol)
        data = stock.history(period="1d", interval="1m")
        if len(data) > 0:
            return {
                "symbol": symbol,
                "price": float(data["Close"].iloc[-1]),
                "timestamp": int(datetime.now().timestamp() * 1000)
            }
    except Exception as e:
        print(f"Error fetching data for {symbol}: {e}")
    return None

def main():
    producer = create_producer()
    symbols = os.getenv("STOCK_SYMBOLS", "AAPL,GOOGL,MSFT").split(",")
    interval = int(os.getenv("UPDATE_INTERVAL", "60"))
    
    print(f"Starting producer for symbols: {symbols}")
    
    while True:
        for symbol in symbols:
            data = fetch_stock_data(symbol)
            if data:
                producer.send(
                    os.getenv("KAFKA_TOPIC_STOCK_PRICES", "stock-prices"),
                    data
                )
                print(f"Sent data for {symbol}: {data}")
        time.sleep(interval)

if __name__ == "__main__":
    main()
