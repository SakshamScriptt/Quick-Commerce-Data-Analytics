
-- 🛒 QUICK-COMMERCE DEMAND & INVENTORY ANALYTICS - SQL SCRIPTS

 
-- 1. DATABASE SCHEMA SETUP & POSTGIS EXTENSION

CREATE EXTENSION IF NOT EXISTS postgis;

-- Drop existing tables for fresh setup
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS inventory CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS dark_stores CASCADE;

-- Create Dark Stores Table (with Spatial Data)
CREATE TABLE dark_stores (
    store_id SERIAL PRIMARY KEY,
    store_name VARCHAR(100),
    location GEOGRAPHY(POINT, 4326),
    active_status BOOLEAN
);

-- Create Products Table
CREATE TABLE products (
    product_id SERIAL PRIMARY KEY,
    product_name VARCHAR(100),
    category VARCHAR(50),
    unit_price NUMERIC(10, 2)
);

-- Create Inventory Table
CREATE TABLE inventory (
    store_id INT REFERENCES dark_stores(store_id),
    product_id INT REFERENCES products(product_id),
    stock_count INT,
    last_replenished TIMESTAMP,
    PRIMARY KEY (store_id, product_id)
);

-- Create Orders Table (with Spatial Customer Location and JSONB Items)
CREATE TABLE orders (
    order_id SERIAL PRIMARY KEY,
    store_id INT REFERENCES dark_stores(store_id),
    customer_location GEOGRAPHY(POINT, 4326),
    order_items JSONB,
    order_timestamp TIMESTAMP,
    delivery_timestamp TIMESTAMP,
    order_status VARCHAR(20)
);



-- 2. GEOSPATIAL ANALYSIS: DELIVERY RADIUS VS SLA BREACH
 
-- This query calculates the exact distance between the customer and the store
-- and checks if deliveries outside the 2km radius are causing SLA breaches.

WITH DeliveryDistances AS (
    SELECT 
        o.order_id,
        o.store_id,
        ds.store_name,
        -- PostGIS automatically calculates distance in meters for Geography types
        ST_Distance(o.customer_location, ds.location) AS distance_meters,
        EXTRACT(EPOCH FROM (o.delivery_timestamp - o.order_timestamp)) / 60 AS delivery_time_mins
    FROM orders o
    JOIN dark_stores ds ON o.store_id = ds.store_id
    WHERE o.order_status = 'Delivered'
)
SELECT 
    CASE 
        WHEN distance_meters <= 2000 THEN 'Within 2km Radius'
        ELSE 'Outside 2km Radius'
    END AS distance_category,
    COUNT(order_id) AS total_orders,
    ROUND(AVG(distance_meters)::numeric, 0) AS avg_distance_m,
    ROUND(AVG(delivery_time_mins)::numeric, 1) AS avg_delivery_mins,
    ROUND((SUM(CASE WHEN delivery_time_mins > 10 THEN 1.0 ELSE 0 END) / COUNT(*) * 100)::numeric, 2) AS late_delivery_percent
FROM DeliveryDistances
GROUP BY distance_category
ORDER BY distance_category DESC;


 
-- 3. POWER BI DASHBOARD VIEWS
 

-- View 1: Delivery Stats & Spatial Mapping
CREATE OR REPLACE VIEW vw_powerbi_delivery_stats AS
SELECT 
    o.order_id,
    ds.store_name,
    DATE(o.order_timestamp) AS order_date,
    EXTRACT(HOUR FROM o.order_timestamp) AS order_hour,
    EXTRACT(EPOCH FROM (o.delivery_timestamp - o.order_timestamp)) / 60 AS delivery_mins,
    CASE WHEN (EXTRACT(EPOCH FROM (o.delivery_timestamp - o.order_timestamp)) / 60) > 10 THEN 1 ELSE 0 END AS is_late,
    ST_Y(o.customer_location::geometry) AS cust_lat,
    ST_X(o.customer_location::geometry) AS cust_lon
FROM orders o
JOIN dark_stores ds ON o.store_id = ds.store_id;


-- View 2: Critical Inventory Alerts (Daily Burn Rate Logic)
DROP VIEW IF EXISTS vw_powerbi_inventory_alerts CASCADE;

CREATE VIEW vw_powerbi_inventory_alerts AS
WITH OrderItems AS (
    SELECT 
        store_id, 
        (jsonb_array_elements(order_items)->>'product_id')::INT AS product_id,
        (jsonb_array_elements(order_items)->>'qty')::INT AS qty
    FROM orders
)
SELECT 
    ds.store_name,
    p.product_name,
    p.category,
    i.stock_count AS current_stock,
    COALESCE(SUM(oi.qty), 0) AS total_sold,
    -- Daily average burn rate used to calculate hours to stockout
    ROUND(
        (i.stock_count / NULLIF(COALESCE(SUM(oi.qty), 0) / (30.0 * 24.0), 0))::numeric, 
        1
    ) AS hours_to_stockout
FROM inventory i
JOIN products p ON i.product_id = p.product_id
JOIN dark_stores ds ON i.store_id = ds.store_id
LEFT JOIN OrderItems oi ON i.store_id = oi.store_id AND i.product_id = oi.product_id
GROUP BY ds.store_name, p.product_name, p.category, i.stock_count;