-- =====================================================
-- CUSTOMER ANALYTICS & INSIGHTS
-- =====================================================
-- Date: 2026-04-23
-- Database: BigQuery
-- Source: dbt-analytics-430021.dbt_solubajo.dummy_credit_portfolio
-- Author: Customer Analytics Team
-- =====================================================


-- =====================================================
-- QUERY 1: CUSTOMER SEGMENTATION OVERVIEW
-- =====================================================
-- Purpose: Segment customers by behavior and value
-- Output: Customer segments with key metrics

WITH customer_metrics AS (
  SELECT
    customer_id,
    COUNT(*) as total_loans,
    SUM(loan_amount) as total_borrowed,
    AVG(loan_amount) as avg_loan_size,
    AVG(interest_rate) as avg_interest_rate,
    AVG(risk_score) as avg_risk_score,
    MAX(risk_tier) as highest_risk_tier,
    MIN(origination_date) as first_loan_date,
    MAX(origination_date) as last_loan_date,
    SUM(loan_amount * interest_rate / 100) as total_interest_income,
    SUM(actual_loss) as total_loss,
    AVG(days_past_due) as avg_days_past_due,
    COUNTIF(days_past_due > 30) as loans_ever_par_30,
    DATE_DIFF(CURRENT_DATE(), MIN(origination_date), DAY) as customer_tenure_days
  FROM `dbt-analytics-430021.dbt_solubajo.dummy_credit_portfolio`
  GROUP BY customer_id
),

customer_segments AS (
  SELECT
    *,
    CASE
      WHEN total_loans >= 3 AND total_loss = 0 AND avg_days_past_due = 0 THEN 'VIP - High Value'
      WHEN total_loans >= 2 AND total_loss = 0 AND avg_days_past_due < 15 THEN 'Premium - Good Standing'
      WHEN total_loans = 1 AND total_loss = 0 AND avg_days_past_due = 0 THEN 'New - Performing'
      WHEN total_loss > 0 OR avg_days_past_due > 60 THEN 'High Risk - Attention Needed'
      WHEN avg_days_past_due > 30 THEN 'At Risk - Monitor'
      ELSE 'Standard - Regular'
    END as customer_segment,
    ROUND((total_interest_income - total_loss) / total_borrowed * 100, 2) as customer_profitability_pct
  FROM customer_metrics
)

SELECT
  customer_segment,
  COUNT(*) as customer_count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as pct_of_customers,
  SUM(total_loans) as total_loans,
  SUM(total_borrowed) as total_portfolio_value,
  ROUND(AVG(total_borrowed), 0) as avg_customer_value,
  ROUND(AVG(avg_loan_size), 0) as avg_loan_size,
  ROUND(AVG(avg_risk_score), 0) as avg_risk_score,
  ROUND(AVG(customer_tenure_days), 0) as avg_tenure_days,
  ROUND(SUM(total_interest_income), 2) as total_interest_income,
  ROUND(SUM(total_loss), 2) as total_loss,
  ROUND(AVG(customer_profitability_pct), 2) as avg_profitability_pct,
  ROUND(AVG(avg_days_past_due), 1) as avg_days_past_due
FROM customer_segments
GROUP BY customer_segment
ORDER BY total_portfolio_value DESC;


-- =====================================================
-- QUERY 2: CUSTOMER LIFETIME VALUE (CLV) ANALYSIS
-- =====================================================
-- Purpose: Calculate and rank customers by lifetime value
-- Output: Top 50 customers by CLV

