use midb;


CREATE TABLE walmart_raw (
    transaction_id INT,
    customer_id INT,
    product_id INT,
    product_name VARCHAR(255),
    category VARCHAR(100),
    quantity_sold INT,
    unit_price DECIMAL(10,2),
    transaction_date DATE,
    store_id INT,
    store_location VARCHAR(100),
    inventory_level INT,
    reorder_point INT,
    reorder_quantity INT,
    supplier_id INT,
    supplier_lead_time INT,
    customer_age INT,
    customer_gender VARCHAR(10),
    customer_income DECIMAL(10,2),
    customer_loyalty_level VARCHAR(50),
    payment_method VARCHAR(50),
    promotion_applied BOOLEAN,
    promotion_type VARCHAR(50),
    weather_conditions VARCHAR(50),
    holiday_indicator BOOLEAN,
    weekday VARCHAR(20),
    stockout_indicator BOOLEAN,
    forecasted_demand INT,
    actual_demand INT
);

LOAD DATA LOCAL INFILE '"C:\Users\javim\Downloads\Walmart.csv"'
INTO TABLE walmart_raw
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(transaction_id, customer_id, product_id, product_name, category,
 quantity_sold, unit_price, @date, store_id, store_location,
 inventory_level, reorder_point, reorder_quantity, supplier_id,
 supplier_lead_time, customer_age, customer_gender, customer_income,
 customer_loyalty_level, payment_method, promotion_applied,
 promotion_type, weather_conditions, holiday_indicator, weekday,
 stockout_indicator, forecasted_demand, actual_demand)
SET transaction_date = STR_TO_DATE(@date, '%Y-%m-%d');

SHOW VARIABLES LIKE 'secure_file_priv';

SET GLOBAL local_infile = 1;

TRUNCATE TABLE walmart_raw;

SELECT COUNT(*) FROM walmart_raw;

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/Walmart.csv'
INTO TABLE walmart_raw
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(transaction_id, customer_id, product_id, product_name, category,
 quantity_sold, unit_price, @date, store_id, store_location,
 inventory_level, reorder_point, reorder_quantity, supplier_id,
 supplier_lead_time, customer_age, customer_gender, customer_income,
 customer_loyalty_level, payment_method, @promotion_applied,
 promotion_type, weather_conditions, @holiday_indicator, weekday,
 @stockout_indicator, forecasted_demand, actual_demand)
SET 
transaction_date = STR_TO_DATE(@date, '%m/%d/%Y %H:%i'),
promotion_applied = IF(@promotion_applied = 'TRUE', 1, 0),
holiday_indicator = IF(@holiday_indicator = 'TRUE', 1, 0),
stockout_indicator = IF(@stockout_indicator = 'TRUE', 1, 0);

Select * from products;

CREATE TABLE dim_customers AS
SELECT DISTINCT
    customer_id,
    customer_age,
    customer_gender,
    customer_income,
    customer_loyalty_level
FROM walmart_raw;

SELECT * FROM dim_customers;

CREATE TABLE fact_sales AS
SELECT
    transaction_id,
    customer_id,
    product_id,
    store_id,
    transaction_date,
    quantity_sold,
    unit_price,
    (quantity_sold * unit_price) AS revenue,
    promotion_applied,
    holiday_indicator,
    stockout_indicator,
    forecasted_demand,
    actual_demand
FROM walmart_raw;

-- estos aun no se han hecho, hay que probar

CREATE TABLE dim_products AS
SELECT DISTINCT
    product_id,
    product_name,
    category
FROM walmart_raw;

CREATE TABLE dim_stores AS
SELECT DISTINCT
    store_id,
    store_location
FROM walmart_raw;

CREATE TABLE dim_suppliers AS
SELECT DISTINCT
    supplier_id,
    supplier_lead_time
FROM walmart_raw;

DROP TABLE dim_external;

CREATE TABLE dim_external AS
SELECT DISTINCT
    transaction_date,
	CONCAT(store_id, '_', store_location) AS store_key,
    weather_conditions,
    weekday
FROM walmart_raw;

SELECT * FROM dim_external;

SHOW TABLES;

Select * FROM fact_sales;

Select * FROM dim_products;

-- ver que no haya repeticiones y nulos y rangos 

SELECT transaction_id, COUNT(*) AS veces
FROM walmart_raw
GROUP BY transaction_id
HAVING COUNT(*) > 1;

SELECT COUNT(*) - COUNT(DISTINCT transaction_id) AS duplicados
FROM walmart_raw;

SELECT 
    COUNT(*) AS total,
    SUM(customer_id IS NULL) AS null_customers,
    SUM(product_id IS NULL) AS null_products,
    SUM(transaction_date IS NULL) AS null_dates,
    SUM(unit_price IS NULL) AS null_price,
    SUM(quantity_sold IS NULL) AS null_quantity
FROM walmart_raw;

SELECT 
    MIN(unit_price) AS min_price,
    MAX(unit_price) AS max_price
FROM walmart_raw;


SELECT 
    MIN(quantity_sold) AS min_q,
    MAX(quantity_sold) AS max_q
FROM walmart_raw;


SELECT 
    MIN(customer_age) AS min_age,
    MAX(customer_age) AS max_age
FROM walmart_raw;

SELECT DISTINCT customer_gender FROM walmart_raw;
SELECT DISTINCT payment_method FROM walmart_raw;
SELECT DISTINCT weather_conditions FROM dim_external;
-- ---------------------------------------------------------------------------------------------
-- consultas de utilidad 
-- que tienda genera mas ingresos?

