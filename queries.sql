-- ============================================================
-- DARK STORE PROFITABILITY COLLAPSE TRACKER
-- Grounded in Dunzo's documented failure (Jan 2025)
-- Dataset: Instacart Market Basket + Synthetic cost layer
-- ============================================================

USE darkstore_db;

-- ============================================================
-- CORE QUERY 1: Store Ramp-up Trajectory
-- Identifies stores stalling below break-even threshold
-- Dunzo pattern: peripheral stores never ramped up
-- ============================================================

SELECT
  ds.store_id,
  ds.store_name,
  ds.city,
  COUNT(o.order_id)                                    AS total_orders,
  DATEDIFF(MAX(o.order_date), MIN(o.order_date))       AS days_active,
  ROUND(COUNT(o.order_id) /
    NULLIF(DATEDIFF(MAX(o.order_date),
           MIN(o.order_date)), 0), 1)                  AS avg_orders_per_day,
  MIN(o.order_date)                                    AS first_order,
  MAX(o.order_date)                                    AS last_order,
  ROUND(AVG(o.week_weight), 2)                         AS avg_ramp_score,
  CASE
    WHEN ds.store_id >= 31
     AND ROUND(AVG(o.week_weight), 2) < 0.6            THEN 'STALLING — Dunzo pattern'
    WHEN ds.store_id >= 31                              THEN 'PERIPHERAL — MONITOR'
    WHEN ROUND(AVG(o.week_weight), 2) >= 3.0            THEN 'ABOVE BREAK-EVEN'
    WHEN ROUND(AVG(o.week_weight), 2) >= 1.5            THEN 'RECOVERING'
    ELSE                                                     'EARLY STAGE'
  END                                                  AS dunzo_risk_signal
FROM orders_tbl o
JOIN dark_stores ds ON o.store_id = ds.store_id
WHERE o.delivery_status = 'delivered'
GROUP BY ds.store_id, ds.store_name, ds.city
ORDER BY avg_ramp_score ASC;


-- ============================================================
-- CORE QUERY 2: SKU Co-occurrence Gap
-- Finds SKU pairs always ordered together but never co-stocked
-- Quantifies annual revenue at risk from split deliveries
-- ============================================================

SELECT
  s1.product_name                              AS product_a,
  s2.product_name                              AS product_b,
  COUNT(*)                                     AS times_ordered_together,
  ROUND(COUNT(*) * 450 * 0.30 * 12 / 1000, 1) AS annual_revenue_at_risk_k_inr
FROM order_items a
JOIN order_items b
  ON  a.order_id = b.order_id
  AND a.sku_id < b.sku_id
JOIN skus s1 ON a.sku_id = s1.sku_id
JOIN skus s2 ON b.sku_id = s2.sku_id
WHERE a.fulfilled = TRUE
  AND b.fulfilled = TRUE
GROUP BY a.sku_id, b.sku_id, s1.product_name, s2.product_name
HAVING times_ordered_together >= 40
ORDER BY times_ordered_together DESC
LIMIT 20;


-- ============================================================
-- CORE QUERY 3: Pin Code Cancellation Signal
-- High cancellation + high demand = competitor entry risk
-- ============================================================


-- ============================================================
-- CORE QUERY 4: Fully-Loaded Store P&L
-- Rent + staff + rider costs + COGS vs revenue per store
-- Dunzo calibration: loss_per_order near -₹230 = critical
-- ============================================================

SELECT
  ds.store_id,
  ds.store_name,
  ds.city,
  ds.monthly_rent,
  COUNT(DISTINCT o.order_id)                           AS delivered_orders,
  ROUND(SUM(oi.quantity * s.selling_price), 0)         AS gross_revenue,
  ROUND(SUM(oi.quantity * s.cost_price), 0)            AS total_cogs,
  ROUND(SUM(dc.rider_cost), 0)                         AS total_delivery_cost,
  ROUND(ds.monthly_rent * 3, 0)                        AS rent_90_days,
  ROUND(ds.staff_count * 12000 * 3, 0)                 AS staff_cost_90_days,
  ROUND(
    SUM(oi.quantity * (s.selling_price - s.cost_price))
    - SUM(dc.rider_cost)
    - (ds.monthly_rent * 3)
    - (ds.staff_count * 12000 * 3)
  , 0)                                                 AS net_contribution,
  ROUND(
    (SUM(oi.quantity * (s.selling_price - s.cost_price))
    - SUM(dc.rider_cost)
    - (ds.monthly_rent * 3)
    - (ds.staff_count * 12000 * 3))
    / NULLIF(COUNT(DISTINCT o.order_id), 0)
  , 0)                                                 AS profit_loss_per_order