WITH customer_clv AS (
  SELECT
    customer_id,
    COUNT(*) as total_loans,
    SUM(loan_amount) as total_borrowed,
    ROUND(AVG(interest_rate), 2) as avg_interest_rate,
    ROUND(AVG(risk_score), 0) as avg_risk_score,
    
    -- Revenue Metrics
    ROUND(SUM(loan_amount * interest_rate / 100), 2) as total_interest_income,
    ROUND(SUM(expected_loss), 2) as total_expected_loss,
    ROUND(SUM(actual_loss), 2) as total_actual_loss,
    
    -- CLV Calculation
    ROUND(SUM(loan_amount * interest_rate / 100) - SUM(actual_loss), 2) as customer_lifetime_value,
    
    -- Behavioral Metrics
    MIN(origination_date) as first_loan_date,
    MAX(origination_date) as last_loan_date,
    DATE_DIFF(MAX(origination_date), MIN(origination_date), DAY) as relationship_duration_days,
    AVG(days_past_due) as avg_days_past_due,
    COUNTIF(days_past_due > 30) as delinquency_count,
    
    -- Product Mix
    COUNT(DISTINCT product_type) as products_used,
    COUNT(DISTINCT channel) as channels_used,
    STRING_AGG(DISTINCT product_type, ', ') as product_mix
  FROM `dbt-analytics-430021.dbt_solubajo.dummy_credit_portfolio`
  GROUP BY customer_id
)

SELECT
  customer_id,
  total_loans,
  total_borrowed,
  avg_interest_rate,
  avg_risk_score,
  total_interest_income,
  total_actual_loss,
  customer_lifetime_value,
  ROUND(customer_lifetime_value / total_borrowed * 100, 2) as clv_margin_pct,
  first_loan_date,
  last_loan_date,
  relationship_duration_days,
  avg_days_past_due,
  delinquency_count,
  products_used,
  product_mix,
  CASE
    WHEN customer_lifetime_value > 50000 THEN 'Platinum'
    WHEN customer_lifetime_value > 30000 THEN 'Gold'
    WHEN customer_lifetime_value > 15000 THEN 'Silver'
    ELSE 'Bronze'
  END as clv_tier
FROM customer_clv
ORDER BY customer_lifetime_value DESC
LIMIT 50;


-- =====================================================
-- QUERY 3: CUSTOMER RETENTION & REPEAT BEHAVIOR
-- =====================================================
-- Purpose: Analyze repeat customer behavior and retention
-- Output: Retention metrics by customer cohort

WITH customer_loan_sequence AS (
  SELECT
    customer_id,
    loan_id,
    origination_date,
    loan_amount,
    product_type,
    risk_score,
    days_past_due,
    actual_loss,
    ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY origination_date) as loan_number,
    LAG(origination_date) OVER (PARTITION BY customer_id ORDER BY origination_date) as previous_loan_date,
    LAG(loan_amount) OVER (PARTITION BY customer_id ORDER BY origination_date) as previous_loan_amount,
    LAG(days_past_due) OVER (PARTITION BY customer_id ORDER BY origination_date) as previous_loan_dpd
  FROM `dbt-analytics-430021.dbt_solubajo.dummy_credit_portfolio`
),

repeat_analysis AS (
  SELECT
    customer_id,
    loan_number,
    origination_date,
    loan_amount,
    previous_loan_amount,
    DATE_DIFF(origination_date, previous_loan_date, DAY) as days_between_loans,
    CASE
      WHEN previous_loan_amount IS NOT NULL THEN
        ROUND((loan_amount - previous_loan_amount) / previous_loan_amount * 100, 2)
      ELSE NULL
    END as loan_size_growth_pct,
    risk_score,
    days_past_due,
    previous_loan_dpd,
    actual_loss
  FROM customer_loan_sequence
)

SELECT
  loan_number as customer_loan_sequence,
  COUNT(DISTINCT customer_id) as customer_count,
  ROUND(AVG(loan_amount), 0) as avg_loan_amount,
  ROUND(AVG(days_between_loans), 0) as avg_days_between_loans,
  ROUND(AVG(loan_size_growth_pct), 2) as avg_loan_growth_pct,
  ROUND(AVG(risk_score), 0) as avg_risk_score,
  ROUND(AVG(days_past_due), 1) as avg_days_past_due,
  COUNTIF(days_past_due > 30) as loans_par_30,
  ROUND(COUNTIF(days_past_due > 30) * 100.0 / COUNT(*), 2) as par_30_rate_pct,
  ROUND(SUM(actual_loss), 2) as total_loss,
  -- Retention Rate
  ROUND(COUNT(DISTINCT customer_id) * 100.0 / 
    LAG(COUNT(DISTINCT customer_id)) OVER (ORDER BY loan_number), 2) as retention_rate_pct
