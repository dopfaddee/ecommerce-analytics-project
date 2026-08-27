-- Задача 1: все заказы каждого клиента, а также дата первого и последнего заказа
select 
    o.order_id,
    o.customer_id,
    c.first_name,
    o.order_date,
    min(o.order_date) over (partition by o.customer_id) as first_order_date,
    max(o.order_date) over (partition by o.customer_id) as last_order_date
from orders o
inner join customers c on o.customer_id = c.customer_id
order by o.customer_id, o.order_date;

-- Задача 2: для каждого товара найти его ранг по цене внутри своей категории
select
	product_id,
	product_name,
	category,
	price,
	rank() over (partition by category order by price desc) as price_rank -- у меня нет товаров с одинаковой ценой, поэтому просто использовал rank, не думая про dense_rank
from products
order by category asc, price_rank asc; -- в order by (в отличие от where) работают алиасы из select

-- проверил наличие товаров с одинаковой стоимостью (0 результатов)
select price, count(*) 
from products 
group by price 
having count(*) > 1;

-- Задача 3: для каждого клиента посчитать, сколько дней прошло между его последним и предпоследним заказом
with ranked_orders as (
	select
		customer_id,
		order_date,
		lag(order_date) over (partition by customer_id order by order_date asc, order_id asc) as prev_order_date,
		dense_rank() over (partition by customer_id order by order_date desc, order_id desc) as rn
	from orders
)

select
	customer_id,
	prev_order_date as penultimate_order_date, 
	order_date as last_order_date,
	(order_date::date - prev_order_date::date) as days_between_orders
from ranked_orders
where rn = 1 and prev_order_date is not null
order by customer_id;

-- Задача 3.5: для каждого клиента посчитать, сколько дней прошло между каждым заказом
select
    customer_id,
    order_date,
    lag(order_date) over (partition by customer_id order by order_date asc, order_id asc) as prev_order_date,
    (order_date::date - lag(order_date) over (partition by customer_id order by order_date asc, order_id asc)::date) as days_between_orders
from orders
order by customer_id, order_date;