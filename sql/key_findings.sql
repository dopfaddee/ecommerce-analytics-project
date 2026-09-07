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


--Концентрация выручки на топовом товаре внутри категории: TODO
--Доля клиентов с высоким Monetary, но давним Recency (риск оттока): TODO