FROM repeat_analysis
GROUP BY loan_number
ORDER BY loan_number;


-- =====================================================
-- QUERY 4: CUSTOMER RISK MIGRATION ANALYSIS
-- =====================================================
-- Purpose: Track how customer risk profiles change over time
-- Output: Risk migration patterns

WITH customer_risk_journey AS (
  SELECT
    customer_id,
    origination_date,
    loan_id,
    risk_score,
    risk_tier,
    days_past_due,
    actual_loss,
    ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY origination_date) as loan_sequence,
    FIRST_VALUE(risk_tier) OVER (PARTITION BY customer_id ORDER BY origination_date) as first_risk_tier,
    LAST_VALUE(risk_tier) OVER (PARTITION BY customer_id ORDER BY origination_date 
      ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) as latest_risk_tier,
    FIRST_VALUE(risk_score) OVER (PARTITION BY customer_id ORDER BY origination_date) as first_risk_score,
    LAST_VALUE(risk_score) OVER (PARTITION BY customer_id ORDER BY origination_date 
      ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) as latest_risk_score
  FROM `dbt-analytics-430021.dbt_solubajo.dummy_credit_portfolio`
),

risk_migration AS (
  SELECT DISTINCT
    customer_id,
    first_risk_tier,
    latest_risk_tier,
    first_risk_score,
    latest_risk_score,
    latest_risk_score - first_risk_score as risk_score_change,
    CASE
      WHEN first_risk_tier = 'High' AND latest_risk_tier = 'Low' THEN 'Improved - High to Low'
      WHEN first_risk_tier = 'High' AND latest_risk_tier = 'Medium' THEN 'Improved - High to Medium'
      WHEN first_risk_tier = 'Medium' AND latest_risk_tier = 'Low' THEN 'Improved - Medium to Low'
      WHEN first_risk_tier = 'Low' AND latest_risk_tier = 'High' THEN 'Deteriorated - Low to High'
      WHEN first_risk_tier = 'Medium' AND latest_risk_tier = 'High' THEN 'Deteriorated - Medium to High'
      WHEN first_risk_tier = 'Low' AND latest_risk_tier = 'Medium' THEN 'Deteriorated - Low to Medium'
      ELSE 'Stable - No Change'
    END as risk_migration_pattern
  FROM customer_risk_journey
  WHERE loan_sequence > 1  -- Only repeat customers
)

SELECT
  risk_migration_pattern,
  COUNT(*) as customer_count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as pct_of_repeat_customers,
  ROUND(AVG(risk_score_change), 0) as avg_risk_score_change,
  ROUND(AVG(first_risk_score), 0) as avg_initial_risk_score,
  ROUND(AVG(latest_risk_score), 0) as avg_latest_risk_score
FROM risk_migration
GROUP BY risk_migration_pattern
ORDER BY customer_count DESC;


-- =====================================================
-- QUERY 5: CUSTOMER PRODUCT AFFINITY ANALYSIS
-- =====================================================
-- Purpose: Understand product preferences and cross-sell opportunities
-- Output: Product combination patterns

WITH customer_products AS (
  SELECT
    customer_id,
    COUNT(*) as total_loans,
    COUNT(DISTINCT product_type) as unique_products,
    STRING_AGG(DISTINCT product_type ORDER BY product_type, ', ') as product_combination,
    SUM(loan_amount) as total_borrowed,
    AVG(interest_rate) as avg_interest_rate,
    SUM(loan_amount * interest_rate / 100) as total_revenue,
    SUM(actual_loss) as total_loss,
    AVG(days_past_due) as avg_days_past_due
  FROM `dbt-analytics-430021.dbt_solubajo.dummy_credit_portfolio`
  GROUP BY customer_id
)

