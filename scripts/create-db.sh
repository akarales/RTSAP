#!/bin/bash
set -e
PGPASSWORD=${DB_PASSWORD:-password} psql -h localhost -U ${DB_USER:-postgres} -d postgres -c "CREATE DATABASE rtsap;"