FROM dark_stores ds
JOIN orders_tbl o   ON ds.store_id = o.store_id
JOIN order_items oi ON o.order_id  = oi.order_id
JOIN skus s         ON oi.sku_id   = s.sku_id
JOIN delivery_costs dc ON o.order_id = dc.order_id
WHERE o.delivery_status = 'delivered'
  AND oi.fulfilled = TRUE
GROUP BY ds.store_id, ds.store_name, ds.city,
         ds.monthly_rent, ds.staff_count
ORDER BY net_contribution ASC;


-- ============================================================
-- CORE QUERY 5: Perishable Waste Detector
-- Invisible P&L leak — expired stock sitting on shelves
-- ============================================================

SELECT
  ds.store_name,
  ds.city,
  s.product_name,
  s.department,
  si.quantity_on_hand,
  si.last_restocked,
  s.shelf_life_days,
  DATEDIFF(CURDATE(), si.last_restocked)       AS days_since_restock,
  ROUND(si.quantity_on_hand * s.cost_price, 0) AS waste_value_inr
FROM store_inventory si
JOIN dark_stores ds ON si.store_id = ds.store_id
JOIN skus s         ON si.sku_id   = s.sku_id
WHERE s.is_perishable = TRUE
  AND si.quantity_on_hand > 0
  AND DATEDIFF(CURDATE(), si.last_restocked) >= s.shelf_life_days
ORDER BY waste_value_inr DESC
LIMIT 20;


-- ============================================================
-- CORE QUERY 6: Monday Morning Action Table
-- CLOSE / RESTRUCTURE / MONITOR / SCALE per store
-- The final deliverable — ranked by urgency
-- ============================================================

SELECT
  ds.store_id,
  ds.store_name,
  ds.city,
  COUNT(DISTINCT o.order_id)                        AS delivered_orders,
  ROUND(COUNT(DISTINCT o.order_id) / 90.0, 0)       AS avg_orders_per_day,
  ROUND(
    SUM(oi.quantity * (s.selling_price - s.cost_price))
    - SUM(dc.rider_cost)
    - (ds.monthly_rent * 3)
    - (ds.staff_count * 12000 * 3)
  , 0)                                              AS net_contribution,
  ROUND(
    (SUM(oi.quantity * (s.selling_price - s.cost_price))
    - SUM(dc.rider_cost)
    - (ds.monthly_rent * 3)
    - (ds.staff_count * 12000 * 3))
    / NULLIF(COUNT(DISTINCT o.order_id), 0)
  , 0)                                              AS loss_per_order,
  ROUND(ds.monthly_rent * 3, 0)                     AS sunk_rent_90d,
  CASE
    WHEN ROUND(AVG(o.week_weight), 2) < 0.6
     AND ROUND(
           (SUM(oi.quantity * (s.selling_price - s.cost_price))
           - SUM(dc.rider_cost)
           - (ds.monthly_rent * 3)
           - (ds.staff_count * 12000 * 3))
           / NULLIF(COUNT(DISTINCT o.order_id), 0)
         , 0) < -800
    THEN 'CLOSE IMMEDIATELY'
    WHEN ROUND(AVG(o.week_weight), 2) < 1.5
     AND ROUND(
           (SUM(oi.quantity * (s.selling_price - s.cost_price))
           - SUM(dc.rider_cost)
           - (ds.monthly_rent * 3)
           - (ds.staff_count * 12000 * 3))
           / NULLIF(COUNT(DISTINCT o.order_id), 0)
         , 0) < -500
    THEN 'RESTRUCTURE — Cut SKUs and staff'
    WHEN ROUND(AVG(o.week_weight), 2) BETWEEN 1.5 AND 2.9
    THEN 'MONITOR — Reassess in 4 weeks'
    WHEN ROUND(AVG(o.week_weight), 2) >= 3.0
    THEN 'SCALE — Add inventory and riders'
    ELSE 'REVIEW MANUALLY'
  END                                               AS recommendation
