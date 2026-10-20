{{ config(
    materialized='table',
    alias='BASE_LINEITEM'
) }}

select
    l_orderkey as order_key,
    l_partkey as part_key,
    l_suppkey as supplier_key,
    l_linenumber as line_number,
    l_quantity as quantity,
    l_extendedprice{{ money() }} as extended_price,
    l_discount{{ money() }} as discount,
    l_tax{{ money() }} as tax,
    l_returnflag as return_flag,
    l_linestatus as line_status,
    l_shipdate as ship_date,
    l_commitdate as commit_date,
    l_receiptdate as receipt_date,
    l_shipinstruct as shipping_instructions,
    l_shipmode as shipping_mode,
    l_comment as lineitem_comment
from {{ source('tpch', 'lineitem') }}
