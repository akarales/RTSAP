#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Project root directory
PROJECT_ROOT=$(pwd)

echo -e "${BLUE}Setting up RTSAP Project Structure${NC}"
echo "=================================================="

# Function to create directory and print status
create_dir() {
    local dir=$1
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        echo -e "${GREEN}Created directory:${NC} $dir"
    else
        echo -e "${YELLOW}Directory already exists:${NC} $dir"
    fi
}

# Function to create file with content
create_file() {
    local file=$1
    local content=$2
    if [ ! -f "$file" ]; then
        echo "$content" > "$file"
        echo -e "${GREEN}Created file:${NC} $file"
    else
        echo -e "${YELLOW}File already exists:${NC} $file"
    fi
}

# Function to set up Conda environment
setup_conda_env() {
    if ! command -v conda &> /dev/null; then
        echo -e "${RED}Conda is not installed. Please install Conda first.${NC}"
        exit 1
    fi

    if ! conda env list | grep -q "^rtsap "; then
        echo -e "${BLUE}Creating Conda environment...${NC}"
        conda env create -f environment.yml
        echo -e "${GREEN}Created Conda environment 'rtsap'${NC}"
    else
        echo -e "${YELLOW}Conda environment 'rtsap' already exists${NC}"
        echo -e "${BLUE}Updating Conda environment...${NC}"
        conda env update -f environment.yml
    fi
}

# Create project structure
echo -e "\n${BLUE}Creating project structure...${NC}"

# Main project directories
directories=(
    "src/producer"
    "src/processor"
    "src/api"
    "src/dashboard"
    "k8s/base"
    "k8s/overlays/dev"
    "k8s/overlays/prod"
    "config/dev"
    "config/prod"
    "scripts"
    "tests/unit"
    "tests/integration"
    "docs/api"
    "docs/architecture"
    "notebooks"
    "data/raw"
    "data/processed"
)

for dir in "${directories[@]}"; do
    create_dir "$dir"
done

# Create Python package structure
create_dir "src/rtsap"
create_file "src/rtsap/__init__.py" ""

# Create Conda environment.yml
create_file "environment.yml" "name: rtsap
channels:
  - conda-forge
  - defaults
dependencies:
  - python=3.9
  - pip
  - numpy
  - pandas
  - scikit-learn
  - matplotlib
  - seaborn
  - jupyterlab
  - ipykernel
  - fastapi
  - uvicorn
  - python-dotenv
  - sqlalchemy
  - psycopg2
  - pymongo
  - confluent-kafka
  - requests
  - pytest
  - apache-flink
  - yfinance
  - pip:
    - kafka-python
    - timescale"

# Create docker-compose.yml
create_file "docker-compose.yml" "version: '3.8'

services:
  kafka:
    image: bitnami/kafka:latest
    ports:
      - '9092:9092'
    environment:
      - ALLOW_PLAINTEXT_LISTENER=yes
      
  timescaledb:
    image: timescale/timescaledb:latest-pg14
    ports:
      - '5432:5432'
    environment:
      - POSTGRES_PASSWORD=password
      
  api:
    build: 
      context: .
      dockerfile: src/api/Dockerfile
    ports:
      - '8000:8000'
    depends_on:
      - kafka
      - timescaledb
      
  dashboard:
    build:
      context: .
      dockerfile: src/dashboard/Dockerfile
    ports:
      - '3000:3000'
    depends_on:
      - api"

# Create .env.example
create_file ".env.example" "# Database Configuration
DB_HOST=localhost
DB_PORT=5432
DB_NAME=rtsap
DB_USER=postgres
DB_PASSWORD=password

# Kafka Configuration
KAFKA_BOOTSTRAP_SERVERS=localhost:9092
KAFKA_TOPIC_STOCK_PRICES=stock-prices

# API Configuration
API_HOST=0.0.0.0
API_PORT=8000

# Producer Configuration
STOCK_SYMBOLS=AAPL,GOOGL,MSFT
UPDATE_INTERVAL=60"

# Create .gitignore
create_file ".gitignore" "# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
.env

# Node
node_modules/
npm-debug.log
yarn-debug.log
yarn-error.log

# IDE
.idea/
.vscode/
*.swp
*.swo

# Operating System
.DS_Store
Thumbs.db