FROM dark_stores ds
JOIN orders_tbl o   ON ds.store_id = o.store_id
JOIN order_items oi ON o.order_id  = oi.order_id
JOIN skus s         ON oi.sku_id   = s.sku_id
JOIN delivery_costs dc ON o.order_id = dc.order_id
WHERE o.delivery_status = 'delivered'
  AND oi.fulfilled = TRUE
GROUP BY ds.store_id, ds.store_name, ds.city,
         ds.monthly_rent, ds.staff_count
ORDER BY
  CASE recommendation
    WHEN 'CLOSE IMMEDIATELY' THEN 1
    WHEN 'RESTRUCTURE — Cut SKUs and staff' THEN 2
    WHEN 'MONITOR — Reassess in 4 weeks' THEN 3
    WHEN 'SCALE — Add inventory and riders' THEN 4
    ELSE 5
  END;


-- ============================================================
-- IMPROVISATION 1: AOV Decomposition by Store
-- Diagnoses WHY stores lose money — rider cost vs low AOV
-- Finding: problem is rider cost (₹148-174), not low AOV
-- ============================================================

SELECT
  ds.store_id,
  ds.store_name,
  ds.city,
  COUNT(DISTINCT o.order_id)                          AS total_orders,
  ROUND(
    SUM(oi.quantity * s.selling_price)
    / COUNT(DISTINCT o.order_id)
  , 0)                                                AS aov_inr,
  ROUND(
    SUM(oi.quantity)
    / COUNT(DISTINCT o.order_id)
  , 1)                                                AS avg_items_per_order,
  ROUND(
    SUM(oi.quantity * s.selling_price)
    / NULLIF(SUM(oi.quantity), 0)
  , 0)                                                AS avg_item_price_inr,
  ROUND(
    SUM(dc.rider_cost)
    / COUNT(DISTINCT o.order_id)
  , 0)                                                AS avg_rider_cost_per_order,
  ROUND(
    SUM(oi.quantity * (s.selling_price - s.cost_price))
    / COUNT(DISTINCT o.order_id)
  , 0)                                                AS gross_margin_per_order,
  CASE
    WHEN ROUND(SUM(oi.quantity * s.selling_price)
         / COUNT(DISTINCT o.order_id), 0) < 450
     AND ROUND(SUM(oi.quantity)
         / COUNT(DISTINCT o.order_id), 1) < 4
    THEN 'LOW BASKET SIZE — Push bundles and Tier 1 SKUs'
    WHEN ROUND(SUM(oi.quantity * s.selling_price)
         / COUNT(DISTINCT o.order_id), 0) < 450
     AND ROUND(SUM(oi.quantity)
         / COUNT(DISTINCT o.order_id), 1) >= 4
    THEN 'LOW ITEM PRICE — Assortment skewed to cheap SKUs'
    WHEN ROUND(SUM(dc.rider_cost)
         / COUNT(DISTINCT o.order_id), 0) > 60
     AND ROUND(SUM(oi.quantity * s.selling_price)
         / COUNT(DISTINCT o.order_id), 0) >= 450
    THEN 'HIGH DELIVERY COST — Rider efficiency problem'
    WHEN ROUND(SUM(oi.quantity * s.selling_price)
         / COUNT(DISTINCT o.order_id), 0) >= 450
     AND ROUND(SUM(dc.rider_cost)
         / COUNT(DISTINCT o.order_id), 0) <= 60
    THEN 'HEALTHY — AOV and delivery cost both in range'
    ELSE 'REVIEW — Multiple issues'
  END                                                 AS root_cause
FROM dark_stores ds
JOIN orders_tbl o     ON ds.store_id = o.store_id
JOIN order_items oi   ON o.order_id  = oi.order_id
JOIN skus s           ON oi.sku_id   = s.sku_id
JOIN delivery_costs dc ON o.order_id = dc.order_id
WHERE o.delivery_status = 'delivered'
  AND oi.fulfilled = TRUE
GROUP BY ds.store_id, ds.store_name, ds.city
ORDER BY aov_inr ASC;


