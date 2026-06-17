CREATE DATABASE IF NOT EXISTS darkstore_db;
USE darkstore_db;

CREATE TABLE dark_stores (
  store_id          INT PRIMARY KEY,
  store_name        VARCHAR(100),
  city              VARCHAR(50),
  pincode           VARCHAR(10),
  zone              VARCHAR(30),
  monthly_rent      DECIMAL(10,2),
  staff_count       INT,
  opened_date       DATE,
  status            VARCHAR(20)
);

CREATE TABLE skus (
  sku_id            INT PRIMARY KEY,
  product_name      VARCHAR(200),
  aisle             VARCHAR(100),
  department        VARCHAR(100),
  cost_price        DECIMAL(8,2),
  selling_price     DECIMAL(8,2),
  is_perishable     BOOLEAN,
  shelf_life_days   INT
);

CREATE TABLE orders_tbl (
  order_id          INT PRIMARY KEY,
  store_id          INT,
  pincode           VARCHAR(10),
  order_dow         INT,
  order_hour        INT,
  order_date        DATE,
  days_since_prior  INT,
  delivery_status   VARCHAR(20),
  delivery_minutes  INT,
  is_split          BOOLEAN,
  FOREIGN KEY (store_id) REFERENCES dark_stores(store_id)
);

CREATE TABLE order_items (
  id                INT AUTO_INCREMENT PRIMARY KEY,
  order_id          INT,
  sku_id            INT,
  quantity          INT,
  fulfilled         BOOLEAN,
  reordered         BOOLEAN,
  FOREIGN KEY (order_id) REFERENCES orders_tbl(order_id),
  FOREIGN KEY (sku_id)   REFERENCES skus(sku_id)
);

CREATE TABLE delivery_costs (
  delivery_id       INT AUTO_INCREMENT PRIMARY KEY,
  order_id          INT,
  store_id          INT,
  rider_cost        DECIMAL(8,2),
  distance_km       DECIMAL(5,2),
  delivery_date     DATE,
  FOREIGN KEY (order_id) REFERENCES orders_tbl(order_id)
);

CREATE TABLE store_inventory (
  store_id          INT,
  sku_id            INT,
  quantity_on_hand  INT,
  last_restocked    DATE,
  PRIMARY KEY (store_id, sku_id),
  FOREIGN KEY (store_id) REFERENCES dark_stores(store_id),
  FOREIGN KEY (sku_id)   REFERENCES skus(sku_id)
);

USE darkstore_db;
SET SQL_SAFE_UPDATES = 0;
DELETE FROM delivery_costs;
DELETE FROM order_items;
DELETE FROM orders_tbl;
DELETE FROM store_inventory;
DELETE FROM skus;
DELETE FROM dark_stores;
SET SQL_SAFE_UPDATES = 1;
USE darkstore_db;
SET SQL_SAFE_UPDATES = 0;
DELETE FROM delivery_costs;
DELETE FROM order_items;
DELETE FROM orders_tbl;
DELETE FROM store_inventory;
DELETE FROM skus;
DELETE FROM dark_stores;
SET SQL_SAFE_UPDATES = 1;
USE darkstore_db;
SET SQL_SAFE_UPDATES = 0;
SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE delivery_costs;
TRUNCATE TABLE order_items;
TRUNCATE TABLE orders_tbl;
TRUNCATE TABLE store_inventory;
TRUNCATE TABLE skus;
TRUNCATE TABLE dark_stores;
SET FOREIGN_KEY_CHECKS = 1;
SET SQL_SAFE_UPDATES = 1;
USE darkstore_db;
SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE delivery_costs;
TRUNCATE TABLE order_items;
TRUNCATE TABLE orders_tbl;
TRUNCATE TABLE store_inventory;
TRUNCATE TABLE skus;
TRUNCATE TABLE dark_stores;
SET FOREIGN_KEY_CHECKS = 1;
USE darkstore_db;
SELECT 'dark_stores'    AS table_name, COUNT(*) AS rows FROM dark_stores
UNION ALL
SELECT 'skus',           COUNT(*) FROM skus
UNION ALL
SELECT 'orders_tbl',     COUNT(*) FROM orders_tbl
UNION ALL
SELECT 'order_items',    COUNT(*) FROM order_items
UNION ALL
SELECT 'delivery_costs', COUNT(*) FROM delivery_costs
UNION ALL
SELECT 'store_inventory',COUNT(*) FROM store_inventory;
USE darkstore_db;
SELECT 'dark_stores'     AS table_name, COUNT(*) AS rows FROM dark_stores
UNION ALL
SELECT 'skus',            COUNT(*) FROM skus
UNION ALL
SELECT 'orders_tbl',      COUNT(*) FROM orders_tbl
UNION ALL
SELECT 'order_items',     COUNT(*) FROM order_items
UNION ALL
SELECT 'delivery_costs',  COUNT(*) FROM delivery_costs
UNION ALL
SELECT 'store_inventory', COUNT(*) FROM store_inventory;
USE darkstore_db;
SELECT COUNT(*) FROM dark_stores;
SELECT COUNT(*) FROM skus;
SELECT COUNT(*) FROM orders_tbl;
SELECT COUNT(*) FROM order_items;
SELECT COUNT(*) FROM delivery_costs;
SELECT COUNT(*) FROM store_inventory;