# Project specific
data/raw/*
data/processed/*
!data/raw/.gitkeep
!data/processed/.gitkeep

# Kubernetes
k8s/overlays/dev/secrets.yaml
k8s/overlays/prod/secrets.yaml"

# Create Kubernetes base configuration
create_file "k8s/base/kustomization.yaml" "apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - kafka.yaml
  - timescaledb.yaml
  - api.yaml
  - dashboard.yaml"

# Create producer source
create_file "src/producer/main.py" 'import os
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
    main()'

# Create API source
create_file "src/api/main.py" 'from fastapi import FastAPI, HTTPException
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
        raise HTTPException(status_code=500, detail=str(e))'

# Create processor source
create_file "src/processor/main.py" 'from pyflink.datastream import StreamExecutionEnvironment
from pyflink.table import StreamTableEnvironment, EnvironmentSettings
import os

def create_flink_job():
    # Set up the execution environment
    env = StreamExecutionEnvironment.get_execution_environment()
    settings = EnvironmentSettings.new_instance().in_streaming_mode().build()
    t_env = StreamTableEnvironment.create(env, settings)
    
    # Create Kafka source table
    t_env.execute_sql("""
        CREATE TABLE stock_prices (
            symbol STRING,
            price DOUBLE,
            timestamp BIGINT,
            processing_time AS PROCTIME()
        ) WITH (
            'connector' = 'kafka',
            'topic' = 'stock-prices',
            'properties.bootstrap.servers' = 'localhost:9092',
            'format' = 'json'
        )
    """)
    
    # Create TimescaleDB sink table
    t_env.execute_sql("""
        CREATE TABLE stock_analytics (
            symbol STRING,
            avg_price DOUBLE,
            window_start TIMESTAMP(3),
            window_end TIMESTAMP(3)
        ) WITH (
            'connector' = 'jdbc',
            'url' = 'jdbc:postgresql://localhost:5432/timescaledb',
            'table-name' = 'stock_analytics',
            'driver' = 'org.postgresql.Driver'
        )
    """)
    
    # Process data - Calculate 5-minute average prices
    t_env.sql_query("""
        INSERT INTO stock_analytics
        SELECT
            symbol,
            AVG(price) as avg_price,
            window_start,
            window_end
        FROM TABLE(
            TUMBLE(TABLE stock_prices, DESCRIPTOR(processing_time), INTERVAL '5' MINUTES))
        GROUP BY symbol, window_start, window_end
    """).execute()

if __name__ == "__main__":
    create_flink_job()'

# Create simple React dashboard
create_dir "src/dashboard/src"
create_file "src/dashboard/package.json" '{
  "name": "rtsap-dashboard",
  "version": "0.1.0",
  "private": true,
  "dependencies": {
    "@testing-library/jest-dom": "^5.16.5",
    "@testing-library/react": "^13.4.0",
    "@testing-library/user-event": "^13.5.0",
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-scripts": "5.0.1",
    "recharts": "^2.1.14",
    "axios": "^0.27.2"
  },
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build",
    "test": "react-scripts test",
    "eject": "react-scripts eject"
  }
}'

# Create helper scripts
create_file "scripts/start-services.sh" '#!/bin/bash
docker-compose up -d'

create_file "scripts/init-db.sh" '#!/bin/bash
psql -h localhost -U postgres -d rtsap -f sql/init.sql'

# Make scripts executable
chmod +x scripts/*.sh

# Create README
create_file "README.md" "# RTSAP - Real-Time Streaming Analytics Platform

## Quick Start

1. Set up the Conda environment:
\`\`\`bash
conda env create -f environment.yml
conda activate rtsap
\`\`\`

2. Copy and configure environment variables:
\`\`\`bash
cp .env.example .env
# Edit .env with your configurations
\`\`\`

3. Start the services:
\`\`\`bash
./scripts/start-services.sh
\`\`\`

4. Initialize the database:
\`\`\`bash
./scripts/init-db.sh
\`\`\`

5. Start the components:
\`\`\`bash
# Start the producer
python src/producer/main.py

# Start the API
cd src/api && uvicorn main:app --reload

# Start the dashboard
cd src/dashboard && npm start
\`\`\`

## Development

- Use \`conda activate rtsap\` to activate the development environment
- Run tests with \`pytest\`
- Use \`docker-compose up\` for local development with all services

## Documentation

See the \`docs/\` directory for detailed documentation.
"

# Set up Conda environment
echo -e "\n${BLUE}Setting up Conda environment...${NC}"
setup_conda_env

echo -e "\n${GREEN}Project setup complete!${NC}"
echo -e "Next steps:"
echo -e "1. Run: ${YELLOW}conda activate rtsap${NC}"
echo -e "2. Copy ${YELLOW}.env.example${NC} to ${YELLOW}.env${NC} and configure it"
echo -e "3. Start services with: ${YELLOW}./scripts/start-services.sh${NC}"
echo -e "4. Initialize database with: ${YELLOW}./scripts/init-db.sh${NC}"
echo -e "5. Start developing!"