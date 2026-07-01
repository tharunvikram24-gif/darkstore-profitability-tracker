# Dark Store Profitability Collapse Tracker

A SQL-based analytics system that reconstructs the exact failure pattern behind Dunzo's collapse, and shows what could have caught it 18 months earlier.

---

## The Real Problem

Dunzo shut down in January 2025. Reliance wrote off ₹1,645 crore. The company ran 120+ dark stores across 15 cities with no per-store P&L visibility — only network-wide GMV.

Dunzo lost ₹230 on every order delivered in H1 2022. By April 2023, they were closing stores doing fewer than 1,000 orders/day — but only after months of losses had already compounded. The reactive closures in November 2022 (25–30% of Delhi-NCR and Hyderabad stores) came after the damage was done, not before.

## The Thesis

Dunzo did not collapse because of competition. It collapsed because it had no system to measure where each store was *heading*, only where it currently stood. By the time a store was visibly failing, months of fixed costs (rent, staff, sunk inventory) had already been burned with no early warning.

This project builds that early-warning system using SQL alone.

---

## Dataset

- **Order and SKU layer:** Instacart Market Basket Analysis dataset (3.4M real grocery orders, real product co-occurrence, real customer reorder behavior)
- **Cost and store layer:** Synthetically generated, calibrated to Dunzo's publicly documented unit economics (₹230/order loss, ₹1,250/day break-even threshold, 9-month payback benchmark)

This hybrid approach means the basket analysis and customer repeat-rate findings are genuine statistical patterns from real data, while the cost layer reflects real, sourced industry numbers.

---

## Schema

6 tables: `dark_stores`, `skus`, `orders_tbl`, `order_items`, `delivery_costs`, `store_inventory`

40 dark stores across 6 cities · 500 SKUs · 60,000 orders · 254,000+ order items

See `schema.sql` for full table definitions.

---

## The Investigation — 6 Core Queries

| # | Question | Key Finding |
|---|---|---|
| 1 | Which stores are stalling vs ramping up? | Peripheral stores (31–40) show a flat 0.45 ramp score — never grow. Core stores reach 3.4+ — the Dunzo pattern reproduced |
| 2 | Which SKU pairs cause split deliveries? | Bag of Organic Bananas + Organic Strawberries co-ordered 1,040 times — ₹16.8L annual revenue at risk if either is unstocked |
| 3 | Which pin codes are underserved? | Pincode 411016 has an 8.7% cancellation rate despite 762 orders — demand exists, fulfilment doesn't |
| 4 | What is each store's true P&L? | Worst stores lose ₹883–931 per order after rent, staff, and rider costs — fully loaded, not just COGS |
| 5 | Where is perishable stock expiring unsold? | Items sitting 800+ days past shelf life — ₹22,000+ in invisible waste per store |
| 6 | What should ops do Monday morning? | Ranked action table: CLOSE / RESTRUCTURE / MONITOR / SCALE per store, with sunk cost already burned |

---

## The Deep Dive — 6 Improvisations

| # | Question | Key Finding |
|---|---|---|
| 7 | AOV vs delivery cost — what's the real driver of losses? | AOV is healthy (₹1,450 avg, well above the ₹450 danger threshold). The losses are 100% a rider cost problem — ₹148–174/order vs the ₹50–60 industry benchmark |
| 8 | Which SKUs deserve shelf space? | Banana has an 83% reorder rate and ₹52.8L revenue. Aluminum Foil has a 14.9% reorder rate. Both occupy identical shelf space in every store |
| 9 | Is delivery speed still the right metric? | Since Jan 2026, platforms dropped the "10-minute" promise following a Labour Ministry directive. The real metric now is consistency — our worst stores show a 10-minute variance within the same hour |
| 10 | Are stores competing with each other? | Bengaluru pincode 560004 has 8 stores splitting 1,387 orders — 173/store. One consolidated mega-store would clear the 1,250 break-even threshold instantly |
| 11 | Which SKUs are dead capital? | Banana turns inventory 299x/period. Whipped Cream Cheese turns 20x. Same refrigerated space, 15x different value |
| 12 | Do loyal customers exist? | Top stores show 75–78% repeat rate within 14 days, using real Instacart purchase-interval data — demand isn't the problem, network structure is |

---

## The Master Insight

The network is not failing because customers don't want the product — repeat rates of 75–78% prove they do. It is not failing because AOV is too low — ₹1,450 average is well above viability. It is failing because multiple stores in the same pincode are splitting demand that could support exactly one profitable mega-store. This is the Dunzo pattern: expansion without density discipline.

---

## How to Run This Project

1. Download the [Instacart Market Basket Analysis dataset](https://www.kaggle.com/datasets/psparks/instacart-market-basket-analysis) from Kaggle
2. Place the 5 CSVs in a `data/` folder (not tracked in this repo — see `.gitignore`)
3. Run `schema.sql` in MySQL to create all 6 tables
4. Run `load_data.py` to populate the database (~5–8 minutes)
5. Run `fix_ramp.py` to apply realistic store ramp-up trajectories
6. Run each query in `queries.sql` individually in MySQL Workbench
7. Results from each run are saved in `results/` as CSV

**Requirements:** MySQL 8.0+, Python 3.x with `pandas` and `mysql-connector-python`

---

## Sources

- Entrackr — Dunzo dark store closures (Nov 2022, Jul 2023)
- Rest of World — Dunzo shutdown reporting (Mar 2025)
- Inc42 — Dunzo layoffs and unit economics (Jul 2023)
- Outlook Business, Inventiva — Quick commerce unit economics (2025–2026)
- Redseer, Business Model Hub — Dark store break-even benchmarks (2026)
- Instacart Market Basket Analysis dataset — Kaggle (public)
