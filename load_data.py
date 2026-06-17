import pandas as pd
import mysql.connector
import random
from datetime import date, timedelta
import numpy as np
 
random.seed(42)
np.random.seed(42)
 
# ── CONFIG ────────────────────────────────────────────────
DATA_DIR = r"C:\Users\marki\Desktop\darkstore\data"
DB = dict(host="localhost", user="root", password="mTV112006$", database="darkstore_db")
 
conn = mysql.connector.connect(**DB)
cur  = conn.cursor()
print("Connected to MySQL.")
 
# ══════════════════════════════════════════════════════════
# 1. DARK STORES
# ══════════════════════════════════════════════════════════
cities = [
    ("Chennai",   ["600001","600002","600003","600004","600005","600006","600007","600008"]),
    ("Mumbai",    ["400001","400002","400003","400004","400050","400051","400052","400053"]),
    ("Bengaluru", ["560001","560002","560003","560004","560034","560038","560040","560041"]),
    ("Hyderabad", ["500001","500002","500003","500004","500032","500033","500034","500035"]),
    ("Delhi",     ["110001","110002","110003","110004","110051","110052","110053","110054"]),
    ("Pune",      ["411001","411002","411003","411004","411014","411015","411016","411017"]),
]
zones = ["north","south","east","west","central"]
 
stores = []
store_id = 1
for city, pincodes in cities:
    n = 8 if city in ["Chennai","Mumbai","Bengaluru"] else 6 if city in ["Hyderabad","Delhi"] else 4
    for i in range(n):
        is_peripheral = store_id >= 41
        opened_date   = (date(2023,1,1) + timedelta(days=random.randint(0,300))).isoformat()
        if is_peripheral:
            opened_date   = (date(2023,9,1) + timedelta(days=random.randint(0,120))).isoformat()
            monthly_rent  = random.randint(180000, 260000)
        else:
            monthly_rent  = random.randint(80000, 160000)
        stores.append((
            int(store_id),
            f"{city} Store {i+1}",
            city,
            str(random.choice(pincodes)),
            str(random.choice(zones)),
            float(monthly_rent),
            int(random.randint(8, 18)),
            str(opened_date),
            "active"
        ))
        store_id += 1
 
cur.executemany("""
    INSERT INTO dark_stores
    (store_id,store_name,city,pincode,zone,monthly_rent,staff_count,opened_date,status)
    VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s)
""", stores)
conn.commit()
print(f"Inserted {len(stores)} dark stores.")
 
# ══════════════════════════════════════════════════════════
# 2. SKUS
# ══════════════════════════════════════════════════════════
products    = pd.read_csv(f"{DATA_DIR}/products.csv")
aisles      = pd.read_csv(f"{DATA_DIR}/aisles.csv")
departments = pd.read_csv(f"{DATA_DIR}/departments.csv")
products    = products.merge(aisles, on="aisle_id").merge(departments, on="department_id")
 
op = pd.read_csv(f"{DATA_DIR}/order_products__prior.csv")
top_skus = op['product_id'].value_counts().head(500).index
products = products[products['product_id'].isin(top_skus)].copy()
 
perishable_depts = {"produce","dairy eggs","meat seafood","bakery","deli","beverages"}
 
sku_rows = []
sku_id_set = set()
for _, row in products.iterrows():
    is_perish = row['department'].strip().lower() in perishable_depts
    cost      = round(random.uniform(15, 280), 2)
    selling   = round(cost * random.uniform(1.08, 1.35), 2)
    shelf     = random.randint(1, 5) if is_perish else random.randint(30, 180)
    sku_rows.append((
        int(row['product_id']),
        str(row['product_name'])[:200],
        str(row['aisle']),
        str(row['department']),
        float(cost),
        float(selling),
        bool(is_perish),
        int(shelf)
    ))
    sku_id_set.add(int(row['product_id']))
 
cur.executemany("""
    INSERT INTO skus
    (sku_id,product_name,aisle,department,cost_price,selling_price,is_perishable,shelf_life_days)
    VALUES (%s,%s,%s,%s,%s,%s,%s,%s)
""", sku_rows)
conn.commit()
print(f"Inserted {len(sku_rows)} SKUs.")
 
# ══════════════════════════════════════════════════════════
# 3. ORDERS
# ══════════════════════════════════════════════════════════
orders_raw = pd.read_csv(f"{DATA_DIR}/orders.csv")
orders_raw = orders_raw[orders_raw['eval_set'] == 'prior'].head(60000).copy()
 
store_ids = [s[0] for s in stores]
weights   = [1 if sid < 41 else 0.08 for sid in store_ids]
total_w   = sum(weights)
weights   = [w/total_w for w in weights]
 
users      = orders_raw['user_id'].unique()
user_store = {int(u): int(np.random.choice(store_ids, p=weights)) for u in users}
 
store_map  = {s[0]: (s[2], s[3]) for s in stores}
pincodes_by_city = {city: pincodes for city, pincodes in cities}
 
base_date  = date(2023, 1, 1)
order_rows    = []
delivery_rows = []
 
print("Building orders... (this may take 2-3 minutes)")
 
