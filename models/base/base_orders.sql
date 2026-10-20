{{ config(
    materialized='table',
    alias='BASE_ORDERS'
) }}

select
    o_orderkey as order_key,
    o_custkey as customer_key,
    o_orderstatus as order_status,
    o_totalprice{{ money() }} as order_total_price,
    o_orderdate as order_date,
    o_orderpriority as order_priority,
    o_clerk as order_clerk,
    o_shippriority as shipping_priority,
    o_comment as order_comment
from {{ source('tpch', 'orders') }}
