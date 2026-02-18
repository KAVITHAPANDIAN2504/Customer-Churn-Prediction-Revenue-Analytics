# Customer Churn Prediction Project

&gt; Predict which customers will leave your business before they actually do!

![Python](https://img.shields.io/badge/Python-blue?logo=python)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-green?logo=postgresql)
![Machine Learning](https://img.shields.io/badge/Machine%20Learning-orange?logo=scikit-learn)
![ETL](https://img.shields.io/badge/ETL%20Pipeline-purple?logo=apacheairflow)
![Database](https://img.shields.io/badge/Database%20Connectivity-red?logo=database)

---

## What is this project?

This project helps businesses **keep their customers** by predicting who is likely to stop using their service (called "churn").

**Real Example:** Imagine you have a phone company. Some customers cancel their plans every month. This system looks at customer data and warns you: *"Hey, Customer #123 is unhappy and might leave next month!"* Then you can offer them a discount or fix their problem before they leave.

---

## What I built

| Component | What it does |
|-----------|--------------|
| **Database (PostgreSQL)** | Stores 1,000 fake customer records safely |
| **Python Code** | Cleans data, creates useful information, trains smart computer models |
| **Machine Learning** | Learns patterns from past customers to predict future behavior |
| **Charts & Reports** | Shows results in easy-to-understand pictures |

---

## How it works (Simple Steps)
Step 1: Collect Data 
↓
Step 2: Clean & Organize (Database)
↓
Step 3: Find Patterns (Machine Learning)
↓
Step 4: Predict Who Will Leave
↓
Step 5: Save Money by Keeping Customers!


---

## Results

| Metric | Result | What it means |
|--------|--------|-------------|
| **Accuracy** | 90.5% | Correctly predicts 9 out of 10 churners |
| **Data Size** | 1,000 customers | Good for demonstration |
| **Money Saved** | $340,000 | Estimated value of prevented churn |

**Top Reasons Customers Leave:**
1. 😞 Low satisfaction scores
2. 🎫 Too many support tickets (frustrated with service)
3. 💳 Payment problems

---

## Files in this project

---

## How to run this project

### Step 1: Install tools
```bash
# Install Python packages
pip install pandas scikit-learn matplotlib sqlalchemy psycopg2-binary
password: 'your_postgres_password_here'
python src/main.py
✓ Loaded 1000 records
✓ Best Model: Gradient Boosting (90.5% accuracy)
✓ Model saved!
