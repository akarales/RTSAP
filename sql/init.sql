-- Initialize TimescaleDB
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- Create stock analytics table
CREATE TABLE IF NOT EXISTS stock_analytics (
    symbol VARCHAR(10),
    avg_price DOUBLE PRECISION,
    window_start TIMESTAMP,
    window_end TIMESTAMP
);

-- Make it a hypertable
SELECT create_hypertable('stock_analytics', 'window_start');
