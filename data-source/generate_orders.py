import pandas as pd
import numpy as np
import random
from faker import Faker
from datetime import datetime, timedelta

fake = Faker("en_PH")  # Filipino locale for realistic names

# ─── CONFIGURATION ────────────────────────────────────────────────────────────
NUM_RECORDS      = 1500
ERROR_PERCENTAGE = 0.08   # 8% dirty records to showcase Silver cleaning

# Domain lists — PH food delivery context
PH_CITIES = ["Davao", "Cebu", "Manila", "Quezon City", "Iloilo",
             "Cagayan de Oro", "Zamboanga", "Bacolod"]

CUISINE_TYPES = ["Filipino", "BBQ & Grill", "Fast Food", "Chinese",
                 "Japanese", "Korean", "Western", "Seafood", "Desserts"]

PAYMENT_METHODS = ["GCash", "Maya", "Credit Card", "Cash on Delivery", "ShopeePay"]

DELIVERY_STATUSES = ["Delivered", "Cancelled", "Failed Delivery", "Returned to Rider"]

# Weighted so ~70% are Delivered (realistic)
STATUS_WEIGHTS = [0.70, 0.15, 0.10, 0.05]

# ─── DATA GENERATION ──────────────────────────────────────────────────────────
def generate_data():
    orders    = []
    customers = []
    riders    = []

    # -- Pre-build customer pool (300 customers)
    customer_pool = [
        {
            "customer_id"   : f"C{i+1:04d}",
            "customer_name" : fake.name(),
            "city"          : random.choice(PH_CITIES),
            "phone"         : fake.phone_number(),
            "signup_date"   : fake.date_between(start_date="-3y", end_date="-1y"),
        }
        for i in range(300)
    ]

    # -- Pre-build rider pool (50 riders)
    rider_pool = [
        {
            "rider_id"  : f"R{i+1:03d}",
            "rider_name": fake.name(),
            "city"      : random.choice(PH_CITIES),
            "vehicle"   : random.choice(["Motorcycle", "Bicycle", "E-bike"]),
        }
        for i in range(50)
    ]

    # -- Pre-build restaurant pool (200 restaurants)
    restaurant_pool = [
        {
            "restaurant_id"  : f"REST{i+1:04d}",
            "restaurant_name": fake.company() + " " + random.choice(["Grill", "Kitchen", "Eats", "House", "Diner"]),
            "cuisine_type"   : random.choice(CUISINE_TYPES),
            "city"           : random.choice(PH_CITIES),
        }
        for i in range(200)
    ]

    # -- Generate orders
    for i in range(NUM_RECORDS):
        customer   = random.choice(customer_pool)
        rider      = random.choice(rider_pool)
        restaurant = random.choice(restaurant_pool)

        order_date    = fake.date_time_between(start_date="-1y", end_date="now")
        item_count    = random.randint(1, 8)
        order_total   = round(random.uniform(80, 1500), 2)   # ₱
        delivery_fee  = round(random.choice([29, 39, 49, 59, 69, 79]), 2)
        rating        = round(random.uniform(1.0, 5.0), 1) if random.random() > 0.2 else None

        orders.append({
            "order_id"       : f"ORD{i+1:06d}",
            "order_datetime" : order_date,
            "customer_id"    : customer["customer_id"],
            "rider_id"       : rider["rider_id"],
            "restaurant_id"  : restaurant["restaurant_id"],
            "city"           : customer["city"],
            "cuisine_type"   : restaurant["cuisine_type"],
            "item_count"     : item_count,
            "order_total"    : order_total,
            "delivery_fee"   : delivery_fee,
            "payment_method" : random.choice(PAYMENT_METHODS),
            "delivery_status": random.choices(DELIVERY_STATUSES, weights=STATUS_WEIGHTS)[0],
            "customer_rating": rating,
        })

    # Convert to DataFrames
    df_orders      = pd.DataFrame(orders)
    df_customers   = pd.DataFrame(customer_pool)
    df_riders      = pd.DataFrame(rider_pool)
    df_restaurants = pd.DataFrame(restaurant_pool)

    # Inject realistic dirty data
    df_orders = inject_errors(df_orders)

    # Save all three source tables as CSVs
    df_orders.to_csv("food_delivery_orders.csv",       index=False)
    df_customers.to_csv("food_delivery_customers.csv", index=False)
    df_riders.to_csv("food_delivery_riders.csv",       index=False)
    df_restaurants.to_csv("food_delivery_restaurants.csv", index=False)

    print("✅  4 CSV files generated successfully:")
    print(f"    → food_delivery_orders.csv       ({len(df_orders)} rows)")
    print(f"    → food_delivery_customers.csv    ({len(df_customers)} rows)")
    print(f"    → food_delivery_riders.csv       ({len(df_riders)} rows)")
    print(f"    → food_delivery_restaurants.csv  ({len(df_restaurants)} rows)")


# ─── ERROR INJECTION ──────────────────────────────────────────────────────────
def inject_errors(df: pd.DataFrame) -> pd.DataFrame:
    num_errors = int(len(df) * ERROR_PERCENTAGE)

    error_types = [
        "null_customer",
        "null_rider",
        "negative_order_total",
        "zero_item_count",
        "invalid_city",
        "future_datetime",
        "duplicate_order",
        "negative_delivery_fee",
    ]

    for _ in range(num_errors):
        row        = random.randint(0, len(df) - 1)
        error_type = random.choice(error_types)

        if error_type == "null_customer":
            df.at[row, "customer_id"] = None

        elif error_type == "null_rider":
            df.at[row, "rider_id"] = None

        elif error_type == "negative_order_total":
            df.at[row, "order_total"] = -round(random.uniform(80, 500), 2)

        elif error_type == "zero_item_count":
            df.at[row, "item_count"] = 0

        elif error_type == "invalid_city":
            df.at[row, "city"] = "XYZ"

        elif error_type == "future_datetime":
            df.at[row, "order_datetime"] = datetime.now() + timedelta(days=random.randint(1, 60))

        elif error_type == "duplicate_order":
            df.at[row, "order_id"] = "ORD000001"

        elif error_type == "negative_delivery_fee":
            df.at[row, "delivery_fee"] = -abs(df.at[row, "delivery_fee"])

    return df


if __name__ == "__main__":
    generate_data()