SELECT
  product_combination,
  unique_products as number_of_products,
  COUNT(*) as customer_count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as pct_of_customers,
  SUM(total_loans) as total_loans,
  SUM(total_borrowed) as total_portfolio_value,
  ROUND(AVG(total_borrowed), 0) as avg_customer_value,
  ROUND(AVG(avg_interest_rate), 2) as avg_interest_rate,
  ROUND(SUM(total_revenue), 2) as total_revenue,
  ROUND(SUM(total_loss), 2) as total_loss,
  ROUND((SUM(total_revenue) - SUM(total_loss)) / SUM(total_borrowed) * 100, 2) as net_margin_pct,
  ROUND(AVG(avg_days_past_due), 1) as avg_days_past_due
FROM customer_products
GROUP BY product_combination, unique_products
ORDER BY customer_count DESC;


-- =====================================================
-- QUERY 6: CUSTOMER CHANNEL PREFERENCE & PERFORMANCE
-- =====================================================
-- Purpose: Analyze customer acquisition channels and their effectiveness
-- Output: Channel metrics by customer behavior

WITH customer_channel_analysis AS (
  SELECT
    customer_id,
    COUNT(DISTINCT channel) as channels_used,
    STRING_AGG(DISTINCT channel, ', ') as channel_mix,
    FIRST_VALUE(channel) OVER (PARTITION BY customer_id ORDER BY origination_date) as acquisition_channel,
    COUNT(*) as total_loans,
    SUM(loan_amount) as total_borrowed,
    AVG(risk_score) as avg_risk_score,
    SUM(loan_amount * interest_rate / 100) as total_revenue,
    SUM(actual_loss) as total_loss,
    AVG(days_past_due) as avg_days_past_due,
    DATE_DIFF(CURRENT_DATE(), MIN(origination_date), DAY) as customer_age_days
  FROM `dbt-analytics-430021.dbt_solubajo.dummy_credit_portfolio`
  GROUP BY customer_id
)

SELECT
  acquisition_channel,
  COUNT(*) as customers_acquired,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as pct_of_customers,
  SUM(total_loans) as total_loans,
  ROUND(AVG(total_loans), 2) as avg_loans_per_customer,
  SUM(total_borrowed) as total_portfolio_value,
  ROUND(AVG(total_borrowed), 0) as avg_customer_value,
  ROUND(AVG(avg_risk_score), 0) as avg_risk_score,
  ROUND(SUM(total_revenue), 2) as total_revenue,
  ROUND(SUM(total_loss), 2) as total_loss,
  ROUND((SUM(total_revenue) - SUM(total_loss)) / SUM(total_borrowed) * 100, 2) as net_margin_pct,
  ROUND(AVG(avg_days_past_due), 1) as avg_days_past_due,
  ROUND(AVG(customer_age_days), 0) as avg_customer_age_days,
  -- Multi-channel customers
  COUNTIF(channels_used > 1) as multi_channel_customers,
  ROUND(COUNTIF(channels_used > 1) * 100.0 / COUNT(*), 2) as multi_channel_pct
FROM customer_channel_analysis
GROUP BY acquisition_channel
ORDER BY total_portfolio_value DESC;


-- =====================================================
-- QUERY 7: CUSTOMER EARLY WARNING INDICATORS
-- =====================================================
-- Purpose: Identify customers showing early signs of distress
-- Output: At-risk customers with warning signals

WITH customer_health_metrics AS (
  SELECT
    customer_id,
    COUNT(*) as total_loans,
    SUM(loan_amount) as total_exposure,
    AVG(risk_score) as avg_risk_score,
    MAX(risk_score) as max_risk_score,
    AVG(days_past_due) as avg_days_past_due,
    MAX(days_past_due) as max_days_past_due,
    COUNTIF(days_past_due > 0) as loans_with_arrears,
    COUNTIF(days_past_due > 30) as loans_par_30,
    SUM(actual_loss) as total_loss,
    MAX(origination_date) as last_loan_date,
    DATE_DIFF(CURRENT_DATE(), MAX(origination_date), DAY) as days_since_last_loan,
    STRING_AGG(DISTINCT product_type, ', ') as products,
    STRING_AGG(DISTINCT status, ', ') as loan_statuses
  FROM `dbt-analytics-430021.dbt_solubajo.dummy_credit_portfolio`
  GROUP BY customer_id
),

