-- 1. bi_dim_product (mostly portable, no change needed)
CREATE OR REPLACE VIEW bi_dim_product AS
SELECT
  p.product_id,
  COALESCE(t.product_category_name_english, p.product_category_name) AS category,
  p.product_weight_g,
  p.product_length_cm,
  p.product_height_cm,
  p.product_width_cm,
  (p.product_length_cm * p.product_height_cm * p.product_width_cm) AS volume_cm3
FROM olist_products_dataset p
LEFT JOIN product_category_name_translation t
  ON t.product_category_name = p.product_category_name;


-- 2. bi_fact_review_latest — DISTINCT ON replaced with ROW_NUMBER()
CREATE OR REPLACE VIEW bi_fact_review_latest AS
SELECT order_id, review_score, review_creation_date, review_answer_timestamp
FROM (
  SELECT
    r.order_id,
    r.review_score,
    r.review_creation_date,
    r.review_answer_timestamp,
    ROW_NUMBER() OVER (
      PARTITION BY r.order_id
      ORDER BY r.review_creation_date DESC
    ) AS rn
  FROM olist_order_reviews_dataset r
) ranked
WHERE rn = 1;


-- 3. bi_fact_order — ::date casts, date_trunc, date subtraction all converted
CREATE OR REPLACE VIEW bi_fact_order AS
SELECT
  o.order_id,
  o.customer_id,
  o.order_status,
  CAST(o.order_purchase_timestamp AS DATE) AS purchase_date,
  DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m-01') AS purchase_month,
  CAST(o.order_delivered_customer_date AS DATE) AS delivered_date,
  CAST(o.order_estimated_delivery_date AS DATE) AS estimated_date,
  CASE
    WHEN o.order_status = 'delivered'
     AND o.order_delivered_customer_date IS NOT NULL
    THEN DATEDIFF(CAST(o.order_delivered_customer_date AS DATE), CAST(o.order_purchase_timestamp AS DATE))
    ELSE NULL
  END AS delivery_days,
  CASE
    WHEN o.order_status = 'delivered'
     AND o.order_delivered_customer_date IS NOT NULL
     AND o.order_estimated_delivery_date IS NOT NULL
     AND CAST(o.order_delivered_customer_date AS DATE) > CAST(o.order_estimated_delivery_date AS DATE)
    THEN 1 ELSE 0
  END AS is_late,
  c.customer_unique_id,
  c.customer_city,
  c.customer_state
FROM olist_orders_dataset o
JOIN olist_customers_dataset c ON c.customer_id = o.customer_id;


-- 4. bi_fact_sales — only ::date cast needed conversion
CREATE OR REPLACE VIEW bi_fact_sales AS
SELECT
  oi.order_id,
  oi.order_item_id,
  oi.product_id,
  oi.seller_id,
  CAST(oi.shipping_limit_date AS DATE) AS shipping_limit_date,
  oi.price,
  oi.freight_value,
  fo.customer_id,
  fo.customer_unique_id,
  fo.order_status,
  fo.purchase_date,
  fo.purchase_month,
  fo.delivered_date,
  fo.estimated_date,
  fo.delivery_days,
  fo.is_late,
  fo.customer_city,
  fo.customer_state,
  dp.category,
  r.review_score,
  p.payment_type,
  p.payment_installments,
  p.payment_value,
  s.seller_city,
  s.seller_state
FROM olist_order_items_dataset oi
JOIN bi_fact_order fo ON fo.order_id = oi.order_id
LEFT JOIN bi_dim_product dp ON dp.product_id = oi.product_id
LEFT JOIN bi_fact_review_latest r ON r.order_id = oi.order_id
LEFT JOIN olist_order_payments_dataset p ON p.order_id = oi.order_id
LEFT JOIN olist_sellers_dataset s ON s.seller_id = oi.seller_id;


-- 5. bi_payments_order — ARRAY_AGG replaced with ROW_NUMBER subquery
CREATE OR REPLACE VIEW bi_payments_order AS
SELECT
  op.order_id,
  SUM(op.payment_value) AS order_payment_value,
  MAX(op.payment_installments) AS order_payment_installments,
  MAX(CASE WHEN op.rn = 1 THEN op.payment_type END) AS order_payment_type
FROM (
  SELECT
    payment_value,
    payment_installments,
    payment_type,
    order_id,
    ROW_NUMBER() OVER (
      PARTITION BY order_id
      ORDER BY payment_value DESC
    ) AS rn
  FROM olist_order_payments_dataset
) op
GROUP BY op.order_id;
