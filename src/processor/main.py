from pyflink.datastream import StreamExecutionEnvironment
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
            connector = kafka,
            topic = stock-prices,
            properties.bootstrap.servers = localhost:9092,
            format = json
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
            connector = jdbc,
            url = jdbc:postgresql://localhost:5432/timescaledb,
            table-name = stock_analytics,
            driver = org.postgresql.Driver
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
            TUMBLE(TABLE stock_prices, DESCRIPTOR(processing_time), INTERVAL 5 MINUTES))
        GROUP BY symbol, window_start, window_end
    """).execute()

if __name__ == "__main__":
    create_flink_job()
