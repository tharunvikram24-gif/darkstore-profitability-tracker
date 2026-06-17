import mysql.connector
import random
from datetime import date, timedelta

random.seed(99)

DB = dict(host="localhost", user="root", password="mTV112006$", database="darkstore_db")
conn = mysql.connector.connect(**DB)
cur  = conn.cursor()

print("Connected. Updating order dates to create ramp-up patterns...")

# Fetch all orders with their store
cur.execute("SELECT order_id, store_id FROM orders_tbl")
orders = cur.fetchall()

base_date = date(2023, 1, 1)
updates   = []

for order_id, store_id in orders:
    is_peripheral = store_id >= 31

    if is_peripheral:
        # Peripheral: random date, no growth trend
        days_offset = random.randint(0, 365)
        weight      = round(random.uniform(0.3, 0.6), 2)
    else:
        # Core store: bias toward later dates = ramp-up effect
        # Early weeks get fewer orders, later weeks get more
        days_offset = int(random.betavariate(2, 1) * 365)
        weight      = round(min(0.5 + (days_offset / 365) * 4.5, 5.0), 2)

    new_date = str((base_date + timedelta(days=days_offset)).isoformat())
    updates.append((new_date, float(weight), int(order_id)))

print(f"Updating {len(updates)} orders...")

batch = 5000
for i in range(0, len(updates), batch):
    cur.executemany(
        "UPDATE orders_tbl SET order_date=%s, week_weight=%s WHERE order_id=%s",
        updates[i:i+batch]
    )
    conn.commit()
    print(f"  Updated {min(i+batch, len(updates))}/{len(updates)}")

cur.close()
conn.close()
print("\n✅ Ramp-up patterns applied.")