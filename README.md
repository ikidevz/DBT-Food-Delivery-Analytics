# 🍔 Food Delivery Analytics — dbt + PostgreSQL

A end-to-end data engineering project built with **dbt Core 1.11** and **PostgreSQL 17**,
using the **Medallion Architecture** (Bronze → Silver → Gold) on a Philippine food delivery dataset.

---

## 📐 Architecture

```
Raw CSVs (Seeds)
     │
     ▼
┌─────────────┐     ┌──────────────────────┐
│   BRONZE    │────▶│   br_food_delivery_  │  Views — no transformation
│  (Raw Views)│     │   orders / customers │  Single source of truth
└─────────────┘     │   / riders           │
                    └──────────────────────┘
                             │
                             ▼
┌─────────────┐      ┌──────────────────────┐
│   SILVER    │───▶ │  sl_food_delivery_    │  Table — cleaned + deduplicated
│  (Cleaned)  │      │ orders               │  8 data quality rules applied
└─────────────┘      └──────────────────────┘
                             │
                    ┌────────┴────────┐
                    ▼                 ▼
┌─────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│    GOLD     │  │ dim_customer │  │  dim_rider   │  │ fct_delivery │
│(Analytical) │  │              │  │              │  │              │
└─────────────┘  └──────────────┘  └──────────────┘  └──────────────┘
```

---

## 🗂️ Project Structure

```
food-delivery-dbt/
├── data-source/
│   └── generate_orders.py        # Synthetic data generator (Faker, PH locale)
├── dbt_project/
│   ├── dbt_project.yml           # Project config, layer schemas, tags
│   ├── .dbt/
│   │   └── profiles.yml          # Connection profile (reads from env vars)
│   ├── models/
│   │   ├── bronze/
│   │   │   ├── br_food_delivery_orders.sql
│   │   │   ├── br_food_delivery_customers.sql
│   │   │   └── br_food_delivery_riders.sql
│   │   ├── silver/
│   │   │   └── sl_food_delivery_orders.sql
│   │   └── gold/
│   │       ├── dim_customer.sql
│   │       ├── dim_rider.sql     ← unique to food delivery domain
│   │       └── fct_delivery.sql
│   └── seeds/                    # Drop CSVs here to load via `dbt seed`
├── init-scripts/
│   └── 01_create_schemas.sql     # Auto-creates medallion schemas on pg start
├── .env.example
├── docker-compose.yml            # PostgreSQL 17 + dbt 1.11
└── Dockerfile                    # python:3.12-slim + dbt-core 1.11.6
```

---

## 🚀 Quick Start

### 1. Generate synthetic data

```bash
cd data-source
pip install faker pandas numpy
python generate_orders.py
# Outputs: food_delivery_orders.csv, food_delivery_customers.csv,
#          food_delivery_riders.csv, food_delivery_restaurants.csv
```

### 2. Copy CSVs into seeds folder

```bash
cp data-source/*.csv dbt_project/seeds/
```

### 3. Configure environment

```bash
cp .env.example .env
# Edit .env if you want custom credentials
```

### 4. Start Postgres

```bash
docker compose up postgres -d
# Wait for health check to pass (~15s)
```

### 5. Seed raw data + run models

```bash
docker compose run dbt seed          # Load CSVs into raw schema
docker compose run dbt run           # Build Bronze → Silver → Gold
docker compose run dbt test          # Run data quality tests
docker compose run dbt docs generate # Build lineage docs
docker compose run dbt docs serve    # Serve docs at localhost:8080
```

---

## 📊 What's in each layer?

### Bronze — Raw Ingestion

Simple `SELECT *` views pointing to seed tables. No logic, just stable references.

| Model                        | Source                         |
| ---------------------------- | ------------------------------ |
| `br_food_delivery_orders`    | `food_delivery_orders` seed    |
| `br_food_delivery_customers` | `food_delivery_customers` seed |
| `br_food_delivery_riders`    | `food_delivery_riders` seed    |

### Silver — Data Quality

One cleaned table with 8 rules applied:

1. Drop rows with NULL `customer_id` or `rider_id`
2. Reject future `order_datetime`
3. Clamp negative `order_total` → 0
4. Clamp zero/negative `item_count` → 1
5. Clamp negative `delivery_fee` → 0
6. Map unknown cities → `'Unknown'`
7. Deduplicate `order_id` — keep most recent
8. Derive `grand_total`, date-part columns, `order_hour`

### Gold — Analytical

| Model          | Type      | Key features                                                            |
| -------------- | --------- | ----------------------------------------------------------------------- |
| `dim_customer` | Dimension | Lifetime value, segment (VIP/Regular/New), preferred payment            |
| `dim_rider`    | Dimension | Success rate %, rider tier (Elite/Experienced/Active), fees earned      |
| `fct_delivery` | Fact      | Boolean flags (is_delivered, is_rated), time_of_day_segment, is_weekend |

---

## 🔧 Version Upgrades vs. Original

| Component                    | Original             | This Project                        |
| ---------------------------- | -------------------- | ----------------------------------- |
| Python                       | 3.11                 | **3.12**                            |
| PostgreSQL                   | 16                   | **17**                              |
| dbt-core                     | 1.11.6               | **1.11.6** ✅ latest stable         |
| dbt-postgres                 | 1.10.0               | **1.10.0** ✅ latest stable         |
| docker-compose `version` key | `"3.9"` (deprecated) | **Removed** (Compose V2 default)    |
| Healthcheck                  | ❌                   | **✅ postgres healthcheck**         |
| `depends_on`                 | basic                | **`condition: service_healthy`**    |
| Schemas                      | single `public`      | **raw / bronze / silver / gold**    |
| Tables                       | 1 source             | **3 source tables + 3 gold models** |

---

## 📝 Blog post notes

- The `dim_rider` model is the most unique part of this project — it showcases how the food delivery domain adds a **third analytical dimension** not found in regular e-commerce
- The Silver layer's `time_of_day_segment` and `is_weekend` flags in the fact table enable **peak hour analysis** without any BI-tool-side logic
- `MODE() WITHIN GROUP (ORDER BY ...)` in PostgreSQL is used to find each customer's preferred payment method — a good SQL pattern worth highlighting
