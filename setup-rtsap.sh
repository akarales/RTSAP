#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Project root directory
PROJECT_ROOT=$(pwd)

echo -e "${BLUE}Setting up RTSAP Project${NC}"
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

# Function to check prerequisites
check_prerequisites() {
    echo -e "\n${BLUE}Checking prerequisites...${NC}"
    
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Docker is not installed. Please install Docker first.${NC}"
        exit 1
    fi
    
    if ! docker ps &> /dev/null; then
        echo -e "${RED}Docker daemon is not running or you don't have permissions.${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Docker is installed and running${NC}"
    
    if ! command -v conda &> /dev/null; then
        echo -e "${RED}Conda is not installed. Please install Conda first.${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Conda is installed${NC}"
    
    if ! command -v git &> /dev/null; then
        echo -e "${RED}Git is not installed. Please install Git first.${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Git is installed${NC}"
    
    if ! command -v node &> /dev/null; then
        echo -e "${RED}Node.js is not installed. Please install Node.js first.${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Node.js is installed${NC}"
}

# Function to set up Conda environment
setup_conda_env() {
    if ! conda env list | grep -q "^rtsap "; then
        echo -e "${BLUE}Creating new Conda environment...${NC}"
        conda env create -f environment.yml
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Successfully created Conda environment 'rtsap'${NC}"
        else
            echo -e "${RED}Failed to create Conda environment${NC}"
            exit 1
        fi
    else
        echo -e "${YELLOW}Conda environment 'rtsap' already exists${NC}"
        echo -e "${BLUE}Updating Conda environment...${NC}"
        conda env update -f environment.yml
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Successfully updated Conda environment${NC}"
        else
            echo -e "${RED}Failed to update Conda environment${NC}"
            exit 1
        fi
    fi
}

# Function to verify setup
verify_setup() {
    echo -e "\n${BLUE}Verifying setup...${NC}"
    
    if ! conda env list | grep -q "^rtsap "; then
        echo -e "${RED}Conda environment 'rtsap' was not created properly${NC}"
        exit 1
    fi
    
    for dir in "${directories[@]}"; do
        if [ ! -d "$dir" ]; then
            echo -e "${RED}Directory $dir was not created properly${NC}"
            exit 1
        fi
    done
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            echo -e "${RED}File $file was not created properly${NC}"
            exit 1
        fi
    done
    
    echo -e "${GREEN}Setup verified successfully!${NC}"
}

# Check prerequisites first
check_prerequisites

# Create project structure
echo -e "\n${BLUE}Creating project structure...${NC}"

# Main project directories
directories=(
    "src/producer"
    "src/processor"
    "src/api"
    "src/dashboard/src"
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
    "sql"
    ".vscode"
)

# Required files for verification
required_files=(
    "environment.yml"
    "docker-compose.yml"
    ".env.example"
    "sql/init.sql"
    "src/api/Dockerfile"
    "src/dashboard/Dockerfile"
    "src/api/requirements.txt"
    "src/dashboard/src/App.js"
    "k8s/base/kustomization.yaml"
)

# Create directories
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
  - requests
  - pytest
  - pip:
    - kafka-python
    - timescale
    - confluent-kafka
    - apache-flink
    - yfinance"

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

# Create SQL init file
create_file "sql/init.sql" "-- Initialize TimescaleDB
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- Create stock analytics table
CREATE TABLE IF NOT EXISTS stock_analytics (
    symbol VARCHAR(10),
    avg_price DOUBLE PRECISION,
    window_start TIMESTAMP,
    window_end TIMESTAMP
);

-- Make it a hypertable
SELECT create_hypertable('stock_analytics', 'window_start');"

