#!/bin/bash
psql -h localhost -U postgres -d rtsap -f sql/init.sql
