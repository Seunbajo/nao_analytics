-- Portfolio Health Analysis: Risk and Profitability Metrics
-- Date: 2026-03-17
-- Source: dbt-analytics-430021.dbt_solubajo.dummy_credit_portfolio

-- =====================================================
-- 1. COMPREHENSIVE PORTFOLIO HEALTH OVERVIEW
-- =====================================================

WITH portfolio_overview AS (
  SELECT
    COUNT(DISTINCT loan_id) as total_loans,
    COUNT(DISTINCT customer_id) as total_customers,
    SUM(loan_amount) as total_portfolio_value,
    AVG(loan_amount) as avg_loan_size,
    AVG(interest_rate) as avg_interest_rate,
    AVG(risk_score) as avg_risk_score,
    AVG(tenure_months) as avg_tenure_months
  FROM `dbt-analytics-430021.dbt_solubajo.dummy_credit_portfolio`
),

risk_metrics AS (
  SELECT
    -- Portfolio at Risk (PAR) Analysis
    COUNTIF(days_past_due > 0) as loans_in_arrears,
    COUNTIF(days_past_due > 30) as loans_par_30,
    COUNTIF(days_past_due > 60) as loans_par_60,
    COUNTIF(days_past_due > 90) as loans_par_90,
    
    SUM(CASE WHEN days_past_due > 0 THEN loan_amount ELSE 0 END) as amount_in_arrears,
    SUM(CASE WHEN days_past_due > 30 THEN loan_amount ELSE 0 END) as amount_par_30,
    SUM(CASE WHEN days_past_due > 60 THEN loan_amount ELSE 0 END) as amount_par_60,
    SUM(CASE WHEN days_past_due > 90 THEN loan_amount ELSE 0 END) as amount_par_90,
    
    -- Default and Loss Metrics
    COUNTIF(status = 'Defaulted') as defaulted_loans,
    SUM(CASE WHEN status = 'Defaulted' THEN loan_amount ELSE 0 END) as defaulted_amount,
    SUM(expected_loss) as total_expected_loss,
    SUM(actual_loss) as total_actual_loss,
    
    -- Risk Tier Distribution
    COUNTIF(risk_tier = 'High') as high_risk_loans,
    COUNTIF(risk_tier = 'Medium') as medium_risk_loans,
    COUNTIF(risk_tier = 'Low') as low_risk_loans,
    
    SUM(CASE WHEN risk_tier = 'High' THEN loan_amount ELSE 0 END) as high_risk_amount,
    SUM(CASE WHEN risk_tier = 'Medium' THEN loan_amount ELSE 0 END) as medium_risk_amount,
    SUM(CASE WHEN risk_tier = 'Low' THEN loan_amount ELSE 0 END) as low_risk_amount
  FROM `dbt-analytics-430021.dbt_solubajo.dummy_credit_portfolio`
),

profitability_metrics AS (
  SELECT
    -- Revenue Potential (Interest Income)
    SUM(loan_amount * interest_rate / 100) as estimated_annual_interest_income,
    
    -- Active vs Non-Performing
    SUM(CASE WHEN status = 'Active' THEN loan_amount ELSE 0 END) as active_portfolio_value,
    SUM(CASE WHEN status IN ('Defaulted', 'Written Off') THEN loan_amount ELSE 0 END) as non_performing_value,
    
    COUNTIF(status = 'Active') as active_loans,
    COUNTIF(status = 'Closed') as closed_loans,
    COUNTIF(status IN ('Defaulted', 'Written Off')) as non_performing_loans
  FROM `dbt-analytics-430021.dbt_solubajo.dummy_credit_portfolio`
)

SELECT
  -- Portfolio Overview
  po.total_loans,
  po.total_customers,
  po.total_portfolio_value,
  po.avg_loan_size,
  ROUND(po.avg_interest_rate, 2) as avg_interest_rate_pct,
  ROUND(po.avg_risk_score, 0) as avg_risk_score,
  ROUND(po.avg_tenure_months, 1) as avg_tenure_months,
  
  -- Risk Metrics - Counts
  rm.loans_in_arrears,
  rm.loans_par_30,
  rm.loans_par_60,
  rm.loans_par_90,
  rm.defaulted_loans,
  
  -- Risk Metrics - Amounts
  rm.amount_in_arrears,
  rm.amount_par_30,
  rm.amount_par_60,
  rm.amount_par_90,
  rm.defaulted_amount,
  
  -- Risk Ratios (%)
  ROUND(rm.loans_in_arrears / po.total_loans * 100, 2) as arrears_rate_pct,
  ROUND(rm.amount_in_arrears / po.total_portfolio_value * 100, 2) as par_rate_pct,
  ROUND(rm.amount_par_30 / po.total_portfolio_value * 100, 2) as par_30_rate_pct,
  ROUND(rm.amount_par_90 / po.total_portfolio_value * 100, 2) as par_90_rate_pct,
  ROUND(rm.defaulted_loans / po.total_loans * 100, 2) as default_rate_pct,
  ROUND(rm.defaulted_amount / po.total_portfolio_value * 100, 2) as default_amount_pct,
  
  -- Loss Metrics
  rm.total_expected_loss,
  rm.total_actual_loss,
  ROUND(rm.total_expected_loss / po.total_portfolio_value * 100, 2) as expected_loss_rate_pct,
  ROUND(rm.total_actual_loss / po.total_portfolio_value * 100, 2) as actual_loss_rate_pct,
  
  -- Risk Tier Distribution
  rm.high_risk_loans,
  rm.medium_risk_loans,
  rm.low_risk_loans,
  ROUND(rm.high_risk_loans / po.total_loans * 100, 2) as high_risk_pct,
  ROUND(rm.medium_risk_loans / po.total_loans * 100, 2) as medium_risk_pct,
  ROUND(rm.low_risk_loans / po.total_loans * 100, 2) as low_risk_pct,
  
  -- Profitability Metrics
  pm.estimated_annual_interest_income,
  pm.active_portfolio_value,
  pm.non_performing_value,
  pm.active_loans,
  pm.closed_loans,
  pm.non_performing_loans,
  
  -- Profitability Ratios
  ROUND(pm.active_loans / po.total_loans * 100, 2) as active_loan_pct,
  ROUND(pm.non_performing_loans / po.total_loans * 100, 2) as npl_ratio_pct,
  ROUND(pm.non_performing_value / po.total_portfolio_value * 100, 2) as npl_amount_pct,
  
  -- Net Profitability Indicator
  ROUND((pm.estimated_annual_interest_income - rm.total_actual_loss) / po.total_portfolio_value * 100, 2) as net_return_on_portfolio_pct

