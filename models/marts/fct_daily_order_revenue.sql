select
    order_date,
    count(*) as order_count,
    sum(order_revenue){{ money() }} as order_revenue
from {{ ref('int_order_revenue') }}
group by order_date