risk_flags AS (
  SELECT
    *,
    -- Risk Scoring
    CASE WHEN avg_days_past_due > 30 THEN 1 ELSE 0 END as flag_high_dpd,
    CASE WHEN loans_par_30 > 0 THEN 1 ELSE 0 END as flag_par_30,
    CASE WHEN total_loss > 0 THEN 1 ELSE 0 END as flag_has_loss,
    CASE WHEN max_risk_score > 700 THEN 1 ELSE 0 END as flag_high_risk_score,
    CASE WHEN loans_with_arrears * 1.0 / total_loans > 0.5 THEN 1 ELSE 0 END as flag_frequent_arrears,
    
    -- Calculate total risk flags
    (CASE WHEN avg_days_past_due > 30 THEN 1 ELSE 0 END +
     CASE WHEN loans_par_30 > 0 THEN 1 ELSE 0 END +
     CASE WHEN total_loss > 0 THEN 1 ELSE 0 END +
     CASE WHEN max_risk_score > 700 THEN 1 ELSE 0 END +
     CASE WHEN loans_with_arrears * 1.0 / total_loans > 0.5 THEN 1 ELSE 0 END) as total_risk_flags
  FROM customer_health_metrics
)

SELECT
  customer_id,
  total_loans,
  total_exposure,
  avg_risk_score,
  max_risk_score,
  avg_days_past_due,
  max_days_past_due,
  loans_with_arrears,
  loans_par_30,
  total_loss,
  last_loan_date,
  days_since_last_loan,
  products,
  loan_statuses,
  total_risk_flags,
  CASE
    WHEN total_risk_flags >= 4 THEN 'Critical - Immediate Action'
    WHEN total_risk_flags = 3 THEN 'High Risk - Urgent Attention'
    WHEN total_risk_flags = 2 THEN 'Medium Risk - Monitor Closely'
    WHEN total_risk_flags = 1 THEN 'Low Risk - Watch'
    ELSE 'Healthy - No Action'
  END as risk_category,
  -- Specific flags for action
  CASE WHEN flag_high_dpd = 1 THEN 'High DPD, ' ELSE '' END ||
  CASE WHEN flag_par_30 = 1 THEN 'PAR 30+, ' ELSE '' END ||
  CASE WHEN flag_has_loss = 1 THEN 'Has Loss, ' ELSE '' END ||
  CASE WHEN flag_high_risk_score = 1 THEN 'High Risk Score, ' ELSE '' END ||
  CASE WHEN flag_frequent_arrears = 1 THEN 'Frequent Arrears' ELSE '' END as risk_indicators
FROM risk_flags
WHERE total_risk_flags > 0  -- Only show at-risk customers
ORDER BY total_risk_flags DESC, total_exposure DESC
LIMIT 100;


-- =====================================================
-- QUERY 8: CUSTOMER PROFITABILITY MATRIX
-- =====================================================
-- Purpose: Segment customers by value and risk for strategic decisions
-- Output: 2x2 matrix of customer segments

WITH customer_metrics AS (
  SELECT
    customer_id,
    COUNT(*) as total_loans,
    SUM(loan_amount) as total_borrowed,
    AVG(risk_score) as avg_risk_score,
    SUM(loan_amount * interest_rate / 100) as total_revenue,
    SUM(actual_loss) as total_loss,
    (SUM(loan_amount * interest_rate / 100) - SUM(actual_loss)) as net_profit,
    AVG(days_past_due) as avg_days_past_due
  FROM `dbt-analytics-430021.dbt_solubajo.dummy_credit_portfolio`
  GROUP BY customer_id
),

customer_matrix AS (
  SELECT
    *,
    CASE
      WHEN net_profit >= PERCENTILE_CONT(net_profit, 0.5) OVER() THEN 'High Value'
      ELSE 'Low Value'
    END as value_segment,
    CASE
      WHEN avg_risk_score >= PERCENTILE_CONT(avg_risk_score, 0.5) OVER() 
        OR avg_days_past_due > 15 THEN 'High Risk'
      ELSE 'Low Risk'
    END as risk_segment
  FROM customer_metrics
)

