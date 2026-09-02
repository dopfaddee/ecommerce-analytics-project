-- EXPLAIN показывает этот план без реального выполнения запроса (просто прогноз), 
-- а EXPLAIN ANALYZE — реально выполняет запрос и показывает план вместе с фактическим временем на каждом шаге

explain analyze
select * from orders where customer_id = 42

/*  Результат:
"Bitmap Heap Scan on orders  (cost=4.34..23.84 rows=8 width=25) (actual time=0.034..0.042 rows=8.00 loops=1)"                       Ушло всего 0,042 секунды на примерно 4000 строк
"  Recheck Cond: (customer_id = 42)"
"  Heap Blocks: exact=8"
"  Buffers: shared hit=10"
"  ->  Bitmap Index Scan on idx_orders_customer_id  (cost=0.00..4.34 rows=8 width=0) (actual time=0.019..0.019 rows=8.00 loops=1)"          
"        Index Cond: (customer_id = 42)"
"        Index Searches: 1"
"        Buffers: shared hit=2"
"Planning Time: 0.099 ms"
"Execution Time: 0.062 ms"                                                                                                          Итоговое время выполнения всего запроса */



-- Удаление индекса и повторный прогон
drop index idx_orders_customer_id;

explain analyze
select * from orders where customer_id = 42

/* Результат:
"Seq Scan on orders  (cost=0.00..79.00 rows=8 width=25) (actual time=0.029..0.240 rows=8.00 loops=1)"
"  Filter: (customer_id = 42)"
"  Rows Removed by Filter: 3995"
"  Buffers: shared hit=29"
"Planning:"
"  Buffers: shared hit=5"
"Planning Time: 0.749 ms"
"Execution Time: 0.254 ms" */ 

/* Без индексов на соответствие условиям проверяется каждая строка, что занимает значительно больше времени.

С индексом (Bitmap)	                   |   Без индекса (Seq Scan)
---------------------------------------|----------------------------
Тип скана	Bitmap Index + Heap Scan   |  Seq Scan
Buffers (прочитано блоков)	10	       |  29
Execution Time	0.062 ms	           |  0.254 ms
Строк проверено	8 (сразу нашёл нужные) |  4003 (проверил вообще все) 
*/

-- ИТОГ:
-- Индекс не ускоряет сам факт чтения одной строки — он ускоряет поиск нужных строк среди множества ненужных. 
-- Чем больше в таблице "ненужных" (не подходящих под условие) строк относительно "нужных" — тем больше выигрыш от индекса.



-- Вернул индекс
create index idx_orders_customer_id on orders(customer_id)