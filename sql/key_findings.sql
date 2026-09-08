-- Доля клиентов с повторными покупками:
with total_orders as (
	select 
		customer_id, 
		count(*) as total_orders
    from orders
    group by customer_id
),

recurrent as (
	select
		count(distinct customer_id) as recurrent_customers
	from total_orders
	where total_orders > 1
)

select
	recurrent_customers,
	(select count(distinct customer_id) from orders) as all_customers,
	round(recurrent_customers * 100.0 / (select count(distinct customer_id) from orders), 1) as recurrent_customers_percent
from recurrent


--UPD: более простой и чиатемый вариант
select
    count(distinct customer_id) filter (where total_orders > 1) as recurrent_customers,
    count(distinct customer_id) as all_customers,
    round(count(distinct customer_id) filter (where total_orders > 1) * 100.0 / count(distinct customer_id), 1) as recurrent_customer_percent
from 
	(select customer_id, count(*) as total_orders
	from orders
    group by customer_id)

/*
recurrent_customers | all_customers | recurrent_customers_percent
         778	    |      799      |          97.4

Показатель в 97,4% аномально высок для реального e-commerce
и является следствием способа генерации синтетических данных — 
заказы распределялись между клиентами случайно и равномерно, без моделирования 
разницы в поведении новых и лояльных клиентов. */


--Доля выручки, которую генерирует топ-10% клиентов:
with customer_revenue as (
	select
		customer_id,
		sum(amount) as total_spent
	from payments p join orders o on p.order_id = o.order_id
	group by customer_id
),

customer_top as (
	select
		*,
		ntile(10) over (order by total_spent desc) as top_position
	from customer_revenue
)

select 
	round(sum(total_spent) filter (where top_position = 1) * 100.0/sum(total_spent), 1) as top_ten_perc_revenue_share
from customer_top
/* Результат: 
	top_ten_perc_revenue_share
			20,4%
Показатель заметно ниже типичных значений для реального e-commerce. Причина – при генерации данных
заказы распределялись между клиентами равномерно случайно, без небольшой группы очень активных клиентов. */


-- Концентрация выручки на топовом товаре внутри категории: 
with product_metrics as (
	select distinct
		p.category,
		sum(o.quantity * o.price_at_purchase) over (partition by p.category) as category_revenue,
		o.product_id,
		sum(o.quantity) over (partition by o.product_id) as product_sales,
		sum(o.quantity * o.price_at_purchase) over (partition by o.product_id) as product_revenue,
		round((sum(o.quantity * o.price_at_purchase) over (partition by o.product_id order by o.product_id asc) * 100.0) 
		/ sum(o.quantity * o.price_at_purchase) over (partition by p.category), 2) as product_share
	from order_items o inner join products p on o.product_id = p.product_id
	order by p.category asc, product_revenue desc
),

product_share as (
	select
		*,
		row_number() over (partition by category order by product_revenue desc) as product_rn
	from product_metrics
)

select * from product_share
where product_rn = 1

/* Результат:
category 	  | category_revenue | product_id | product_sales | product_revenue | product_share | product_rn
"Дом и сад"	  | 880938.69		 | 34		  | 154			  | 82058.90		| 9.31			| 1
"Книги"		  | 1464934.32		 | 114		  | 166			  | 96538.96		| 6.59			| 1
"Красота"	  | 1096504.27		 | 136		  | 155			  | 90214.65		| 8.23			| 1
"Одежда"	  | 1150226.94		 | 195		  | 144			  | 85943.52		| 7.47			| 1
"Спорт"		  | 1126673.47		 | 155		  | 149			  | 75481.91		| 6.70			| 1
"Электроника" | 1164199.44		 | 126		  | 135			  | 94964.40		| 8.16			| 1

Ни одна категория не демонстрирует критической зависимости от одного товара — распределение 
выручки внутри категорий равномерное, риск концентрации отсутствует */

-- Доля клиентов с высоким Monetary, но давним Recency (риск оттока):
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
        ntile(4) over (order by total_spent desc) as m_score,
        ntile(4) over (order by total_orders desc) as f_score,
        ntile(4) over (order by days_since_last_order asc) as r_score
    from customer_info
)

select
    round(count(*) filter (where m_score = 1 and r_score >= 3) * 100.0 / count(*), 1) as high_value_at_risk_pct
from rfm_scores

--Результат: 8.5%


-- Распределение количества клиентов по каждому RFM-сегменту:
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
	case
		when r_score + f_score + m_score <= 4 then 'champion'
		when r_score + f_score + m_score <= 7 then 'loyal'
		when r_score + f_score + m_score <= 10 then 'at risk'
		else 'lost'
	end as segment,
	count(*)
from rfm_scores
group by segment


/* Результат
segment 	| count
"lost"		| 134
"loyal"		| 273
"at risk"	| 266
"champion"	| 126

В отличие от предыдущих метрик, здесь есть содержательный сигнал: 
размер сегментов champion и lost в разы превышает ожидаемый при 
полностью случайном (независимом) распределении R/F/M (~12-13 человек при 
случайности). 

Причина не в способе генерации, а в том, что количество заказов, 
их давность и сумма трат у клиента реально связаны через логику скрипта 
*(больше заказов → выше шанс недавней покупки → больше потрачено)* — это 
отражает реалистичное поведенческое допущение, а не побочный эффект случайности.

Беру эту находку как основу для hypotheses.md.
*/