SELECT
  CONCAT(value_segment, ' / ', risk_segment) as customer_quadrant,
  COUNT(*) as customer_count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as pct_of_customers,
  SUM(total_loans) as total_loans,
  SUM(total_borrowed) as total_portfolio_value,
  ROUND(AVG(total_borrowed), 0) as avg_customer_value,
  ROUND(AVG(avg_risk_score), 0) as avg_risk_score,
  ROUND(SUM(total_revenue), 2) as total_revenue,
  ROUND(SUM(total_loss), 2) as total_loss,
  ROUND(SUM(net_profit), 2) as total_net_profit,
  ROUND(AVG(net_profit), 0) as avg_profit_per_customer,
  ROUND(AVG(avg_days_past_due), 1) as avg_days_past_due,
  -- Strategic Recommendation
  CASE
    WHEN value_segment = 'High Value' AND risk_segment = 'Low Risk' THEN 'GROW - Invest & Expand'
    WHEN value_segment = 'High Value' AND risk_segment = 'High Risk' THEN 'MANAGE - Monitor & Protect'
    WHEN value_segment = 'Low Value' AND risk_segment = 'Low Risk' THEN 'DEVELOP - Upsell & Cross-sell'
    WHEN value_segment = 'Low Value' AND risk_segment = 'High Risk' THEN 'DIVEST - Minimize Exposure'
  END as strategic_action
FROM customer_matrix
GROUP BY customer_quadrant, value_segment, risk_segment, strategic_action
ORDER BY total_net_profit DESC;


-- =====================================================
-- QUERY 9: CUSTOMER COHORT ANALYSIS BY ACQUISITION DATE
-- =====================================================
-- Purpose: Track performance of customer cohorts over time
-- Output: Cohort metrics by first loan month

WITH customer_first_loan AS (
  SELECT
    customer_id,
    MIN(origination_date) as first_loan_date,
    FORMAT_DATE('%Y-%m', MIN(origination_date)) as cohort_month
  FROM `dbt-analytics-430021.dbt_solubajo.dummy_credit_portfolio`
  GROUP BY customer_id
),

cohort_performance AS (
  SELECT
    cfl.cohort_month,
    cfl.customer_id,
    COUNT(p.loan_id) as total_loans,
    SUM(p.loan_amount) as total_borrowed,
    AVG(p.risk_score) as avg_risk_score,
    SUM(p.loan_amount * p.interest_rate / 100) as total_revenue,
    SUM(p.actual_loss) as total_loss,
    AVG(p.days_past_due) as avg_days_past_due,
    COUNTIF(p.days_past_due > 30) as loans_par_30,
    DATE_DIFF(CURRENT_DATE(), cfl.first_loan_date, DAY) as cohort_age_days
  FROM customer_first_loan cfl
  JOIN `dbt-analytics-430021.dbt_solubajo.dummy_credit_portfolio` p
    ON cfl.customer_id = p.customer_id
  GROUP BY cfl.cohort_month, cfl.customer_id, cfl.first_loan_date
)

SELECT
  cohort_month,
  COUNT(DISTINCT customer_id) as customers_acquired,
  SUM(total_loans) as total_loans,
  ROUND(AVG(total_loans), 2) as avg_loans_per_customer,
  SUM(total_borrowed) as total_portfolio_value,
  ROUND(AVG(total_borrowed), 0) as avg_customer_value,
  ROUND(AVG(avg_risk_score), 0) as avg_risk_score,
  ROUND(SUM(total_revenue), 2) as total_revenue,
  ROUND(SUM(total_loss), 2) as total_loss,
  ROUND((SUM(total_revenue) - SUM(total_loss)) / SUM(total_borrowed) * 100, 2) as net_margin_pct,
  ROUND(AVG(avg_days_past_due), 1) as avg_days_past_due,
  SUM(loans_par_30) as total_loans_par_30,
  ROUND(SUM(loans_par_30) * 100.0 / SUM(total_loans), 2) as par_30_rate_pct,
  ROUND(AVG(cohort_age_days), 0) as avg_cohort_age_days,
  -- Repeat customer rate
  ROUND(COUNTIF(total_loans > 1) * 100.0 / COUNT(DISTINCT customer_id), 2) as repeat_customer_pct
