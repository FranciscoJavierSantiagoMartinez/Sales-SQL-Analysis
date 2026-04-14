-- =====================================================
-- 1. RAW TABLE CREATION
-- =====================================================

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

-- =====================================================
-- 2. DATA LOADING
-- =====================================================

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

-- =====================================================
-- 3. DATA VALIDATION
-- =====================================================

-- Duplicate transactions
SELECT transaction_id, COUNT(*) AS count
FROM walmart_raw
GROUP BY transaction_id
HAVING COUNT(*) > 1;

-- Duplicate count
SELECT COUNT(*) - COUNT(DISTINCT transaction_id) AS duplicate_count
FROM walmart_raw;

-- Null checks
SELECT 
    COUNT(*) AS total,
    SUM(customer_id IS NULL) AS null_customers,
    SUM(product_id IS NULL) AS null_products,
    SUM(transaction_date IS NULL) AS null_dates,
    SUM(unit_price IS NULL) AS null_price,
    SUM(quantity_sold IS NULL) AS null_quantity
FROM walmart_raw;

-- Range checks
SELECT MIN(unit_price), MAX(unit_price) FROM walmart_raw;
SELECT MIN(quantity_sold), MAX(quantity_sold) FROM walmart_raw;
SELECT MIN(customer_age), MAX(customer_age) FROM walmart_raw;

-- Categorical values
SELECT DISTINCT customer_gender FROM walmart_raw;
SELECT DISTINCT payment_method FROM walmart_raw;
SELECT DISTINCT weather_conditions FROM walmart_raw;

-- =====================================================
-- 4. DATA MODELING (STAR SCHEMA)
-- =====================================================

-- Customers dimension
CREATE TABLE dim_customers AS
SELECT DISTINCT
    customer_id,
    customer_age,
    customer_gender,
    customer_income,
    customer_loyalty_level
FROM walmart_raw;

-- Fact table
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

-- Products dimension
CREATE TABLE dim_products AS
SELECT DISTINCT
    product_id,
    product_name,
    category
FROM walmart_raw;

-- Stores dimension
CREATE TABLE dim_stores AS
SELECT DISTINCT
    store_id,
    store_location,
    CONCAT(store_id, '_', store_location) AS store_key
FROM walmart_raw;

-- Suppliers dimension
CREATE TABLE dim_suppliers AS
SELECT DISTINCT
    supplier_id,
    supplier_lead_time
FROM walmart_raw;

-- External factors
CREATE TABLE dim_external AS
SELECT DISTINCT
    transaction_date,
    CONCAT(store_id, '_', store_location) AS store_key,
    weather_conditions,
    weekday
FROM walmart_raw;

-- =====================================================
-- 5. BUSINESS ANALYSIS
-- =====================================================

-- Revenue by city
SELECT s.store_location, SUM(f.revenue) AS revenue 
FROM fact_sales f
JOIN dim_stores s 
ON f.store_key = s.store_key
GROUP BY s.store_location
ORDER BY revenue DESC;

-- Top-selling products
SELECT p.product_name, SUM(f.quantity_sold) AS units_sold
FROM fact_sales f
JOIN dim_products p
ON f.product_id = p.product_id
GROUP BY p.product_name
ORDER BY units_sold DESC;

-- Promotion impact
SELECT promotion_applied,
       AVG(revenue) AS avg_revenue
FROM fact_sales
GROUP BY promotion_applied;

-- Weather impact
SELECT e.weather_conditions, AVG(f.revenue) AS avg_revenue
FROM fact_sales f
JOIN dim_external e 
ON f.transaction_date = e.transaction_date
GROUP BY e.weather_conditions
ORDER BY avg_revenue DESC;

-- Customer segmentation
SELECT c.customer_loyalty_level, AVG(f.revenue) AS avg_revenue
FROM fact_sales f
JOIN dim_customers c 
ON f.customer_id = c.customer_id
GROUP BY c.customer_loyalty_level
ORDER BY avg_revenue DESC;