for _, row in orders_raw.iterrows():
    oid = int(row['order_id'])
    uid = int(row['user_id'])
    sid = user_store[uid]
    city, _ = store_map[sid]
    pincode  = str(random.choice(pincodes_by_city[city]))
    dow      = int(row['order_dow'])
    hour     = int(row['order_hour_of_day'])
    odate    = str((base_date + timedelta(days=random.randint(0, 365))).isoformat())
 
    is_peripheral = sid >= 41
    cancel_prob   = 0.22 if is_peripheral else 0.06
    status = random.choices(
        ['delivered','cancelled','partial'],
        weights=[1-cancel_prob-0.04, cancel_prob, 0.04]
    )[0]
 
    days_prior    = 0 if pd.isna(row['days_since_prior_order']) else int(row['days_since_prior_order'])
    delivery_mins = int(random.randint(22, 48) if is_peripheral else random.randint(8, 18))
    is_split      = bool(random.random() < (0.18 if is_peripheral else 0.05))
 
    order_rows.append((oid, sid, pincode, dow, hour, odate, days_prior, status, delivery_mins, is_split))
 
    rider_cost  = float(round(random.uniform(55, 95) if is_peripheral else random.uniform(28, 52), 2))
    distance_km = float(round(random.uniform(2.1, 4.8) if is_peripheral else random.uniform(0.4, 2.2), 2))
    delivery_rows.append((oid, sid, rider_cost, distance_km, odate))
 
batch = 5000
for i in range(0, len(order_rows), batch):
    cur.executemany("""
        INSERT IGNORE INTO orders_tbl
        (order_id,store_id,pincode,order_dow,order_hour,order_date,
         days_since_prior,delivery_status,delivery_minutes,is_split)
        VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
    """, order_rows[i:i+batch])
    conn.commit()
    print(f"  Orders: {min(i+batch, len(order_rows))}/{len(order_rows)}")
 
print(f"Inserted {len(order_rows)} orders.")
 
# ══════════════════════════════════════════════════════════
# 4. ORDER ITEMS
# ══════════════════════════════════════════════════════════
print("Building order items...")
order_ids_in_db = {r[0] for r in order_rows}
op_grouped      = op.groupby('order_id')
 
item_rows = []
for order_id, group in op_grouped:
    oid = int(order_id)
    if oid not in order_ids_in_db:
        continue
    for _, item in group.iterrows():
        pid = int(item['product_id'])
        if pid not in sku_id_set:
            continue
        item_rows.append((
            oid,
            pid,
            int(random.randint(1, 3)),
            bool(random.random() > 0.07),
            bool(int(item['reordered']))
        ))
 
for i in range(0, len(item_rows), batch):
    cur.executemany("""
        INSERT INTO order_items (order_id,sku_id,quantity,fulfilled,reordered)
        VALUES (%s,%s,%s,%s,%s)
    """, item_rows[i:i+batch])
    conn.commit()
    print(f"  Items: {min(i+batch, len(item_rows))}/{len(item_rows)}")
 
print(f"Inserted {len(item_rows)} order items.")
 
# ══════════════════════════════════════════════════════════
# 5. DELIVERY COSTS
# ══════════════════════════════════════════════════════════
for i in range(0, len(delivery_rows), batch):
    cur.executemany("""
        INSERT INTO delivery_costs (order_id,store_id,rider_cost,distance_km,delivery_date)
        VALUES (%s,%s,%s,%s,%s)
    """, delivery_rows[i:i+batch])
    conn.commit()
print(f"Inserted {len(delivery_rows)} delivery cost records.")
 
# ══════════════════════════════════════════════════════════
# 6. STORE INVENTORY
# ══════════════════════════════════════════════════════════
print("Building store inventory...")
top_products = [int(x) for x in op['product_id'].value_counts().head(60).index.tolist()]
sku_id_list  = list(sku_id_set)
 
unstocked_pairs = [
    (top_products[0], top_products[1]),
    (top_products[2], top_products[3]),
    (top_products[4], top_products[5]),
    (top_products[6], top_products[7]),
    (top_products[8], top_products[9]),
    (top_products[10], top_products[11]),
]
 
unstocked_skus_by_store = {}
for s in stores[:15]:
    missing = set()
    for pair in unstocked_pairs:
        missing.add(pair[1])
    unstocked_skus_by_store[s[0]] = missing
 
base_restock = date(2024, 1, 1)
inv_rows = []
for s in stores:
    sid     = s[0]
    missing = unstocked_skus_by_store.get(sid, set())
    for sku in sku_id_list:
        if sku in missing:
            continue
        qty     = int(random.randint(5, 80))
        restock = str((base_restock + timedelta(days=random.randint(0, 30))).isoformat())
        inv_rows.append((int(sid), int(sku), qty, restock))
 
for i in range(0, len(inv_rows), batch):
    cur.executemany("""
        INSERT IGNORE INTO store_inventory (store_id,sku_id,quantity_on_hand,last_restocked)
        VALUES (%s,%s,%s,%s)
    """, inv_rows[i:i+batch])
    conn.commit()
print(f"Inserted {len(inv_rows)} inventory records.")
 
cur.close()
conn.close()
print("\n✅ All data loaded. Database is ready.")
 
