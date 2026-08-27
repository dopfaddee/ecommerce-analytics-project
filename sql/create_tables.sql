CREATE TABLE customers ( 
    customer_id     INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name      VARCHAR(50) NOT NULL,
    last_name       VARCHAR(50) NOT NULL,
    email           VARCHAR(255) NOT NULL UNIQUE, -- unique: 2 клиента с одинаковой почтой считаем дублем
    phone           VARCHAR(20), -- может быть null, потому что не все указывают телефон
    city            VARCHAR(100),
    signup_date     DATE NOT NULL DEFAULT CURRENT_DATE
);

CREATE TABLE products (
    product_id      INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_name    VARCHAR(200) NOT NULL,
    category        VARCHAR(100) NOT NULL,
    price           NUMERIC(10,2) NOT NULL CHECK (price >= 0), -- стоимость товара: cost с наценкой (на момент покупки)
    cost            NUMERIC(10,2) NOT NULL CHECK (cost >= 0),
    is_active       BOOLEAN NOT NULL DEFAULT TRUE -- в продаже или снят
);

CREATE TABLE orders (
    order_id        INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id     INTEGER NOT NULL REFERENCES customers(customer_id), -- привязывется к клиенту, так как заказ не может не принадлежать никому
    order_date      TIMESTAMPTZ NOT NULL DEFAULT now(),
    status          VARCHAR(20) NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending', 'completed', 'shipped', 'cancelled', 'refunded'))
);

CREATE TABLE order_items (
    order_item_id       INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id            INTEGER NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE, -- если удаляется заказ, позиции удаяются вместе с ним
    product_id          INTEGER NOT NULL REFERENCES products(product_id),
    quantity            INTEGER NOT NULL CHECK (quantity > 0),
    price_at_purchase   NUMERIC(10,2) NOT NULL CHECK (price_at_purchase >= 0)
);

CREATE TABLE payments (
    payment_id      INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id        INTEGER NOT NULL REFERENCES orders(order_id),
    payment_date    TIMESTAMPTZ NOT NULL DEFAULT now(),
    amount          NUMERIC(10,2) NOT NULL CHECK (amount > 0),
    method          VARCHAR(20) NOT NULL
                    CHECK (method IN ('credit_card', 'paypal', 'bank_transfer', 'cash'))
);