# Create API Dockerfile
create_file "src/api/Dockerfile" "FROM python:3.9-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY src/api /app
CMD [\"uvicorn\", \"main:app\", \"--host\", \"0.0.0.0\", \"--port\", \"8000\"]"

# Create Dashboard Dockerfile
create_file "src/dashboard/Dockerfile" "FROM node:18-alpine

WORKDIR /app
COPY src/dashboard/package*.json ./
RUN npm install

COPY src/dashboard /app
CMD [\"npm\", \"start\"]"

# Create API requirements.txt
create_file "src/api/requirements.txt" "fastapi==0.104.1
uvicorn==0.24.0
sqlalchemy==2.0.23
pandas==2.1.3
psycopg2-binary==2.9.9
python-dotenv==1.0.0"

# Create React App component
create_file "src/dashboard/src/App.js" 'import React, { useState, useEffect } from "react";
import axios from "axios";

function App() {
  const [stocks, setStocks] = useState([]);

  useEffect(() => {
    const fetchData = async () => {
      const symbols = ["AAPL", "GOOGL", "MSFT"];
      const results = await Promise.all(
        symbols.map(symbol => 
          axios.get(`/api/v1/prices/${symbol}`)
        )
      );
      setStocks(results.map(r => r.data));
    };

    fetchData();
    const interval = setInterval(fetchData, 5000);
    return () => clearInterval(interval);
  }, []);

  return (
    <div>
      <h1>RTSAP Dashboard</h1>
      {stocks.map((stockData, index) => (
        <div key={index}>
          <h2>{stockData[0]?.symbol}</h2>
          <p>Latest Price: {stockData[0]?.avg_price}</p>
        </div>
      ))}
    </div>
  );
}'

# Create helper scripts
create_file "scripts/start-services.sh" '#!/bin/bash
set -e

if ! docker-compose up -d; then
    echo "Failed to start services"
    exit 1
fi

echo "Waiting for services to be ready..."
sleep 10

if ! docker-compose ps | grep -q "Up"; then
    echo "Services failed to start properly"
    exit 1
fi

echo "Services started successfully"'

create_file "scripts/init-db.sh" '#!/bin/bash
set -e
PGPASSWORD=${DB_PASSWORD:-password} psql -h localhost -U ${DB_USER:-postgres} -d rtsap -f sql/init.sql'

create_file "scripts/create-db.sh" '#!/bin/bash
set -e
PGPASSWORD=${DB_PASSWORD:-password} psql -h localhost -U ${DB_USER:-postgres} -d postgres -c "CREATE DATABASE rtsap;"'

# Make scripts executable
chmod +x scripts/*.sh

# Create VS Code settings
create_file ".vscode/settings.json" '{
    "python.defaultInterpreterPath": "~/anaconda3/envs/rtsap/bin/python",
    "python.linting.enabled": true,
    "python.linting.pylintEnabled": true,
    "python.formatting.provider": "black",
    "editor.formatOnSave": true
}'

# Create placeholder files for data directories
touch data/raw/.gitkeep
touch data/processed/.gitkeep

# Copy .env.example to .env if it doesn't exist
if [ ! -f ".env" ]; then
    cp .env.example .env
    echo -e "${GREEN}Created .env file from template${NC}"
fi

# Set up Conda environment
echo -e "\n${BLUE}Setting up Conda environment...${NC}"
setup_conda_env

# Initialize git repository if not already initialized
if [ ! -d ".git" ]; then
    git init
    echo -e "${GREEN}Initialized Git repository${NC}"
fi

# Verify the setup
verify_setup

echo -e "\n${GREEN}Project setup complete!${NC}"
echo -e "\nNext steps:"
echo -e "1. Run: ${YELLOW}conda activate rtsap${NC}"
echo -e "2. Review and update ${YELLOW}.env${NC} with your configurations"
echo -e "3. Create database: ${YELLOW}./scripts/create-db.sh${NC}"
echo -e "4. Start services: ${YELLOW}./scripts/start-services.sh${NC}"
echo -e "5. Initialize database: ${YELLOW}./scripts/init-db.sh${NC}"
echo -e "6. Start components in separate terminals:"
echo -e "   ${YELLOW}./scripts/start-producer.sh${NC}"
echo -e "   ${YELLOW}./scripts/start-api.sh${NC}"
echo -e "   ${YELLOW}./scripts/start-dashboard.sh${NC}"
echo -e "\nFor more information, see the documentation in the ${YELLOW}docs/${NC} directory."