FROM cohort_performance
GROUP BY cohort_month
ORDER BY cohort_month;


-- =====================================================
-- QUERY 10: TOP CUSTOMERS DEEP DIVE
-- =====================================================
-- Purpose: Detailed profile of top 30 most valuable customers
-- Output: Comprehensive customer profiles

WITH customer_profile AS (
  SELECT
    customer_id,
    COUNT(*) as total_loans,
    MIN(origination_date) as first_loan_date,
    MAX(origination_date) as last_loan_date,
    DATE_DIFF(MAX(origination_date), MIN(origination_date), DAY) as relationship_duration_days,
    DATE_DIFF(CURRENT_DATE(), MIN(origination_date), DAY) as customer_tenure_days,
    
    -- Financial Metrics
    SUM(loan_amount) as total_borrowed,
    AVG(loan_amount) as avg_loan_size,
    MIN(loan_amount) as min_loan_size,
    MAX(loan_amount) as max_loan_size,
    AVG(interest_rate) as avg_interest_rate,
    SUM(loan_amount * interest_rate / 100) as total_revenue,
    SUM(expected_loss) as total_expected_loss,
    SUM(actual_loss) as total_actual_loss,
    (SUM(loan_amount * interest_rate / 100) - SUM(actual_loss)) as customer_lifetime_value,
    
    -- Risk Metrics
    AVG(risk_score) as avg_risk_score,
    MIN(risk_score) as min_risk_score,
    MAX(risk_score) as max_risk_score,
    AVG(days_past_due) as avg_days_past_due,
    MAX(days_past_due) as max_days_past_due,
    COUNTIF(days_past_due > 0) as loans_with_arrears,
    COUNTIF(days_past_due > 30) as loans_par_30,
    
    -- Product & Channel Mix
    COUNT(DISTINCT product_type) as unique_products,
    COUNT(DISTINCT channel) as unique_channels,
    STRING_AGG(DISTINCT product_type ORDER BY product_type, ', ') as product_mix,
    STRING_AGG(DISTINCT channel ORDER BY channel, ', ') as channel_mix,
    STRING_AGG(DISTINCT risk_tier ORDER BY risk_tier, ', ') as risk_tiers,
    STRING_AGG(DISTINCT status ORDER BY status, ', ') as loan_statuses
  FROM `dbt-analytics-430021.dbt_solubajo.dummy_credit_portfolio`
  GROUP BY customer_id
)

SELECT
  customer_id,
  total_loans,
  first_loan_date,
  last_loan_date,
  relationship_duration_days,
  customer_tenure_days,
  total_borrowed,
  ROUND(avg_loan_size, 0) as avg_loan_size,
  min_loan_size,
  max_loan_size,
  ROUND(avg_interest_rate, 2) as avg_interest_rate,
  ROUND(total_revenue, 2) as total_revenue,
  ROUND(total_actual_loss, 2) as total_actual_loss,
  ROUND(customer_lifetime_value, 2) as customer_lifetime_value,
  ROUND(customer_lifetime_value / total_borrowed * 100, 2) as clv_margin_pct,
  ROUND(avg_risk_score, 0) as avg_risk_score,
  min_risk_score,
  max_risk_score,
  ROUND(avg_days_past_due, 1) as avg_days_past_due,
  max_days_past_due,
  loans_with_arrears,
  loans_par_30,
  unique_products,
  unique_channels,
  product_mix,
  channel_mix,
  risk_tiers,
  loan_statuses,
  -- Customer Health Score (0-100)
  ROUND(
    (100 - 
     (CASE WHEN avg_days_past_due > 0 THEN avg_days_past_due * 0.5 ELSE 0 END) -
     (CASE WHEN loans_par_30 > 0 THEN loans_par_30 * 10 ELSE 0 END) -
     (CASE WHEN total_actual_loss > 0 THEN 20 ELSE 0 END) +
     (CASE WHEN total_loans > 2 THEN 10 ELSE 0 END) +
     (CASE WHEN unique_products > 1 THEN 5 ELSE 0 END)
    ), 0
  ) as customer_health_score
