import psycopg2
from psycopg2.extras import execute_values
from faker import Faker
import random
import json
from datetime import datetime, timedelta

# ==========================================
# 1. DATABASE CONFIGURATION
# ==========================================
DB_CONFIG = {
    'dbname': 'Quick_commerce_db',
    'user': 'postgres',
    'password': 'admin123', # Yahan apna password dalein
    'host': 'localhost',
    'port': '5432'
}

fake = Faker('en_IN')

# ==========================================
# 2. SEED DATA SETUP
# ==========================================
CATEGORIES = ['Dairy', 'Snacks', 'Beverages', 'Staples', 'Personal Care']
PRODUCT_NAMES = [
    "Milk 500ml", "Bread", "Eggs 6pcs", "Butter 100g", "Paneer 200g",
    "Maggi Masala", "Lays Classic", "Doritos Nacho", "Oreo Biscuits", "Bhujia 200g",
    "Coke 750ml", "Red Bull", "Cold Coffee", "Orange Juice", "Mineral Water 1L",
    "Atta 1kg", "Rice 1kg", "Dal 500g", "Sugar 1kg", "Salt 1kg",
    "Toothpaste", "Soap", "Shampoo", "Face Wash", "Tissue Paper"
]

CENTER_LAT, CENTER_LON = 28.5355, 77.3910

def get_random_location(base_lat, base_lon, radius_offset=0.03):
    lat = base_lat + random.uniform(-radius_offset, radius_offset)
    lon = base_lon + random.uniform(-radius_offset, radius_offset)
    return f"POINT({lon} {lat})"

# ==========================================
# 3. GENERATION FUNCTIONS
# ==========================================
def generate_stores(conn):
    print("Generating 10 Dark Stores...")
    stores = [(f"Dark Store {fake.city()}", get_random_location(CENTER_LAT, CENTER_LON), True) for _ in range(10)]
    
    with conn.cursor() as cur:
        execute_values(cur, "INSERT INTO dark_stores (store_name, location, active_status) VALUES %s", stores)
        cur.execute("SELECT store_id, ST_AsText(location) FROM dark_stores")
        return cur.fetchall()

def generate_products(conn):
    print("Generating 25 Products...")
    products = [(name, random.choice(CATEGORIES), round(random.uniform(20.0, 300.0), 2)) for name in PRODUCT_NAMES]
    
    with conn.cursor() as cur:
        execute_values(cur, "INSERT INTO products (product_name, category, unit_price) VALUES %s", products)
        cur.execute("SELECT product_id FROM products")
        return [row[0] for row in cur.fetchall()]

def generate_inventory(conn, store_ids, product_ids):
    print("Generating Inventory...")
    inventory = []
    for store_id, _ in store_ids:
        for product_id in product_ids:
            inventory.append((store_id, product_id, random.randint(10, 200), datetime.now() - timedelta(days=random.randint(0, 5))))
            
    with conn.cursor() as cur:
        execute_values(cur, "INSERT INTO inventory (store_id, product_id, stock_count, last_replenished) VALUES %s", inventory)

def generate_orders(conn, store_ids, product_ids, num_orders=10000):
    print(f"Generating {num_orders} Orders (This might take a moment)...")
    orders = []
    now = datetime.now()
    
    for _ in range(num_orders):
        store_id, store_loc = random.choice(store_ids)
        
        store_lon, store_lat = map(float, store_loc.replace('POINT(', '').replace(')', '').split())
        customer_loc = get_random_location(store_lat, store_lon, radius_offset=0.02)
        
        num_items = random.randint(1, 5)
        cart = [{"product_id": random.choice(product_ids), "qty": random.randint(1, 3)} for _ in range(num_items)]
        order_items_json = json.dumps(cart)
        
        days_ago = random.randint(0, 30)
        
        hour = random.choices(
            population=list(range(24)),
            weights=[1]*18 + [4]*4 + [1]*2,
            k=1
        )[0]
        
        minute = random.randint(0, 59)
        order_time = now.replace(hour=hour, minute=minute, second=0, microsecond=0) - timedelta(days=days_ago)
        
        if 18 <= hour <= 21 and random.random() < 0.4: 
            delivery_duration = random.randint(11, 25)
        else:
            delivery_duration = random.randint(5, 9)
            
        delivery_time = order_time + timedelta(minutes=delivery_duration)
        status = "Delivered" if random.random() > 0.02 else "Cancelled"
        
        orders.append((store_id, customer_loc, order_items_json, order_time, delivery_time, status))

    with conn.cursor() as cur:
        query = """
            INSERT INTO orders 
            (store_id, customer_location, order_items, order_timestamp, delivery_timestamp, order_status) 
            VALUES %s
        """
        execute_values(cur, query, orders, page_size=1000)

# ==========================================
# 4. MAIN EXECUTION
# ==========================================
if __name__ == "__main__":
    try:
        print("Connecting to PostgreSQL...")
        conn = psycopg2.connect(**DB_CONFIG)
        conn.autocommit = True
        
        store_data = generate_stores(conn)
        product_data = generate_products(conn)
        generate_inventory(conn, store_data, product_data)
        generate_orders(conn, store_data, product_data, 10000)
        
        print("\nData generation complete! You can now run your analytics queries.")
        
    except Exception as e:
        print(f"An error occurred: {e}")
    finally:
        if 'conn' in locals():
            conn.close()