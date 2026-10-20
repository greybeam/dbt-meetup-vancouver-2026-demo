# Run dbt on Snowflake and DuckDB

This project runs dbt models on Snowflake and DuckDB against shared Iceberg
tables via Snowflake Horizon Catalog. Snowflake-managed storage holds the files,
so you don't need to deal with AWS.

The build runs in three steps:

| Step | Engine | Models |
| --- | --- | --- |
| 1 | Snowflake | Builds the five `base` models as Iceberg tables from `SNOWFLAKE_SAMPLE_DATA.TPCH_SF10`. |
| 2 | DuckDB on your laptop | Reads the base tables and writes `int_customer_geography` back as an Iceberg table. |
| 3 | Snowflake | Builds `int_order_revenue` and the marts, including `dim_customer`, which reads DuckDB's output. |

Full walkthrough: [Run dbt on Snowflake and DuckDB](https://greybeam.ai/blog/run-dbt-on-snowflake-and-duckdb/). The guide covers Snowflake setup, the project configuration,
troubleshooting, and storage access costs.

## Prerequisites

- Python 3.11 or later and [uv](https://docs.astral.sh/uv/getting-started/installation/).
- A Snowflake account on AWS with access to `SNOWFLAKE_SAMPLE_DATA.TPCH_SF10`
  and an existing warehouse.
- A database named `DEMO_DB` and a dbt role with `USAGE` and `CREATE SCHEMA`
  on that database, plus access to the warehouse and sample data. The setup
  below creates the demo schema as that role so it owns the schema.
- Key-pair authentication for the Snowflake target, as configured in
  `profiles.yml`. You can adapt that target to your existing authentication
  method instead.
- A programmatic access token (PAT) for DuckDB to authenticate to Horizon,
  usable with the same role, and a network policy that allows your connection's
  IP address. A policy set on your user also applies to your other Snowflake
  connections, including the Snowflake dbt target and Snowsight.
- DuckDB CLI 1.5.4 or later, if you want to run the optional verification query.
  The dbt build itself does not require a separate DuckDB CLI installation.

## Set up the project

Clone the repository and install its locked dependencies:

```bash
git clone https://github.com/greybeam/dbt-meetup-vancouver-2026-demo.git
cd dbt-meetup-vancouver-2026-demo
uv sync --locked
uv run dbt --version
```

The project pins dbt 2.0.6. Run dbt commands through `uv run` so they use this
version rather than another installation on your PATH.

Copy `.env.example` to `.env`, then replace the example values with your own:

```bash
cp .env.example .env
```

Set `SNOWFLAKE_TARGET_DATABASE=DEMO_DB`, fill in your account identifier
(`orgname-accountname`), user, role, warehouse, and private-key path, and put
the PAT in `PAT_TOKEN_SECRET`. Leave `SNOWFLAKE_PRIVATE_KEY_PASSPHRASE` empty
if your key is not encrypted. Keep `.env` out of git; it is already ignored.

The examples use `DEMO_DB.TPCH_DEMO`. If you choose different names, update
`catalogs.yml`, the schema settings in `profiles.yml`, and the SQL below to
match your environment variables.

Export the variables in the terminal where you will run dbt:

```bash
set -a
source .env
set +a
```

In Snowflake, run the following as the role specified by `SNOWFLAKE_ROLE`:

```sql
CREATE SCHEMA IF NOT EXISTS DEMO_DB.TPCH_DEMO;
ALTER SCHEMA DEMO_DB.TPCH_DEMO SET EXTERNAL_VOLUME = 'SNOWFLAKE_MANAGED';
ALTER SCHEMA DEMO_DB.TPCH_DEMO SET CATALOG = 'SNOWFLAKE';
```

If the schema already exists, have its owner set the defaults and grant your
dbt role the privileges it needs to create tables and Iceberg tables there.
The `EXTERNAL_VOLUME` default is needed when DuckDB creates tables through
Horizon. Without it, creation can fail with `403 Authorization failed` even
when the role has `CREATE ICEBERG TABLE`.

Check the Snowflake connection:

```bash
uv run dbt debug --target snowflake --profiles-dir .
```

## Build the models on both engines

Run the three builds in dependency order. The `&&` operators stop the sequence
if a step fails:

```bash
uv run dbt build --target snowflake --profiles-dir . -s base && \
uv run dbt build --target duckdb --profiles-dir . -s int_customer_geography && \
uv run dbt build --target snowflake --profiles-dir . -s int_order_revenue+ dim_customer
```

Each build runs the selected models and their tests. All three commands should
finish successfully. The DuckDB step builds `INT_CUSTOMER_GEOGRAPHY` and runs
its four data tests; the final Snowflake step builds the models that consume
its output.

If the DuckDB build fails, fix the error and rerun that step before running
the final Snowflake step. A failed DuckDB table rebuild can leave the previous
table missing.

Models assigned to DuckDB must use SQL that DuckDB understands. dbt 2.0 does
not automatically translate model SQL between dialects. These commands use
separate targets and do not require the experimental multi-adapter flag.

## Query the shared tables from the DuckDB CLI

After the builds finish, you can read the Iceberg tables outside dbt. From the
same terminal with your environment variables exported, start an in-memory
DuckDB session:

```bash
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

SELECT region_name, count(*) AS customers
FROM horizon.TPCH_DEMO.INT_CUSTOMER_GEOGRAPHY
GROUP BY region_name;
```

The query returns customer counts by region from the table DuckDB built.
DuckDB executes the query locally against the existing Iceberg data; Horizon
provides catalog metadata and temporary storage credentials. `DEMO_DB` is the
Snowflake database, not a compute warehouse. Ordinary Snowflake tables, such
as `dim_customer`, are not exposed by this Iceberg attachment.

The PAT is read using the CLI's
[`getenv()` function](https://duckdb.org/docs/stable/clients/cli/overview#reading-environment-variables),
so you don't need to paste it into SQL. The secret lasts only for this session.
See [DuckDB Iceberg catalogs](https://duckdb.org/docs/current/core_extensions/iceberg/catalogs)
for more about catalog attachment. Type `.quit` to exit.

## Troubleshooting

- **403 when DuckDB creates a table:** Check the schema's default
  `EXTERNAL_VOLUME` first. Use the `ALTER SCHEMA` statements above.
- **A table exists but DuckDB cannot find it:** Horizon expects uppercase
  names for these tables. Keep the `macros/generate_alias_name.sql` override,
  which uppercases dbt's model aliases.
- **`BASE_LOCATION property is not supported`:** Check `uv run dbt --version`
  and use `uv run` for every dbt command. An older global dbt installation can
  generate SQL that Snowflake-managed storage rejects.
- **IP address rejected:** Connect from an address allowed by your Snowflake
  network policy, such as your VPN, or ask the policy owner to add your address.
