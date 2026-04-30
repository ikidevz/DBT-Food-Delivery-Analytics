-- ─────────────────────────────────────────────────────────────────────────────
-- init-scripts/01_create_schemas.sql
-- Runs automatically on first Postgres container start.
-- Creates the three medallion schemas so dbt doesn't need CREATE SCHEMA privs.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS bronze;
CREATE SCHEMA IF NOT EXISTS silver;
CREATE SCHEMA IF NOT EXISTS gold;

GRANT ALL PRIVILEGES ON SCHEMA raw    TO dbt_user;
GRANT ALL PRIVILEGES ON SCHEMA bronze TO dbt_user;
GRANT ALL PRIVILEGES ON SCHEMA silver TO dbt_user;
GRANT ALL PRIVILEGES ON SCHEMA gold   TO dbt_user;
