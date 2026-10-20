select
    orders.order_date,
    customers.region_name,
    count(*) as order_count,
    sum(orders.order_revenue){{ money() }} as order_revenue
from {{ ref('int_order_revenue') }} as orders
left join {{ ref('int_customer_geography') }} as customers
    on orders.customer_key = customers.customer_key
group by orders.order_date, customers.region_name
