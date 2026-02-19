-- Creates the reef_document database on first boot
-- (the default 'reef' database is created by POSTGRES_DB env var)
SELECT 'CREATE DATABASE reef_document'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'reef_document')\gexec
