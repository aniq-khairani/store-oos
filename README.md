## 💰 Store OOS Report

### 📊 Dashboard Preview
![Dashboard Page 1](images/store-oos-p1.png)
![Dashboard Page 2](images/store-oos-p2.png)
![Dashboard Page 3](images/store-oos-p3.png)

### 🚀 Live Demo
🔗 [View Power BI Dashboard](https://app.powerbi.com/view?r=example)

### 🧠 Overview
This report monitors **cost and selling price alignment** across multiple merchants (e.g., Food Panda, Shopee Food) and product categories.  
It enables quick comparison between procurement and selling margins to ensure accurate pricing strategies across platforms.

### ⚙️ Technical Summary
- **Data Source:** Amazon Redshift (multiple joined tables via custom SQL script)  
- **SQL Logic:** Combined cost, selling price, and product master data using inner joins and date filters.  
- **Transformations:** Initial data preparation done in SQL; further aggregation handled in Power BI DAX.  
- **Model:** Star-schema inspired (Fact table joined with Dimension tables).  

### 🧮 Key Metrics
- Cost Price (RM)  
- Selling Price (RM)  
- Price Variance by Category  
- Merchant-wise Pricing Comparison  
- Category and Item Filtering  

### 🧩 Report Features
- Dynamic filtering by Merchant Type, Pricing Group, and Item  
- Table view optimized for readability on control-room displays  
- Automated daily data refresh at 12:00 AM  
- Last Updated Timestamp shown for data transparency  

> 💡 *Used SQL joins in Redshift to merge merchant, product, and pricing data before loading into Power BI.*
