# TPC-H dbt demo

## Run dbt with uv

This project uses the `dbt` v2 package. Install the locked dependencies and check
the runtime:

```bash
uv sync --locked
uv run dbt --version
```

The version command should report `dbt 2.x`. Run project commands through uv:

```bash
uv run dbt debug --profiles-dir .
uv run dbt parse --profiles-dir .
uv run dbt build --target snowflake --profiles-dir .
```

## Query Snowflake Iceberg tables from the DuckDB CLI

Use DuckDB CLI 1.5.4 or newer and connect to the VPN allowed by your Snowflake
network policy. Run the following from the repository root. Your `.env` must
define `SNOWFLAKE_ACCOUNT`, `SNOWFLAKE_ROLE`, and `PAT_TOKEN_SECRET`.

First, export the environment variables and start an in-memory DuckDB session:

```bash
set -a
source .env
set +a
duckdb :memory:
```

Then paste this SQL into the DuckDB prompt:

```sql
INSTALL iceberg;
LOAD iceberg;
INSTALL httpfs;
LOAD httpfs;

SET VARIABLE horizon_url =
    'https://' || getenv('SNOWFLAKE_ACCOUNT')
    || '.snowflakecomputing.com/polaris/api/catalog';

CREATE SECRET horizon_secret (
    TYPE iceberg,
    CLIENT_ID '',
    CLIENT_SECRET getenv('PAT_TOKEN_SECRET'),
    OAUTH2_SERVER_URI getvariable('horizon_url') || '/v1/oauth/tokens',
    OAUTH2_SCOPE 'session:role:' || getenv('SNOWFLAKE_ROLE')
);

ATTACH 'DEMO_DB' AS horizon (
    TYPE iceberg,
    ENDPOINT getvariable('horizon_url'),
    SECRET horizon_secret,
    ACCESS_DELEGATION_MODE 'vended_credentials'
);

SELECT *
FROM horizon.TPCH_DEMO.MY_TABLE_TEST
LIMIT 10;

SELECT 
    nation_key
    , COUNT(*) as num_customers
    , SUM(CUSTOMER_ACCOUNT_BALANCE) as account_balance
FROM horizon.TPCH_DEMO.BASE_CUSTOMER
WHERE
    CUSTOMER_MARKET_SEGMENT_NAME = 'HOUSEHOLD'
GROUP BY 1;
```

The test table created with `AS SELECT 1` should return one row containing `1`.
DuckDB executes the query locally against the existing Iceberg data; Horizon
provides catalog metadata and temporary storage credentials. `DEMO_DB` is the
Snowflake database, not a compute warehouse. Ordinary Snowflake tables and views
are not exposed by this Iceberg attachment.

The PAT is read using the CLI's
[`getenv()` function](https://duckdb.org/docs/stable/clients/cli/overview#reading-environment-variables),
so you don't need to paste it into SQL. The secret lasts only for this session.
See [DuckDB Iceberg catalogs](https://duckdb.org/docs/current/core_extensions/iceberg/catalogs)
for more about catalog attachment. Type `.quit` to exit.