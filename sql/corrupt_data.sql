INSERT INTO orders (customer_id, order_date, status)
SELECT customer_id, order_date, status
FROM orders
WHERE order_id IN (10, 25, 42) 
LIMIT 3;

ALTER TABLE customers ALTER COLUMN email DROP NOT NULL;

UPDATE customers
SET email = NULL
WHERE customer_id IN (5, 17, 33);

UPDATE order_items
SET quantity = 500
WHERE order_item_id = 100;

DELETE FROM payments
WHERE order_id = 50;