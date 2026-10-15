select
    customer_key,
    customer_name,
    customer_address,
    customer_phone_number,
    customer_account_balance,
    customer_market_segment_name,
    customer_comment,
    nation_key,
    nation_name,
    region_key,
    region_name
from {{ ref('int_customer_geography') }}