-- ============================================================
-- IMPROVISATION 2: SKU Tier Classification
-- Mirrors Blinkit's weekly category management playbook
-- Tier 1 = must stock everywhere, Tier 3 = rationalize/cut
-- ============================================================

WITH sku_metrics AS (
  SELECT
    s.sku_id,
    s.product_name,
    s.department,
    s.aisle,
    SUM(oi.quantity * s.selling_price)              AS total_revenue,
    COUNT(DISTINCT oi.order_id)                     AS total_orders,
    ROUND(AVG(CASE WHEN oi.reordered = 1
        THEN 1 ELSE 0 END) * 100, 1)               AS reorder_rate_pct,
    ROUND(AVG(CASE WHEN oi.fulfilled = 1
        THEN 1 ELSE 0 END) * 100, 1)               AS fulfilment_rate_pct,
    ROUND(AVG(oi.quantity), 2)                      AS avg_qty_per_order
  FROM skus s
  JOIN order_items oi ON s.sku_id = oi.sku_id
  JOIN orders_tbl o   ON oi.order_id = o.order_id
  WHERE o.delivery_status = 'delivered'
  GROUP BY s.sku_id, s.product_name, s.department, s.aisle
),
sku_ranked AS (
  SELECT *,
    NTILE(5) OVER (ORDER BY total_revenue DESC)     AS revenue_quintile
  FROM sku_metrics
)
SELECT
  sku_id,
  product_name,
  department,
  total_revenue,
  total_orders,
  reorder_rate_pct,
  fulfilment_rate_pct,
  CASE
    WHEN revenue_quintile = 1
     AND reorder_rate_pct >= 50                     THEN 'TIER 1 — Must stock everywhere'
    WHEN revenue_quintile <= 2
     AND reorder_rate_pct >= 30                     THEN 'TIER 2 — Stock in high demand stores'
    WHEN revenue_quintile >= 4
     AND reorder_rate_pct < 30                      THEN 'TIER 3 — Rationalize or cut'
    ELSE                                                 'TIER 2 — Standard stocking'
  END                                               AS sku_tier,
  CASE
    WHEN fulfilment_rate_pct < 90
     AND revenue_quintile = 1                       THEN 'CRITICAL — Tier 1 SKU understocked'
    WHEN fulfilment_rate_pct < 85
     AND revenue_quintile = 2                       THEN 'WARNING — Tier 2 availability low'
    ELSE                                                 'OK'
  END                                               AS availability_alert
FROM sku_ranked
ORDER BY
  CASE
    WHEN revenue_quintile = 1 AND reorder_rate_pct >= 50 THEN 1
    WHEN revenue_quintile <= 2 AND reorder_rate_pct >= 30 THEN 2
    WHEN revenue_quintile >= 4 AND reorder_rate_pct < 30 THEN 4
    ELSE 3
  END,
  total_revenue DESC;


-- ============================================================
-- IMPROVISATION 3: Post-Jan 2026 Delivery Consistency Tracker
-- Since platforms dropped 10-min promise (govt directive Jan 2026)
-- New metric: consistency (variance), not raw speed
-- ============================================================

SELECT
  ds.store_id,
  ds.store_name,
  ds.city,
  o.order_hour,
  CASE o.order_dow
    WHEN 0 THEN 'Sunday'
    WHEN 1 THEN 'Monday'
    WHEN 2 THEN 'Tuesday'
    WHEN 3 THEN 'Wednesday'
    WHEN 4 THEN 'Thursday'
    WHEN 5 THEN 'Friday'
    WHEN 6 THEN 'Saturday'
  END                                                AS day_of_week,
  COUNT(o.order_id)                                  AS total_orders,
  ROUND(AVG(o.delivery_minutes), 1)                  AS avg_delivery_mins,
  ROUND(MIN(o.delivery_minutes), 1)                  AS fastest_delivery,
  ROUND(MAX(o.delivery_minutes), 1)                  AS slowest_delivery,
  ROUND(MAX(o.delivery_minutes)
      - MIN(o.delivery_minutes), 1)                  AS delivery_variance_mins,
  ROUND(AVG(dc.rider_cost / NULLIF(dc.distance_km, 0)), 1)
                                                     AS avg_cost_per_km,
  CASE
    WHEN ROUND(MAX(o.delivery_minutes)
       - MIN(o.delivery_minutes), 1) > 8
     AND COUNT(o.order_id) > 20
    THEN 'HIGH VARIANCE — Inconsistent rider supply this hour'
    WHEN ROUND(AVG(dc.rider_cost
       / NULLIF(dc.distance_km, 0)), 1) > 30
     AND COUNT(o.order_id) > 20
    THEN 'INEFFICIENT ROUTING — Cost per km too high'
    WHEN COUNT(o.order_id) > 40
     AND ROUND(AVG(o.delivery_minutes), 1) > 14
    THEN 'OVERLOADED — Too many orders, not enough riders'
    ELSE 'EFFICIENT'
  END                                                AS ops_signal
