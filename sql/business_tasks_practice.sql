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

-- Задача 7: для каждой категории посчитать кол-во уникальных проданных товаров и долю выручки самого продаваемого товара (топ-1 товар по выручке) категории от общей выручки всей категории
select distinct
	p.category,
	sum(o.quantity * o.price_at_purchase) over (partition by p.category) as category_revenue,
	o.product_id,
	sum(o.quantity) over (partition by o.product_id) as product_sales,
	sum(o.quantity * o.price_at_purchase) over (partition by o.product_id) as product_revenue,
	round((sum(o.quantity * o.price_at_purchase) over (partition by o.product_id order by o.product_id asc) * 100) / sum(o.quantity * o.price_at_purchase) over (partition by p.category), 2) as percent
from order_items o inner join products p on o.product_id = p.product_id
order by p.category asc, product_revenue desc

-- Задача 8: для каждого месяца посчитать кол-во самых первых заказов клиентов и кол-во повторных
with order_rank as(
	select
		order_id,
		customer_id,
		order_date,
		row_number() over (partition by customer_id order by order_date asc, order_id asc) as order_seq
	from orders
)

select
	date_trunc('month', order_date)::date as order_month,
	case when order_seq = 1 then 'first-timer' else 'returning' end as order_type,
	count(*) as number_of_orders
from order_rank
group by date_trunc('month', order_date)::date, case when order_seq = 1 then 'first-timer' else 'returning' end
order by order_month desc, order_type 

-- Задача 9: определить статус клиента: если потратил больше 20 000 — "VIP", если сделал 5+ заказов — "постоянный", иначе — "обычный" (при совпадении условий - VIP)
with revenue_of_order as (
	select
		o.customer_id,
		o.order_id,
		o.order_date::date as order_date,
		sum(ot.quantity * ot.price_at_purchase) as order_revenue
	from orders o 
	join order_items ot on o.order_id = ot.order_id
	group by o.customer_id, o.order_id, o.order_date
	order by o.customer_id asc
)

select 
	r.customer_id,
	count(r.order_id) as total_orders,
	sum(r.order_revenue) as total_spent,
	max(r.order_date) as last_order_date,
	case 
		when sum(r.order_revenue) > 20000 then 'VIP'
		when count(r.order_id) >= 5 then 'regular' else 'usual' end as client_status,
	c.first_name,
	c.last_name,
	c.email,
	c.phone
from revenue_of_order r join customers c on r.customer_id = c.customer_id
group by r.customer_id, c.first_name, c.last_name, c.email, c.phone
order by total_spent desc

-- Задача 10: список клиентов, чья сумма покупок превышает среднюю сумму по клиентам; кол-во и доля в общеё выручке компании
with customer_totals as (
    select
        o.customer_id,
        c.email, 
        sum(ot.quantity * ot.price_at_purchase) as user_spent
    from orders o 
    join order_items ot on o.order_id = ot.order_id
    join customers c on o.customer_id = c.customer_id
    group by o.customer_id, c.email
),
profit as (
    select 
        customer_id,
        email,
        user_spent,
        (user_spent * 100) / ((select sum(user_spent) from customer_totals)) as share_of_profit,
        (select sum(user_spent) from customer_totals) as total_spent
    from customer_totals
    where user_spent > (select avg(user_spent) from customer_totals)
)
select 
    customer_id,
    email,
	user_spent,
	round(share_of_profit,2) as user_share,
	(select round(sum(user_spent),2) from profit) as total_spent,
    (select count(customer_id) from profit) as count_of_above_avg_users,
    (select round(sum(share_of_profit),2) from profit) as total_share
from profit
where email is not null
group by customer_id, email, user_spent, share_of_profit
order by customer_id

-- Задача 11: для каждого месяца средний чек и отклонение от среднего чека за весь период в процентах (более 20% - аномальный месяц)
with avg_month_revenue as (
	select
		date_trunc('month', o.order_date)::date as order_month,
		round(sum(p.amount)/count(o.order_id), 2) as avg_month_revenue
	from payments p join orders o on p.order_id = o.order_id
	where o.order_date < date_trunc('month', now())
	group by date_trunc('month', o.order_date)::date
	order by date_trunc('month', o.order_date)::date desc
),

all_time_avg as (
	select
		round(sum(p.amount)/count(o.order_id), 2) as all_time_avg
	from payments p join orders o on p.order_id = o.order_id
	where o.order_date < date_trunc('month', now())
)

select
    m.order_month,
    m.avg_month_revenue,
    a.all_time_avg,
    round((m.avg_month_revenue - a.all_time_avg) * 100.0 / a.all_time_avg, 2) as deviation_pct,
    case 
        when abs((m.avg_month_revenue - a.all_time_avg) * 100.0 / a.all_time_avg) > 20 
        then 'anomaly' 
        else 'normal' 
    end as month_flag
from avg_month_revenue m
cross join all_time_avg a
order by m.order_month desc;

-- Задача 12: собрать полный отчёт за последние 90 дней (включая дни без платежей - где сумма 0, а не null)
