-- Step 1: Create ENUM types first
CREATE TYPE gender_type AS ENUM ('Male', 'Female', 'Other');
CREATE TYPE segment_type AS ENUM ('Premium', 'Standard', 'Basic');
CREATE TYPE service_type AS ENUM ('Internet', 'Phone', 'TV', 'Bundle');
CREATE TYPE payment_method_type AS ENUM ('Credit Card', 'Bank Transfer', 'Electronic Check', 'Mailed Check');
CREATE TYPE payment_status_type AS ENUM ('Success', 'Failed', 'Pending', 'Refunded');

-- Step 2: Create customers table
CREATE TABLE customers (
    customer_id SERIAL PRIMARY KEY,
    customer_name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE,
    phone VARCHAR(20),
    age INTEGER CHECK (age >= 18 AND age <= 100),
    gender gender_type,
    city VARCHAR(50),
    state VARCHAR(50),
    country VARCHAR(50) DEFAULT 'USA',
    signup_date DATE NOT NULL,
    customer_segment segment_type,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Step 3: Create services table
CREATE TABLE services (
    service_id SERIAL PRIMARY KEY,
    service_name VARCHAR(100) NOT NULL,
    service_type service_type,
    monthly_price DECIMAL(10,2) NOT NULL,
    setup_fee DECIMAL(10,2) DEFAULT 0,
    contract_length_months INTEGER DEFAULT 12
);

-- Step 4: Create subscriptions table
CREATE TABLE subscriptions (
    subscription_id SERIAL PRIMARY KEY,
    customer_id INTEGER REFERENCES customers(customer_id),
    service_id INTEGER REFERENCES services(service_id),
    start_date DATE NOT NULL,
    end_date DATE,
    monthly_charges DECIMAL(10,2) NOT NULL,
    total_charges DECIMAL(10,2),
    payment_method payment_method_type,
    paperless_billing BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    churn_date DATE,
    churn_reason VARCHAR(200),
    CONSTRAINT valid_dates CHECK (end_date IS NULL OR end_date >= start_date),
	UNIQUE(customer_id)
);

-- Step 5: Create usage_metrics table
CREATE TABLE usage_metrics (
    metric_id SERIAL PRIMARY KEY,
    customer_id INTEGER REFERENCES customers(customer_id),
    record_date DATE NOT NULL,
    data_usage_gb DECIMAL(10,2),
    call_minutes INTEGER,
    support_tickets INTEGER DEFAULT 0,
    website_visits INTEGER DEFAULT 0,
    app_logins INTEGER DEFAULT 0,
    satisfaction_score INTEGER CHECK (satisfaction_score BETWEEN 1 AND 10),
    UNIQUE(customer_id, record_date)
);

-- Step 6: Create payments table
CREATE TABLE payments (
    payment_id SERIAL PRIMARY KEY,
    customer_id INTEGER REFERENCES subscriptions(subscription_id),
    payment_date DATE NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    payment_status payment_status_type,
    late_fee DECIMAL(10,2) DEFAULT 0
);

-- Step 7: Create indexes for performance
CREATE INDEX idx_customers_segment ON customers(customer_segment);
CREATE INDEX idx_customers_signup ON customers(signup_date);
CREATE INDEX idx_subscriptions_active ON subscriptions(is_active);
CREATE INDEX idx_subscriptions_churn ON subscriptions(churn_date) WHERE churn_date IS NOT NULL;
CREATE INDEX idx_subscriptions_customer ON subscriptions(customer_id);
CREATE INDEX idx_usage_customer_date ON usage_metrics(customer_id, record_date);
CREATE INDEX idx_payments_customer ON payments(customer_id);
CREATE INDEX idx_payments_date ON payments(payment_date);

-- Verify tables created
SELECT table_name FROM information_schema.tables WHERE table_schema = 'public';

-- Insert Services
INSERT INTO services (service_name, service_type, monthly_price, setup_fee, contract_length_months) VALUES
('Fiber Optic 100Mbps', 'Internet', 70.00, 50.00, 12),
('Fiber Optic 500Mbps', 'Internet', 90.00, 50.00, 12),
('Fiber Optic 1Gbps', 'Internet', 120.00, 0.00, 24),
('Basic TV Package', 'TV', 50.00, 30.00, 12),
('Premium TV Package', 'TV', 85.00, 30.00, 12),
('Unlimited Phone', 'Phone', 30.00, 20.00, 12),
('Triple Play Bundle', 'Bundle', 150.00, 100.00, 24),
('Double Play Bundle', 'Bundle', 110.00, 80.00, 12);

-- Verify services
SELECT * FROM services;

-- Insert 1000 Customers
INSERT INTO customers (customer_name, email, phone, age, gender, city, state, signup_date, customer_segment)
SELECT 
    'Customer_' || i,
    'customer' || i || '@gmail.com' as email,
    '(' || (random() * 800 + 200)::int || ')' || (random() * 800 + 200)::int || '-' || (random() * 9000 + 1000)::int,
    (random() * 62 + 18)::int,
    CASE WHEN random() < 0.5 THEN 'Male'::gender_type ELSE 'Female'::gender_type END,
    (ARRAY['New York', 'Los Angeles', 'Chicago', 'Houston', 'Phoenix', 'Philadelphia', 'San Antonio', 'San Diego', 'Dallas', 'San Jose'])[(random() * 9 + 1)::int],
    (ARRAY['NY', 'CA', 'IL', 'TX', 'AZ', 'PA', 'TX', 'CA', 'TX', 'CA'])[(random() * 9 + 1)::int],
    CURRENT_DATE - (random() * 1095 + 30)::int,
    CASE 
        WHEN random() < 0.2 THEN 'Premium'::segment_type
        WHEN random() < 0.6 THEN 'Standard'::segment_type
        ELSE 'Basic'::segment_type
    END
FROM generate_series(1, 1000) AS i
on conflict (email) do nothing;

-- Verify count
SELECT COUNT(*) as total_customers FROM customers;
SELECT * FROM customers LIMIT 5;

-- Insert Usage Metrics (last 12 months for each customer)
INSERT INTO usage_metrics (customer_id, record_date, data_usage_gb, call_minutes, support_tickets, website_visits, app_logins, satisfaction_score)
SELECT 
    c.customer_id,
    dates.dt,
    CASE 
        WHEN random() < 0.1 THEN NULL  -- Some missing data
        WHEN s.service_type IN ('Internet', 'Bundle') THEN random() * 500 + 10
        ELSE random() * 50
    END,
    (random() * 1000)::int,
    (random() * 5)::int,
    (random() * 50)::int,
    (random() * 30)::int,
    CASE 
        WHEN sub.churn_date IS NOT NULL AND dates.dt > sub.churn_date - 30 THEN (random() * 3 + 1)::int
        ELSE (random() * 7 + 3)::int
    END
FROM customers c
JOIN subscriptions sub ON c.customer_id = sub.customer_id
JOIN services s ON sub.service_id = s.service_id
CROSS JOIN LATERAL generate_series(
    GREATEST(sub.start_date, CURRENT_DATE - INTERVAL '12 months'),
    LEAST(COALESCE(sub.churn_date, CURRENT_DATE), CURRENT_DATE),
    INTERVAL '1 month'
) AS dates(dt)
WHERE random() < 0.8;

-- Verify
SELECT COUNT(*) as total_usage_records FROM usage_metrics;
SELECT * FROM usage_metrics LIMIT 5;


-- Insert Payment History
INSERT INTO payments (customer_id, payment_date, amount, payment_status, late_fee)
SELECT 
    sub.customer_id,
    generate_series(sub.start_date, COALESCE(sub.churn_date, CURRENT_DATE), INTERVAL '1 month')::date,
    sub.monthly_charges,
    CASE 
        WHEN random() < 0.85 THEN 'Success'::payment_status_type
        WHEN random() < 0.95 THEN 'Failed'::payment_status_type
        ELSE 'Pending'::payment_status_type
    END,
    CASE WHEN random() < 0.15 THEN sub.monthly_charges * 0.05 ELSE 0 END
FROM subscriptions sub;

-- Verify
SELECT 
    payment_status,
    COUNT(*) as count,
    SUM(amount) as total_amount
FROM payments
GROUP BY payment_status;

-- View 1: Customer Lifetime Value
CREATE OR REPLACE VIEW customer_ltv AS
SELECT 
    c.customer_id,
    c.customer_name,
    c.customer_segment,
    c.signup_date,
    COUNT(DISTINCT sub.subscription_id) as total_subscriptions,
    SUM(sub.total_charges) as total_revenue,
    AVG(sub.monthly_charges) as avg_monthly_charges,
    MAX(sub.churn_date) as last_churn_date,
    CASE WHEN MAX(sub.churn_date) IS NULL THEN 'Active' ELSE 'Churned' END as current_status,
    EXTRACT(DAY FROM COALESCE(MAX(sub.churn_date), CURRENT_DATE)::TIMESTAMP - c.signup_date) as customer_tenure_days
FROM customers c
LEFT JOIN subscriptions sub ON c.customer_id = sub.customer_id
GROUP BY c.customer_id, c.customer_name, c.customer_segment, c.signup_date;

-- View 2: Churn Analysis by Segment
CREATE OR REPLACE VIEW churn_analysis AS
SELECT 
    customer_segment,
    COUNT(*) as total_customers,
    SUM(CASE WHEN current_status = 'Churned' THEN 1 ELSE 0 END) as churned_customers,
    ROUND(100.0 * SUM(CASE WHEN current_status = 'Churned' THEN 1 ELSE 0 END) / COUNT(*), 2) as churn_rate_pct,
    ROUND(AVG(total_revenue), 2) as avg_ltv,
    ROUND(AVG(customer_tenure_days), 0) as avg_tenure_days
FROM customer_ltv
GROUP BY customer_segment;

-- View 3: Customer Risk Features (for ML)
CREATE OR REPLACE VIEW customer_risk_features AS
WITH customer_metrics AS (
    SELECT 
        c.customer_id,
        c.age,
        c.customer_segment,
        c.gender,
        EXTRACT(DAY FROM CURRENT_DATE ::TIMESTAMP - c.signup_date) as account_age_days,
        COUNT(DISTINCT sub.subscription_id) as num_subscriptions,
        SUM(CASE WHEN sub.is_active THEN 1 ELSE 0 END) as active_subscriptions,
        ROUND(AVG(sub.monthly_charges), 2) as avg_monthly_charges,
        ROUND(SUM(sub.total_charges), 2) as total_spent,
        MAX(CASE WHEN sub.churn_date IS NOT NULL THEN 1 ELSE 0 END) as has_churned,
        ROUND(AVG(um.data_usage_gb), 2) as avg_data_usage,
        ROUND(AVG(um.call_minutes), 0) as avg_call_minutes,
        SUM(um.support_tickets) as total_support_tickets,
        ROUND(AVG(um.satisfaction_score), 1) as avg_satisfaction,
        COUNT(p.payment_id) FILTER (WHERE p.payment_status = 'Failed') as failed_payments_count,
        ROUND(AVG(p.late_fee), 2) as avg_late_fees,
        BOOL_OR(sub.paperless_billing) as has_paperless_billing
    FROM customers c
    LEFT JOIN subscriptions sub ON c.customer_id = sub.customer_id
    LEFT JOIN usage_metrics um ON c.customer_id = um.customer_id 
        AND um.record_date >= CURRENT_DATE - INTERVAL '3 months'
    LEFT JOIN payments p ON c.customer_id = p.customer_id
    GROUP BY c.customer_id, c.age, c.customer_segment, c.signup_date, c.gender
)
SELECT 
    *,
    CASE 
        WHEN avg_satisfaction < 5 AND total_support_tickets > 2 THEN 'High Risk'
        WHEN avg_satisfaction < 7 OR failed_payments_count > 1 THEN 'Medium Risk'
        ELSE 'Low Risk'
    END as risk_category
FROM customer_metrics
WHERE avg_monthly_charges IS NOT NULL;

-- Test views
SELECT * FROM churn_analysis;
SELECT * FROM customer_risk_features LIMIT 10;

-- Check data completeness
SELECT 
    'customers' as table_name, COUNT(*) as record_count FROM customers
UNION ALL
SELECT 'subscriptions', COUNT(*) FROM subscriptions
UNION ALL
SELECT 'usage_metrics', COUNT(*) FROM usage_metrics
UNION ALL
SELECT 'payments', COUNT(*) FROM payments;

-- Check churn distribution
SELECT 
    has_churned,
    COUNT(*) as count,
    ROUND(AVG(total_spent), 2) as avg_revenue,
    ROUND(AVG(avg_satisfaction), 2) as avg_satisfaction
FROM customer_risk_features
GROUP BY has_churned;


-- Check if database exists
SELECT datname FROM pg_database WHERE datname = 'telecom_analytics';

-- Connect to telecom_analytics and run:
SELECT COUNT(*) FROM customers;
SELECT COUNT(*) FROM customer_risk_features;

-- If view doesn't exist, recreate it:
CREATE OR REPLACE VIEW customer_risk_features AS
WITH customer_metrics AS (
    SELECT 
        c.customer_id,
        c.age,
        c.customer_segment::text,
        c.gender::text,
        EXTRACT(DAY FROM CURRENT_DATE - c.signup_date) as account_age_days,
        COUNT(DISTINCT sub.subscription_id) as num_subscriptions,
        SUM(CASE WHEN sub.is_active THEN 1 ELSE 0 END) as active_subscriptions,
        ROUND(AVG(sub.monthly_charges), 2) as avg_monthly_charges,
        ROUND(SUM(sub.total_charges), 2) as total_spent,
        MAX(CASE WHEN sub.churn_date IS NOT NULL THEN 1 ELSE 0 END) as has_churned,
        ROUND(AVG(um.data_usage_gb), 2) as avg_data_usage,
        ROUND(AVG(um.call_minutes), 0) as avg_call_minutes,
        SUM(um.support_tickets) as total_support_tickets,
        ROUND(AVG(um.satisfaction_score), 1) as avg_satisfaction,
        COUNT(p.payment_id) FILTER (WHERE p.payment_status = 'Failed') as failed_payments_count,
        ROUND(AVG(p.late_fee), 2) as avg_late_fees,
        BOOL_OR(sub.paperless_billing) as has_paperless_billing
    FROM customers c
    LEFT JOIN subscriptions sub ON c.customer_id = sub.customer_id
    LEFT JOIN usage_metrics um ON c.customer_id = um.customer_id 
        AND um.record_date >= CURRENT_DATE - INTERVAL '3 months'
    LEFT JOIN payments p ON c.customer_id = p.customer_id
    GROUP BY c.customer_id, c.age, c.customer_segment, c.signup_date, c.gender
)
SELECT 
    *,
    CASE 
        WHEN avg_satisfaction < 5 AND total_support_tickets > 2 THEN 'High Risk'
        WHEN avg_satisfaction < 7 OR failed_payments_count > 1 THEN 'Medium Risk'
        ELSE 'Low Risk'
    END as risk_category
FROM customer_metrics
WHERE avg_monthly_charges IS NOT NULL;








-- ==========================================
-- STEP 1: DROP EVERYTHING (Clean slate)
-- ==========================================
DROP VIEW IF EXISTS customer_risk_features;
DROP VIEW IF EXISTS churn_analysis;
DROP VIEW IF EXISTS customer_ltv;
DROP TABLE IF EXISTS payments;
DROP TABLE IF EXISTS usage_metrics;
DROP TABLE IF EXISTS subscriptions;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS services;
DROP TYPE IF EXISTS payment_status_type;
DROP TYPE IF EXISTS payment_method_type;
DROP TYPE IF EXISTS service_type;
DROP TYPE IF EXISTS segment_type;
DROP TYPE IF EXISTS gender_type;

-- ==========================================
-- STEP 2: CREATE TYPES
-- ==========================================
CREATE TYPE gender_type AS ENUM ('Male', 'Female', 'Other');
CREATE TYPE segment_type AS ENUM ('Premium', 'Standard', 'Basic');
CREATE TYPE service_type AS ENUM ('Internet', 'Phone', 'TV', 'Bundle');
CREATE TYPE payment_method_type AS ENUM ('Credit Card', 'Bank Transfer', 'Electronic Check', 'Mailed Check');
CREATE TYPE payment_status_type AS ENUM ('Success', 'Failed', 'Pending', 'Refunded');

-- ==========================================
-- STEP 3: CREATE TABLES
-- ==========================================

-- Customers table
CREATE TABLE customers (
    customer_id SERIAL PRIMARY KEY,
    customer_name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE,
    phone VARCHAR(20),
    age INTEGER CHECK (age >= 18 AND age <= 100),
    gender gender_type,
    city VARCHAR(50),
    state VARCHAR(50),
    country VARCHAR(50) DEFAULT 'USA',
    signup_date DATE NOT NULL,
    customer_segment segment_type,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Services table
CREATE TABLE services (
    service_id SERIAL PRIMARY KEY,
    service_name VARCHAR(100) NOT NULL,
    service_type service_type,
    monthly_price DECIMAL(10,2) NOT NULL,
    setup_fee DECIMAL(10,2) DEFAULT 0,
    contract_length_months INTEGER DEFAULT 12
);

-- Subscriptions table (REMOVED UNIQUE constraint on customer_id!)
CREATE TABLE subscriptions (
    subscription_id SERIAL PRIMARY KEY,
    customer_id INTEGER REFERENCES customers(customer_id),
    service_id INTEGER REFERENCES services(service_id),
    start_date DATE NOT NULL,
    end_date DATE,
    monthly_charges DECIMAL(10,2) NOT NULL,
    total_charges DECIMAL(10,2),
    payment_method payment_method_type,
    paperless_billing BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    churn_date DATE,
    churn_reason VARCHAR(200),
    CONSTRAINT valid_dates CHECK (end_date IS NULL OR end_date >= start_date)
);

-- Usage metrics table
CREATE TABLE usage_metrics (
    metric_id SERIAL PRIMARY KEY,
    customer_id INTEGER REFERENCES customers(customer_id),
    record_date DATE NOT NULL,
    data_usage_gb DECIMAL(10,2),
    call_minutes INTEGER,
    support_tickets INTEGER DEFAULT 0,
    website_visits INTEGER DEFAULT 0,
    app_logins INTEGER DEFAULT 0,
    satisfaction_score INTEGER CHECK (satisfaction_score BETWEEN 1 AND 10),
    UNIQUE(customer_id, record_date)
);

-- Payments table (FIXED: reference customer_id, not subscription_id!)
CREATE TABLE payments (
    payment_id SERIAL PRIMARY KEY,
    customer_id INTEGER REFERENCES customers(customer_id),
    payment_date DATE NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    payment_status payment_status_type,
    late_fee DECIMAL(10,2) DEFAULT 0
);

-- Indexes
CREATE INDEX idx_customers_segment ON customers(customer_segment);
CREATE INDEX idx_subscriptions_active ON subscriptions(is_active);
CREATE INDEX idx_subscriptions_churn ON subscriptions(churn_date) WHERE churn_date IS NOT NULL;
CREATE INDEX idx_usage_customer_date ON usage_metrics(customer_id, record_date);
CREATE INDEX idx_payments_customer ON payments(customer_id);

-- ==========================================
-- STEP 4: INSERT DATA (IN CORRECT ORDER!)
-- ==========================================

-- Insert Services
INSERT INTO services (service_name, service_type, monthly_price, setup_fee, contract_length_months) VALUES
('Fiber Optic 100Mbps', 'Internet', 70.00, 50.00, 12),
('Fiber Optic 500Mbps', 'Internet', 90.00, 50.00, 12),
('Fiber Optic 1Gbps', 'Internet', 120.00, 0.00, 24),
('Basic TV Package', 'TV', 50.00, 30.00, 12),
('Premium TV Package', 'TV', 85.00, 30.00, 12),
('Unlimited Phone', 'Phone', 30.00, 20.00, 12),
('Triple Play Bundle', 'Bundle', 150.00, 100.00, 24),
('Double Play Bundle', 'Bundle', 110.00, 80.00, 12);

-- Insert 1000 Customers
INSERT INTO customers (customer_name, email, phone, age, gender, city, state, signup_date, customer_segment)
SELECT 
    'Customer_' || i,
    'customer' || i || '@gmail.com',
    '(' || (random() * 800 + 200)::int || ')' || (random() * 800 + 200)::int || '-' || (random() * 9000 + 1000)::int,
    (random() * 62 + 18)::int,
    CASE WHEN random() < 0.5 THEN 'Male'::gender_type ELSE 'Female'::gender_type END,
    (ARRAY['New York', 'Los Angeles', 'Chicago', 'Houston', 'Phoenix', 'Philadelphia', 'San Antonio', 'San Diego', 'Dallas', 'San Jose'])[(random() * 9 + 1)::int],
    (ARRAY['NY', 'CA', 'IL', 'TX', 'AZ', 'PA', 'TX', 'CA', 'TX', 'CA'])[(random() * 9 + 1)::int],
    CURRENT_DATE - (random() * 1095 + 30)::int,
    CASE 
        WHEN random() < 0.2 THEN 'Premium'::segment_type
        WHEN random() < 0.6 THEN 'Standard'::segment_type
        ELSE 'Basic'::segment_type
    END
FROM generate_series(1, 1000) AS i
ON CONFLICT (email) DO NOTHING;

-- ==========================================
-- STEP 5: INSERT SUBSCRIPTIONS (THIS WAS MISSING!)
-- ==========================================
INSERT INTO subscriptions (customer_id, service_id, start_date, monthly_charges, payment_method, paperless_billing, is_active, churn_date, churn_reason)
SELECT 
    c.customer_id,
    (random() * 7 + 1)::int,
    c.signup_date,
    (random() * 100 + 50)::decimal(10,2),
    (ARRAY['Credit Card', 'Bank Transfer', 'Electronic Check', 'Mailed Check']::payment_method_type[])[(random() * 3 + 1)::int],
    random() < 0.7,
    CASE WHEN random() < 0.73 THEN TRUE ELSE FALSE END,
    CASE 
        WHEN random() < 0.27 THEN c.signup_date + (random() * 500 + 30)::int
        ELSE NULL 
    END,
    CASE 
        WHEN random() < 0.27 THEN 
            (ARRAY['Competitor had better price', 'Service quality issues', 'Moved to new location', 'Dont use service enough', 'Deceased', 'Unknown'])[(random() * 5 + 1)::int]
        ELSE NULL 
    END
FROM customers c;

-- Update total_charges
UPDATE subscriptions 
SET total_charges = monthly_charges * 
    CASE 
        WHEN churn_date IS NOT NULL THEN GREATEST(1, EXTRACT(MONTH FROM AGE(churn_date, start_date)))
        ELSE GREATEST(1, EXTRACT(MONTH FROM AGE(CURRENT_DATE, start_date)))
    END;

-- ==========================================
-- STEP 6: INSERT USAGE METRICS (After subscriptions exist!)
-- ==========================================
INSERT INTO usage_metrics (customer_id, record_date, data_usage_gb, call_minutes, support_tickets, website_visits, app_logins, satisfaction_score)
SELECT 
    c.customer_id,
    dates.dt,
    CASE 
        WHEN random() < 0.1 THEN NULL
        WHEN s.service_type IN ('Internet', 'Bundle') THEN random() * 500 + 10
        ELSE random() * 50
    END,
    (random() * 1000)::int,
    (random() * 5)::int,
    (random() * 50)::int,
    (random() * 30)::int,
    CASE 
        WHEN sub.churn_date IS NOT NULL AND dates.dt > sub.churn_date - 30 THEN (random() * 3 + 1)::int
        ELSE (random() * 7 + 3)::int
    END
FROM customers c
JOIN subscriptions sub ON c.customer_id = sub.customer_id
JOIN services s ON sub.service_id = s.service_id
CROSS JOIN LATERAL generate_series(
    GREATEST(sub.start_date, CURRENT_DATE - INTERVAL '12 months'),
    LEAST(COALESCE(sub.churn_date, CURRENT_DATE), CURRENT_DATE),
    INTERVAL '1 month'
) AS dates(dt)
WHERE random() < 0.8;

-- ==========================================
-- STEP 7: INSERT PAYMENTS (Fixed foreign key!)
-- ==========================================
INSERT INTO payments (customer_id, payment_date, amount, payment_status, late_fee)
SELECT 
    sub.customer_id,
    generate_series(sub.start_date, COALESCE(sub.churn_date, CURRENT_DATE), INTERVAL '1 month')::date,
    sub.monthly_charges,
    CASE 
        WHEN random() < 0.85 THEN 'Success'::payment_status_type
        WHEN random() < 0.95 THEN 'Failed'::payment_status_type
        ELSE 'Pending'::payment_status_type
    END,
    CASE WHEN random() < 0.15 THEN sub.monthly_charges * 0.05 ELSE 0 END
FROM subscriptions sub;

-- ==========================================
-- STEP 8: CREATE VIEWS
-- ==========================================

-- View 1: Customer Lifetime Value
CREATE OR REPLACE VIEW customer_ltv AS
SELECT 
    c.customer_id,
    c.customer_name,
    c.customer_segment,
    c.signup_date,
    COUNT(DISTINCT sub.subscription_id) as total_subscriptions,
    SUM(sub.total_charges) as total_revenue,
    AVG(sub.monthly_charges) as avg_monthly_charges,
    MAX(sub.churn_date) as last_churn_date,
    CASE WHEN MAX(sub.churn_date) IS NULL THEN 'Active' ELSE 'Churned' END as current_status,
    EXTRACT(DAY FROM COALESCE(MAX(sub.churn_date), CURRENT_DATE)::TIMESTAMP - c.signup_date) as customer_tenure_days
FROM customers c
LEFT JOIN subscriptions sub ON c.customer_id = sub.customer_id
GROUP BY c.customer_id, c.customer_name, c.customer_segment, c.signup_date;

-- View 2: Churn Analysis
CREATE OR REPLACE VIEW churn_analysis AS
SELECT 
    customer_segment,
    COUNT(*) as total_customers,
    SUM(CASE WHEN current_status = 'Churned' THEN 1 ELSE 0 END) as churned_customers,
    ROUND(100.0 * SUM(CASE WHEN current_status = 'Churned' THEN 1 ELSE 0 END) / COUNT(*), 2) as churn_rate_pct,
    ROUND(AVG(total_revenue), 2) as avg_ltv,
    ROUND(AVG(customer_tenure_days), 0) as avg_tenure_days
FROM customer_ltv
GROUP BY customer_segment;

-- View 3: Customer Risk Features (FIXED: removed problematic WHERE clause)
CREATE OR REPLACE VIEW customer_risk_features AS
WITH customer_metrics AS (
    SELECT 
        c.customer_id,
        c.age,
        c.customer_segment::text,
        c.gender::text,
        EXTRACT(DAY FROM CURRENT_DATE::TIMESTAMP - c.signup_date) as account_age_days,
        COUNT(DISTINCT sub.subscription_id) as num_subscriptions,
        COALESCE(SUM(CASE WHEN sub.is_active THEN 1 ELSE 0 END), 0) as active_subscriptions,
        COALESCE(AVG(sub.monthly_charges), 0) as avg_monthly_charges,
        COALESCE(SUM(sub.total_charges), 0) as total_spent,
        MAX(CASE WHEN sub.churn_date IS NOT NULL THEN 1 ELSE 0 END) as has_churned,
        COALESCE(AVG(um.data_usage_gb), 0) as avg_data_usage,
        COALESCE(AVG(um.call_minutes), 0) as avg_call_minutes,
        COALESCE(SUM(um.support_tickets), 0) as total_support_tickets,
        COALESCE(AVG(um.satisfaction_score), 7) as avg_satisfaction,
        COALESCE(COUNT(p.payment_id) FILTER (WHERE p.payment_status = 'Failed'), 0) as failed_payments_count,
        COALESCE(AVG(p.late_fee), 0) as avg_late_fees,
        COALESCE(BOOL_OR(sub.paperless_billing), false) as has_paperless_billing
    FROM customers c
    LEFT JOIN subscriptions sub ON c.customer_id = sub.customer_id
    LEFT JOIN usage_metrics um ON c.customer_id = um.customer_id 
        AND um.record_date >= CURRENT_DATE - INTERVAL '3 months'
    LEFT JOIN payments p ON c.customer_id = p.customer_id
    GROUP BY c.customer_id, c.age, c.customer_segment, c.signup_date, c.gender
)
SELECT 
    *,
    CASE 
        WHEN avg_satisfaction < 5 AND total_support_tickets > 2 THEN 'High Risk'
        WHEN avg_satisfaction < 7 OR failed_payments_count > 1 THEN 'Medium Risk'
        ELSE 'Low Risk'
    END as risk_category
FROM customer_metrics;

-- ==========================================
-- STEP 9: VERIFY DATA
-- ==========================================
SELECT 'customers' as table_name, COUNT(*) as count FROM customers
UNION ALL SELECT 'subscriptions', COUNT(*) FROM subscriptions
UNION ALL SELECT 'usage_metrics', COUNT(*) FROM usage_metrics
UNION ALL SELECT 'payments', COUNT(*) FROM payments;

-- Check view
SELECT COUNT(*) as risk_features_count FROM customer_risk_features;
SELECT * FROM customer_risk_features LIMIT 5;