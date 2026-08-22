# Olist E-Commerce BI Dashboard

End-to-end BI project on the Brazilian Olist e-commerce dataset (~100K orders, 2016–2018) — raw CSVs modeled in **PostgreSQL**, exposed through a SQL semantic layer, and visualized in an interactive **Power BI** report connected live via **DirectQuery**.

## Tech Stack
PostgreSQL · SQL · Power BI · DAX · DirectQuery

## Architecture
```
9 raw CSVs → PostgreSQL tables (PK/FK + indexes) → 5 BI views (fact/dimension pattern) → Power BI (DirectQuery) → DAX measures → 9-page report
```

- **`sql/01_tables.sql`** — 9 table definitions (customers, geolocation, products, sellers, orders, order items, payments, reviews, category translation)
- **`sql/02_foreign_keys.sql`** — relational constraints linking orders↔customers, items↔orders/products/sellers, payments↔orders, reviews↔orders
- **`sql/03_indexes.sql`** — indexes on join/filter columns for query performance
- **`sql/04_bi_views.sql`** — semantic layer of 5 views:
  - `bi_dim_product` — product + English category name + computed volume
  - `bi_fact_review_latest` — most recent review per order (dedup via `DISTINCT ON`)
  - `bi_fact_order` — order grain: delivery days, on-time flag, customer info
  - `bi_fact_sales` — main flattened fact (order-item grain) used by Power BI
  - `bi_payments_order` — payments aggregated to one row per order
- **`dax/measures.dax`** — `DimDate` calculated table + 26 DAX measures (Revenue, Orders, AOV, YoY %, Rolling 30-Day Revenue, On-time %, Review Bucket, Sellers, Drill Title, etc.)
- **`dashboard/`** — the `.pbix` file and PNG screenshots of all 9 report pages
- **`docs/report_pages_spec.md`** — full visual-by-visual spec for every report page

## Dashboard Pages (9)
1. Overview (Executive KPIs)
2. Sales Trends
3. Category & Product
4. Customer Geo
5. Delivery & Logistics
6. Reviews
7. Payments
8. Sellers
9. Drillthrough (by category)

## Headline Metrics
| Metric | Value |
|---|---|
| Revenue | $14.21M |
| Orders | 98.67K |
| Customers | 95K |
| AOV | $144.01 |
| On-time Delivery | 93.23% |
| Avg Rating | 4.03 / 5 |
| YoY Growth | 253.07% |

## Known Limitations
- `olist_geolocation_dataset` is loaded into PostgreSQL but not yet joined into any BI view — no maps or seller/customer distance analysis are implemented. This is a natural next step (e.g. delivery-distance vs. delivery-days correlation).
- `bi_fact_sales` joins raw payments at order-item grain rather than through `bi_payments_order`. For orders with multiple items, this means payment-, late-order-, and rating-based totals are counted at item grain rather than order grain — worth normalizing to `bi_payments_order` for stricter one-row-per-order metrics.
- Report uses Power BI DirectQuery against PostgreSQL — no scheduled refresh or Power BI Service publishing is configured; this is a local/desktop report.

## Dataset
[Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) (Kaggle)
