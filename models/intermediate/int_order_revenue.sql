with lineitem_revenue as (
    select
        order_key,
        sum(extended_price * (1 - discount)){{ money() }} as order_revenue
    from {{ ref('base_lineitem') }}
    group by order_key
)

select
    orders.order_key,
    orders.customer_key,
    orders.order_date,
    coalesce(lineitem_revenue.order_revenue, 0){{ money() }} as order_revenue
from {{ ref('base_orders') }} as orders
left join lineitem_revenue
    on orders.order_key = lineitem_revenue.order_key