FROM orders_tbl o
JOIN dark_stores ds  ON o.store_id  = ds.store_id
JOIN delivery_costs dc ON o.order_id = dc.order_id
WHERE o.delivery_status = 'delivered'
GROUP BY
  ds.store_id, ds.store_name, ds.city,
  o.order_hour, o.order_dow
HAVING total_orders > 20
ORDER BY delivery_variance_mins DESC
LIMIT 30;


-- ============================================================
-- IMPROVISATION 4: Store Cannibalization Detector
-- Pincodes with multiple stores splitting the same demand
-- Key finding: Bengaluru pincodes have 8 stores each
-- getting 173 orders vs 1,250 needed for break-even
-- ============================================================

SELECT
  o.pincode,
  COUNT(DISTINCT o.store_id)                         AS stores_serving,
  COUNT(DISTINCT o.order_id)                         AS total_orders,
  ROUND(COUNT(DISTINCT o.order_id)
    / COUNT(DISTINCT o.store_id), 0)                 AS avg_orders_per_store,
  GROUP_CONCAT(DISTINCT ds.store_name
    ORDER BY ds.store_name
    SEPARATOR ' | ')                                 AS competing_stores,
  SUM(CASE WHEN o.delivery_status = 'cancelled'
      THEN 1 ELSE 0 END)                             AS total_cancellations,
  ROUND(
    SUM(CASE WHEN o.delivery_status = 'cancelled'
        THEN 1 ELSE 0 END)
    / COUNT(DISTINCT o.order_id) * 100
  , 1)                                               AS cancel_rate_pct,
  CASE
    WHEN COUNT(DISTINCT o.store_id) >= 3
     AND ROUND(COUNT(DISTINCT o.order_id)
         / COUNT(DISTINCT o.store_id), 0) < 500
    THEN 'SEVERE CANNIBALIZATION — Consolidate to 1 mega store'
    WHEN COUNT(DISTINCT o.store_id) = 2
     AND ROUND(COUNT(DISTINCT o.order_id)
         / COUNT(DISTINCT o.store_id), 0) < 500
    THEN 'MODERATE CANNIBALIZATION — Review store boundaries'
    WHEN COUNT(DISTINCT o.store_id) >= 2
     AND ROUND(COUNT(DISTINCT o.order_id)
         / COUNT(DISTINCT o.store_id), 0) >= 500
    THEN 'HEALTHY OVERLAP — Demand supports multiple stores'
    ELSE 'SINGLE STORE — No cannibalization'
  END                                                AS cannibalization_signal
FROM orders_tbl o
JOIN dark_stores ds ON o.store_id = ds.store_id
GROUP BY o.pincode
HAVING stores_serving >= 2
ORDER BY stores_serving DESC, avg_orders_per_store ASC
LIMIT 25;


-- ============================================================
-- IMPROVISATION 5: Inventory Turns by SKU
-- Fast movers vs dead stock — capital allocation efficiency
-- Banana: 299x turns. Whipped Cream Cheese: 20x turns.
-- Both occupy same refrigerated shelf space.
-- ============================================================

