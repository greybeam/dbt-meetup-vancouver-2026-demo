select
    order_date,
    region_name
from {{ ref('fct_daily_revenue_by_region') }}
group by order_date, region_name
having count(*) > 1
