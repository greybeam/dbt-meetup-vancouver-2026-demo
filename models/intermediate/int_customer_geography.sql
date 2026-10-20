{{ config(
    materialized='table',
    catalog_name='horizon_catalog',
) }}

select
    customers.customer_key,
    customers.customer_name,
    customers.customer_address,
    customers.customer_phone_number,
    customers.customer_account_balance,
    customers.customer_market_segment_name,
    customers.customer_comment,
    customers.nation_key,
    nations.nation_name,
    nations.region_key,
    regions.region_name,
    -- dateadd('day', 5, current_date) as days_from_now -- this will break when running on DuckDB since dbt 2.0 does not translate dialects!
from {{ ref('base_customer') }} as customers
left join {{ ref('base_nation') }} as nations
    on customers.nation_key = nations.nation_key
left join {{ ref('base_region') }} as regions
    on nations.region_key = regions.region_key