SELECT
  sales.sku_id,
  sales.product_name,
  sales.department,
  sales.is_perishable,
  sales.total_units_sold,
  sales.total_revenue,
  inv.avg_stock_on_hand,
  inv.stores_stocking,
  ROUND(sales.total_units_sold
    / NULLIF(inv.avg_stock_on_hand, 0), 1)           AS inventory_turns,
  ROUND(inv.avg_stock_on_hand * sales.cost_price, 0) AS capital_tied_up_inr,
  CASE
    WHEN ROUND(sales.total_units_sold
         / NULLIF(inv.avg_stock_on_hand, 0), 1) >= 150
    THEN 'FAST MOVER — Increase restock frequency'
    WHEN ROUND(sales.total_units_sold
         / NULLIF(inv.avg_stock_on_hand, 0), 1) BETWEEN 80 AND 149
    THEN 'STEADY MOVER — Maintain current levels'
    WHEN ROUND(sales.total_units_sold
         / NULLIF(inv.avg_stock_on_hand, 0), 1) BETWEEN 30 AND 79
    THEN 'SLOW MOVER — Reduce stock depth'
    ELSE 'DEAD STOCK — Consider delisting'
  END                                                AS inventory_signal
FROM (
  SELECT
    s.sku_id,
    s.product_name,
    s.department,
    s.is_perishable,
    s.cost_price,
    SUM(oi.quantity)                                 AS total_units_sold,
    ROUND(SUM(oi.quantity * s.selling_price), 0)     AS total_revenue
  FROM skus s
  JOIN order_items oi ON s.sku_id   = oi.sku_id
  JOIN orders_tbl o   ON oi.order_id = o.order_id
  WHERE o.delivery_status = 'delivered'
    AND oi.fulfilled = TRUE
  GROUP BY s.sku_id, s.product_name, s.department,
           s.is_perishable, s.cost_price
) sales
JOIN (
  SELECT
    sku_id,
    ROUND(AVG(quantity_on_hand), 1) AS avg_stock_on_hand,
    COUNT(store_id)                 AS stores_stocking
  FROM store_inventory
  GROUP BY sku_id
) inv ON sales.sku_id = inv.sku_id
ORDER BY inventory_turns DESC;


-- ============================================================
-- IMPROVISATION 6: Customer Repeat Rate by Store
-- Uses real Instacart days_since_prior_order signal
-- Separates loyal stores from acquisition-dependent ones
-- ============================================================

SELECT
  ds.store_id,
  ds.store_name,
  ds.city,
  COUNT(o.order_id)                                         AS total_orders,
  SUM(CASE WHEN o.days_since_prior <= 14
      THEN 1 ELSE 0 END)                                    AS repeat_within_14d,
  SUM(CASE WHEN o.days_since_prior <= 7
      THEN 1 ELSE 0 END)                                    AS repeat_within_7d,
  ROUND(AVG(CASE WHEN o.days_since_prior > 0
      THEN o.days_since_prior END), 1)                      AS avg_days_between_orders,
  ROUND(
    SUM(CASE WHEN o.days_since_prior <= 14
        THEN 1 ELSE 0 END)
    / COUNT(o.order_id) * 100
  , 1)                                                      AS repeat_rate_14d_pct,
  ROUND(
    SUM(CASE WHEN o.days_since_prior <= 7
        THEN 1 ELSE 0 END)
    / COUNT(o.order_id) * 100
  , 1)                                                      AS repeat_rate_7d_pct,
  ROUND(
    SUM(CASE WHEN o.delivery_status = 'cancelled'
        THEN 1 ELSE 0 END)
    / COUNT(o.order_id) * 100
  , 1)                                                      AS cancel_rate_pct,
  CASE
    WHEN ROUND(
      SUM(CASE WHEN o.days_since_prior <= 14
          THEN 1 ELSE 0 END)
      / COUNT(o.order_id) * 100, 1) >= 60
    THEN 'LOYAL BASE — Scale this store'
    WHEN ROUND(
      SUM(CASE WHEN o.days_since_prior <= 14
          THEN 1 ELSE 0 END)
      / COUNT(o.order_id) * 100, 1) BETWEEN 30 AND 59
    THEN 'DEVELOPING — Retention campaigns needed'
    ELSE 'ACQUISITION DEPENDENT — Unsustainable'
  END                                                       AS retention_signal
FROM orders_tbl o
JOIN dark_stores ds ON o.store_id = ds.store_id
WHERE o.days_since_prior > 0
GROUP BY ds.store_id, ds.store_name, ds.city
ORDER BY repeat_rate_14d_pct DESC;
