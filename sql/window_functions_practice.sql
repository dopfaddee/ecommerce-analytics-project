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

-- Задача 4: посчитать накопительную (running total) выручку по дням
with daily_totals as (
    select
        payment_date::date as payment_day,
        sum(amount) as daily_total
    from payments
    group by payment_date::date
)
select 
    payment_day,
    daily_total,
    sum(daily_total) over (order by payment_day) as running_total
from daily_totals
order by payment_day

-- Задача 5: список клиентов (+ email), у которых 3+ заказов, но с последнего прошло >30 дней
select
    c.customer_id,
    c.first_name,
    c.email,
    count(o.order_id) as n_of_orders,
    max(o.order_date)::date as last_order_date,
    (now()::date - max(o.order_date)::date) as days_since_last_order
from orders o inner join customers c on o.customer_id = c.customer_id
where c.email is not null
group by c.customer_id, c.first_name, c.email
having count(o.order_id) >= 3 and (now()::date - max(o.order_date)::date) > 30
order by c.customer_id;

-- Задача 6: месячная выручка (сумма всех платежей) со сравнением месяц к месяцу
select
	date_trunc('month', o.order_date)::date as order_month,
	sum(p.amount) as sales,
	lag(sum(p.amount)) over (order by date_trunc('month', o.order_date)) as last_month_sales,
	sum(p.amount) - lag(sum(p.amount)) over (order by date_trunc('month', o.order_date)) as sales_diff
from orders o inner join payments p on o.order_id = p.order_id
where o.order_date < date_trunc('month', now()) -- обрезается текущий (неполный) месяц
group by date_trunc('month', o.order_date)
order by order_month desc

-- Задача 7: Для каждой категории посчитать кол-во уникальных проданных товаров и долю выручки самого продаваемого товара (топ-1 товар по выручке) категории от общей выручки всей категории
select distinct
	p.category,
	sum(o.quantity * o.price_at_purchase) over (partition by p.category) as category_revenue,
	o.product_id,
	sum(o.quantity) over (partition by o.product_id) as product_sales,
	sum(o.quantity * o.price_at_purchase) over (partition by o.product_id) as product_revenue,
	round((sum(o.quantity * o.price_at_purchase) over (partition by o.product_id order by o.product_id asc) * 100) / sum(o.quantity * o.price_at_purchase) over (partition by p.category), 2) as percent
from order_items o inner join products p on o.product_id = p.product_id
order by p.category asc, product_revenue desc