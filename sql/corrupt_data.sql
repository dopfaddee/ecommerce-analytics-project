-- дублирование заказов: имитация ситуации, когда пользователь
-- случайно оформил один и тот же заказ дважды (например, повторный клик)
INSERT INTO orders (customer_id, order_date, status)
SELECT customer_id, order_date, status
FROM orders
WHERE order_id IN (10, 25, 42) 
LIMIT 3;


-- обнуление email у части клиентов: имитация неполных данных,
-- например, если email не был обязательным полем на старой версии формы регистрации
ALTER TABLE customers ALTER COLUMN email DROP NOT NULL;

UPDATE customers
SET email = NULL
WHERE customer_id IN (5, 17, 33);


-- аномально большой заказ
UPDATE order_items
SET quantity = 500
WHERE order_item_id = 100;


-- удаление платежа
DELETE FROM payments
WHERE order_id = 50;