FROM portfolio_overview po
CROSS JOIN risk_metrics rm
CROSS JOIN profitability_metrics pm;


-- =====================================================
-- 2. PAR BUCKET DISTRIBUTION
-- =====================================================

SELECT 
  par_bucket,
  COUNT(*) as loan_count,
  SUM(loan_amount) as total_amount,
  ROUND(AVG(interest_rate), 2) as avg_interest_rate,
  ROUND(SUM(actual_loss), 2) as total_loss
FROM `dbt-analytics-430021.dbt_solubajo.dummy_credit_portfolio`
GROUP BY par_bucket
ORDER BY 
  CASE par_bucket
    WHEN 'Current' THEN 1
    WHEN 'PAR 1-30' THEN 2
    WHEN 'PAR 31-60' THEN 3
    WHEN 'PAR 61-90' THEN 4
    WHEN 'PAR 90+' THEN 5
    ELSE 6
  END;


-- =====================================================
-- 3. RISK TIER PROFITABILITY ANALYSIS
-- =====================================================

SELECT 
  risk_tier,
  COUNT(*) as loan_count,
  SUM(loan_amount) as portfolio_value,
  ROUND(AVG(interest_rate), 2) as avg_interest_rate,
  ROUND(SUM(loan_amount * interest_rate / 100), 2) as estimated_interest_income,
  ROUND(SUM(actual_loss), 2) as total_actual_loss,
  ROUND((SUM(loan_amount * interest_rate / 100) - SUM(actual_loss)) / SUM(loan_amount) * 100, 2) as net_return_pct
FROM `dbt-analytics-430021.dbt_solubajo.dummy_credit_portfolio`
GROUP BY risk_tier
ORDER BY 
  CASE risk_tier
    WHEN 'Low' THEN 1
    WHEN 'Medium' THEN 2
    WHEN 'High' THEN 3
    ELSE 4
  END;


-- =====================================================
-- 4. PRODUCT TYPE PERFORMANCE
-- =====================================================

SELECT 
  product_type,
  COUNT(*) as loan_count,
  SUM(loan_amount) as portfolio_value,
  ROUND(AVG(interest_rate), 2) as avg_interest_rate,
  COUNTIF(days_past_due > 30) as loans_par_30_plus,
  ROUND(SUM(CASE WHEN days_past_due > 30 THEN loan_amount ELSE 0 END) / SUM(loan_amount) * 100, 2) as par_30_rate_pct,
  ROUND(SUM(actual_loss) / SUM(loan_amount) * 100, 2) as loss_rate_pct,
  ROUND((SUM(loan_amount * interest_rate / 100) - SUM(actual_loss)) / SUM(loan_amount) * 100, 2) as net_return_pct
FROM `dbt-analytics-430021.dbt_solubajo.dummy_credit_portfolio`
GROUP BY product_type
ORDER BY portfolio_value DESC;


-- =====================================================
-- 5. MONTHLY ORIGINATION TREND
-- =====================================================

SELECT 
  FORMAT_DATE('%Y-%m', origination_date) as origination_month,
  COUNT(*) as loans_originated,
  SUM(loan_amount) as amount_originated,
  ROUND(AVG(risk_score), 0) as avg_risk_score,
  ROUND(SUM(CASE WHEN days_past_due > 30 THEN loan_amount ELSE 0 END) / SUM(loan_amount) * 100, 2) as par_30_rate_pct
FROM `dbt-analytics-430021.dbt_solubajo.dummy_credit_portfolio`
GROUP BY origination_month
ORDER BY origination_month;


-- =====================================================
-- KEY FINDINGS & RECOMMENDATIONS
-- =====================================================

/*
PORTFOLIO HEALTH SUMMARY:
- Total Portfolio: $65.5M across 300 loans
- Average Interest Rate: 20.5%
- Net Return on Portfolio: 19.95%

RISK METRICS:
- Arrears Rate: 49% (147 loans)
- PAR 30+ Rate: 12.39% ($8.1M)
- Actual Loss Rate: 0.67% ($438K)
- Default Rate: 0%

STRENGTHS:
✓ Strong profitability (19.95% net return)
✓ No defaults recorded
✓ Effective risk-based pricing
✓ Low actual loss rate

AREAS OF CONCERN:
⚠ High arrears rate (49%)
⚠ PAR 30+ above industry benchmark (12.39% vs 5-8%)
⚠ Volatile PAR rates across origination cohorts
⚠ No active loans (portfolio status unclear)

RECOMMENDATIONS:
1. Strengthen early-stage collections (PAR 1-30)
2. Review underwriting for March 2023 cohort (33.87% PAR30)
3. Monitor delinquency trends to prevent defaults
4. Investigate portfolio status (why no active loans?)
*/
