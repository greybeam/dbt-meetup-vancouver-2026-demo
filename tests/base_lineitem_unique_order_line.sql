select
    order_key,
    line_number
from {{ ref('base_lineitem') }}
group by order_key, line_number
having count(*) > 1