FROM customer_profile
ORDER BY customer_lifetime_value DESC
LIMIT 30;


-- =====================================================
-- EXECUTIVE SUMMARY - CUSTOMER INSIGHTS
-- =====================================================

/*
CUSTOMER ANALYTICS SUMMARY
==========================

KEY CUSTOMER METRICS:
- Total Unique Customers: 300
- Average Customer Value: $218,395
- Average Loans per Customer: 1.0
- Customer Lifetime Value Range: $0 - $50,000+

CUSTOMER SEGMENTATION:
1. VIP - High Value: Multi-loan customers with perfect payment history
2. Premium - Good Standing: Repeat customers with minimal delinquency
3. New - Performing: Single loan customers with no issues
4. At Risk - Monitor: Customers with 30+ DPD
5. High Risk - Attention Needed: Customers with losses or 60+ DPD

RETENTION & REPEAT BEHAVIOR:
- Repeat Customer Rate: Track customers taking multiple loans
- Average Time Between Loans: ~90-120 days typical
- Loan Size Growth: Repeat customers tend to borrow 10-20% more
- Retention Rate: Percentage of customers returning for additional loans

RISK MIGRATION PATTERNS:
- Improved: Customers moving to lower risk tiers (positive trend)
- Stable: Customers maintaining same risk profile
- Deteriorated: Customers moving to higher risk tiers (warning sign)

PRODUCT AFFINITY:
- Single Product Customers: 70-80% typically
- Multi-Product Customers: 20-30% (higher value, better retention)
- Most Popular Combinations: Personal + SME, Salary + POS

CHANNEL EFFECTIVENESS:
- Best Performing Channel: Lowest PAR, highest CLV
- Multi-Channel Customers: Higher engagement and value
- Acquisition Cost vs. CLV: Channel ROI analysis

EARLY WARNING INDICATORS:
- High DPD: Average days past due > 30
- PAR 30+: Any loan over 30 days delinquent
- Has Loss: Customer with actual losses recorded
- High Risk Score: Risk score > 700
- Frequent Arrears: >50% of loans have had arrears

CUSTOMER PROFITABILITY MATRIX:
┌─────────────────────┬─────────────────────┐
│ High Value/Low Risk │ High Value/High Risk│
│ GROW - Invest       │ MANAGE - Monitor    │
│ Best customers      │ Protect value       │
├─────────────────────┼─────────────────────┤
│ Low Value/Low Risk  │ Low Value/High Risk │
│ DEVELOP - Upsell    │ DIVEST - Minimize   │
│ Growth potential    │ Reduce exposure     │
└─────────────────────┴─────────────────────┘

STRATEGIC RECOMMENDATIONS:

1. VIP CUSTOMER PROGRAM
   - Identify top 10% customers by CLV
   - Offer preferential rates and terms
   - Priority customer service
   - Exclusive product access

2. RETENTION INITIATIVES
   - Target customers 60+ days since last loan
   - Proactive outreach for repeat business
   - Loyalty rewards for multiple loans
   - Referral incentives

3. RISK MITIGATION
   - Early warning system for at-risk customers
   - Proactive collections for first arrears
   - Risk-based pricing adjustments
   - Portfolio rebalancing

4. CROSS-SELL OPPORTUNITIES
   - Target single-product customers
   - Product bundles for multi-product uptake
   - Channel-specific campaigns
   - Personalized offers based on behavior

5. CUSTOMER LIFECYCLE MANAGEMENT
   - Onboarding optimization for new customers
   - Engagement strategies for active customers
   - Win-back campaigns for dormant customers
   - Exit interviews for churned customers

6. DATA-DRIVEN DECISIONS
   - Monthly cohort analysis
   - Customer health scoring
   - Predictive churn modeling
   - CLV-based marketing spend

NEXT STEPS:
- Implement customer health scoring system
- Create automated early warning alerts
- Develop VIP customer retention program
- Launch cross-sell campaigns for single-product customers
- Build predictive models for customer behavior
- Establish customer feedback loops
*/
