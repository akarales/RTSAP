#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}Fixing RTSAP Environment${NC}"
echo "=================================================="

# Update environment.yml file
cat > environment.yml << 'EOL'
name: rtsap
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
    - yfinance
EOL

echo -e "${GREEN}Updated environment.yml${NC}"

# Remove existing environment if it exists
if conda env list | grep -q "^rtsap "; then
    echo -e "${YELLOW}Removing existing rtsap environment...${NC}"
    conda env remove -n rtsap
fi

# Create new environment
echo -e "${BLUE}Creating new conda environment...${NC}"
conda env create -f environment.yml

echo -e "\n${GREEN}Environment setup complete!${NC}"
echo -e "Next steps:"
echo -e "1. Run: ${YELLOW}conda activate rtsap${NC}"
echo -e "2. Verify installation with: ${YELLOW}python -c 'import pandas; print(pandas.__version__)'${NC}"