# 🛒 Quick-Commerce Demand & Inventory Analytics

An end-to-end data analytics project simulating a 10-minute delivery platform's operations, focusing on geospatial analysis, SLA breaches, and real-time inventory alerts.

## 🛠️ Tech Stack
* **Database:** PostgreSQL with PostGIS (for spatial distance calculations)
* **Data Generation:** Python (Faker, psycopg2)
* **Visualization:** Power BI (Smart Narratives, Drill-throughs, Custom Tooltips)

## 📊 Dashboard Highlights
![Dashboard Preview](![Uploading Screenshot 2026-10-11 154522.png…]()
<img width="1298" height="751" alt="Screenshot 2026-10-11 154444" src="https://github.com/user-attachments/assets/9a0f9338-9e69-4d93-980d-75ec42c941a7" />
)

## 💡 Key Features & Analysis
1. **Geospatial SLA Tracking:** Used `ST_Distance` in PostGIS to calculate delivery radius and correlate it with late deliveries (SLA breaches).
2. **Real-Time Inventory Alerts:** Calculated dynamic 'hours-to-stockout' based on daily burn rates to flag critical items.
3. **Executive UI/UX:** Built custom report page tooltips, app-like navigation slicers, and integrated AI Copilot for automated smart narratives.
    
## 🚀 How to Run
1. Execute `database_queries.sql` in pgAdmin to build the schema and views.
2. Run `python generate_data.py` to seed the database with 10,000 mock records.
3. Open `Quick_Commerce_Dashboard.pbix` in Power BI and hit refresh to load the data model.