SELECT s.store_location, SUM(f.revenue) AS revenue 
FROM fact_sales f
JOIN dim_stores s 
ON f.store_id = s.store_id
Group by s.store_location
ORDER BY revenue DESC;


SELECT store_id, SUM(revenue)
FROM fact_sales
GROUP BY store_id;

SELECT store_id, COUNT(*) 
FROM dim_stores
GROUP BY store_id
HAVING COUNT(*) > 1;

SELECT * FROM dim_stores;

SELECT store_id, COUNT(*) 
FROM walmart_raw
GROUP BY store_id;

SELECT COUNT(DISTINCT store_id) FROM walmart_raw;
-- ---------------------------------------------------------------------------- correcto

DROP TABLE dim_stores;

CREATE TABLE dim_stores AS
SELECT DISTINCT
    store_id,
    store_location,
    CONCAT(store_id, '_', store_location) AS store_key
FROM walmart_raw;

DROP TABLE fact_sales;

CREATE TABLE fact_sales AS
SELECT
    transaction_id,
    customer_id,
    product_id,
    CONCAT(store_id, '_', store_location) AS store_key,
    transaction_date,
    quantity_sold,
    unit_price,
    (quantity_sold * unit_price) AS revenue,
    promotion_applied,
    holiday_indicator,
    stockout_indicator,
    forecasted_demand,
    actual_demand
FROM walmart_raw;

SELECT * FROM dim_stores ;

SELECT * FROM fact_sales ;


SELECT s.store_location, SUM(f.revenue) AS revenue 
FROM fact_sales f
JOIN dim_stores s 
ON f.store_key = s.store_key
Group by s.store_location
ORDER BY revenue DESC;

-- 
-- Total base
SELECT SUM(revenue) FROM fact_sales;

-- Total con join
SELECT SUM(f.revenue)
FROM fact_sales f
JOIN dim_stores s 
ON f.store_key = s.store_key;
--


-- Los angeles cuentan con los mayores ingresos, esto abre la oportunidad de replicar los resultados en las demas ubicaciones. 


-- ¿Que productos venden mas?
SELECT p.product_name AS PRODUCT, SUM(f.quantity_sold) AS 'Units Sold'
FROM fact_sales f
JOIN dim_products p
ON f.product_id = p.product_id
GROUP BY p.product_name 
ORDER BY SUM(f.quantity_sold) DESC;

-- las tablets resultan el producto mas vendido, de hecho los productos de categoria electronica estan encima de otras categorias, esto puede ser una oportunidad de crecimiento en ventas en las distintas sucursales


-- ¿Las promociones funcionan? aqui ver si la existencia de promociones genera que haya mas ventas en productos? especificos

SELECT promotion_applied,
       AVG(revenue) AS avg_revenue
FROM fact_sales
GROUP BY promotion_applied;

-- las promociones muestran un resultado favorable, lo que indica que se deben priorizar y mantener las estrategias de marketing

-- ¿el clima afecta ventas?
SELECT e.weather_conditions, AVG(f.revenue) AS avg_revenue
FROM fact_sales f
JOIN dim_external e 
ON f.transaction_date = e.transaction_date
GROUP BY e.weather_conditions
ORDER BY avg_revenue DESC;

-- los clientes gastan mas en condiciones lluviosas, esto resalta el aumento de necesidades en estas situaciones. 

-- ¿que tipo de cliente gasta mas?
SELECT c.customer_loyalty_level, AVG(f.revenue) AS avg_revenue
FROM fact_sales f
JOIN dim_customers c 
ON f.customer_id = c.customer_id
GROUP BY c.customer_loyalty_level
ORDER BY avg_revenue DESC;

-- Los clientes platino gastan muy por encima de los demas clientes, esto supone una gran ventaja al contemplar y reconocer su fidelidad.

-- ---------------------------------------------------------------------- INSIGHTS

-- “La tienda de Los Ángeles concentra el mayor ingreso total, lo que sugiere un desempeño superior posiblemente 
-- asociado a mayor demanda o eficiencia operativa. Esto representa una oportunidad para analizar y replicar estrategias en otras ubicaciones.”

-- “Las tablets lideran en volumen de ventas, y en general la categoría de electrónicos domina sobre otras, lo que indica una alta demanda 
-- en este segmento y una oportunidad para optimizar inventario y estrategias comerciales enfocadas en esta categoría.”

-- “Las promociones están asociadas con un mayor ingreso promedio por transacción, lo que indica un impacto positivo en ventas
--  y respalda la continuidad y optimización de estrategias promocionales.”

-- “Las ventas aumentan en condiciones lluviosas, lo que sugiere que factores externos como el clima influyen en el comportamiento de 
-- compra, posiblemente impulsando la demanda de ciertos productos.”

-- “Los clientes con nivel de lealtad ‘Platinum’ presentan un gasto significativamente mayor que otros segmentos, lo que resalta el valor de los programas de 
-- fidelización y la importancia de estrategias dirigidas a retención de clientes de alto valor.”


-- -------------------------------------------------------------------------------


SELECT SUM(quantity_sold) FROM fact_sales;

--

SELECT transaction_date, store_id, store_location, weather_conditions FROM walmart_raw
ORDER BY store_location, transaction_date;

SELECT product_id, COUNT(*)
FROM dim_products
GROUP BY product_id
HAVING COUNT(*) > 1;


SELECT CONCAT(product_id, '_', product_name) AS id_prod FROM dim_products
ORDER BY product_id;

SELECT CONCAT(product_id, '_', product_name) AS id_prod FROM dim_products
ORDER BY product_id;
