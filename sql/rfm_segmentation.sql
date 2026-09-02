/* Разделить всю клиентскую базу на сегменты по трём параметрам сразу: 
насколько недавно клиент покупал, как часто он покупает, и сколько денег в целом приносит.
Полноценная модель, чтобы можно было, например, выделить клиентов, которые раньше много 
тратили, но давно не появлялись и таргетировать их отдельно от остальных. */

/* 
Классическая RFM-модель:
- R (Recency) — сколько дней прошло с последнего заказа (меньше — лучше)
- F (Frequency) — сколько всего заказов сделал клиент
- M (Monetary) — сколько всего денег потратил  
*/

with customer_info as (
    select
        o.customer_id,
        (select max(order_date::date) from orders) - max(o.order_date::date) as days_since_last_order,
        count(distinct o.order_id) as total_orders,
        coalesce(sum(p.amount), 0) as total_spent
    from orders o
    left join payments p on o.order_id = p.order_id
    group by o.customer_id
),

rfm_scores as (
    select
        customer_id,
        ntile(4) over (order by days_since_last_order asc) as r_score,
        ntile(4) over (order by total_orders desc) as f_score,
        ntile(4) over (order by total_spent desc) as m_score
    from customer_info
)

select 
	customer_id,
	r_score,
	f_score,
	m_score,
	r_score + f_score + m_score as total_score,
	case
		when r_score + f_score + m_score <= 4 then 'champion'
		when r_score + f_score + m_score <= 7 then 'loyal'
		when r_score + f_score + m_score <= 10 then 'at risk'
		else 'lost'
	end as segment
from rfm_scores
order by total_score asc

/* Есть и другой вариант сегментации:
case
        when r_score = 1 and f_score <= 2 and m_score <= 2 then 'champion'      Недавно покупал, и при этом стабильно в верхней половине по частоте и деньгам - самый ценный тип клиента
        when r_score <= 2 and f_score <= 2 and m_score <= 2 then 'loyal'
        when r_score = 1 and f_score >= 3 then 'new_customer'                   Покупал совсем недавно, но пока мало заказов - скорее всего новый клиент ещё не успевший показать себя
        when r_score >= 3 and f_score <= 2 and m_score <= 2 then 'at_risk'      Раньше был активным и много тратил, но давно не появлялся - под угрозой оттока
        when r_score = 4 and f_score = 4 and m_score = 4 then 'lost'            Плох по всем трём метрикам - потерян
        else 'needs_attention'
    end as segment
*/