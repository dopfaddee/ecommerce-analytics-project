# E-commerce Analytics Project

Учебный проект по аналитике данных: от проектирования БД до SQL-анализа, 
Python-обработки, визуализации и A/B-тестирования.

## Статус
В процессе. Сейчас: SQL-анализ (оконные функции, CTE).

## Данные
Синтетические данные интернет-магазина, сгенерированные через Python (Faker) — не реальный бизнес, цель — отработать методологию анализа на реалистичной структуре данных.

## Структура репозитория
- `sql/create_tables.sql` — схема БД (5 таблиц: customers, products, orders, order_items, payments)
- `sql/corrupt_data.sql` — намеренное искажение части данных (дубли, пропуски, выбросы) для последующей практики очистки данных в Python
- `sql/business_tasks_practice.sql` — практика бизнес задач (в процессе)

## Инструменты
PostgreSQL, pgAdmin, Python (pandas, Faker, SQLAlchemy)

## Схема данных
customers → orders → order_items → products → payments