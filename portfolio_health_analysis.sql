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
-- 6. CHANNEL PERFORMANCE ANALYSIS
-- =====================================================
-- Purpose: Compare acquisition channels by risk and profitability
-- Output: Multiple rows by channel

SELECT 
  channel,
  COUNT(*) as loan_count,
  SUM(loan_amount) as portfolio_value,
  ROUND(AVG(loan_amount), 0) as avg_loan_size,
  ROUND(AVG(interest_rate), 2) as avg_interest_rate,
  
  -- Risk Distribution
  COUNTIF(risk_tier = 'Low') as low_risk_count,
  COUNTIF(risk_tier = 'Medium') as medium_risk_count,
  COUNTIF(risk_tier = 'High') as high_risk_count,
  
  -- Performance
  ROUND(SUM(CASE WHEN days_past_due > 30 THEN loan_amount ELSE 0 END) / SUM(loan_amount) * 100, 2) as par_30_rate_pct,
  ROUND(SUM(actual_loss) / SUM(loan_amount) * 100, 2) as loss_rate_pct,
  ROUND((SUM(loan_amount * interest_rate / 100) - SUM(actual_loss)) / SUM(loan_amount) * 100, 2) as net_return_pct
FROM `dbt-analytics-430021.dbt_solubajo.dummy_credit_portfolio`
GROUP BY channel
ORDER BY portfolio_value DESC;


-- =====================================================
-- 7. LOAN STATUS BREAKDOWN
-- =====================================================
-- Purpose: Understand current status distribution
-- Output: Multiple rows by status

SELECT 
  status,
  COUNT(*) as loan_count,
  SUM(loan_amount) as total_amount,
  ROUND(AVG(loan_amount), 0) as avg_loan_size,
  ROUND(AVG(days_past_due), 0) as avg_days_past_due,
  ROUND(SUM(actual_loss), 2) as total_actual_loss,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as pct_of_total_loans,
  ROUND(SUM(loan_amount) * 100.0 / SUM(SUM(loan_amount)) OVER(), 2) as pct_of_total_amount
FROM `dbt-analytics-430021.dbt_solubajo.dummy_credit_portfolio`
GROUP BY status
ORDER BY loan_count DESC;


-- =====================================================
-- 8. HIGH-RISK LOANS DEEP DIVE
-- =====================================================
-- Purpose: Identify and analyze high-risk exposures
-- Output: Top 20 highest risk loans

SELECT 
  loan_id,
  customer_id,
  product_type,
  channel,
  loan_amount,
  interest_rate,
  risk_score,
  risk_tier,
  days_past_due,
  par_bucket,
  status,
  origination_date,
  expected_loss,
  actual_loss,
  ROUND(actual_loss / NULLIF(loan_amount, 0) * 100, 2) as loss_rate_pct
FROM `dbt-analytics-430021.dbt_solubajo.dummy_credit_portfolio`
WHERE risk_tier = 'High' 
  OR days_past_due > 60
  OR actual_loss > 0
ORDER BY 
  CASE 
    WHEN days_past_due > 90 THEN 1
    WHEN days_past_due > 60 THEN 2
    WHEN days_past_due > 30 THEN 3
    ELSE 4
  END,
  loan_amount DESC
LIMIT 20;


-- =====================================================
-- 9. PORTFOLIO CONCENTRATION ANALYSIS
-- =====================================================
-- Purpose: Identify concentration risks
-- Output: Top customers by exposure

SELECT 
  customer_id,
  COUNT(*) as number_of_loans,
  SUM(loan_amount) as total_exposure,
  ROUND(AVG(interest_rate), 2) as avg_interest_rate,
  ROUND(AVG(risk_score), 0) as avg_risk_score,
  MAX(risk_tier) as highest_risk_tier,
  SUM(CASE WHEN days_past_due > 30 THEN 1 ELSE 0 END) as loans_par_30_plus,
  ROUND(SUM(actual_loss), 2) as total_loss,
  ROUND(SUM(loan_amount) * 100.0 / (SELECT SUM(loan_amount) FROM `dbt-analytics-430021.dbt_solubajo.dummy_credit_portfolio`), 2) as pct_of_portfolio
FROM `dbt-analytics-430021.dbt_solubajo.dummy_credit_portfolio`
GROUP BY customer_id
HAVING COUNT(*) > 1
ORDER BY total_exposure DESC
LIMIT 20;


-- =====================================================
-- 10. RISK SCORE VS ACTUAL PERFORMANCE
-- =====================================================
-- Purpose: Validate risk scoring model effectiveness
-- Output: Performance by risk score bands

SELECT 
  CASE 
    WHEN risk_score < 600 THEN '< 600'
    WHEN risk_score < 650 THEN '600-649'
    WHEN risk_score < 700 THEN '650-699'
    WHEN risk_score < 750 THEN '700-749'
    ELSE '750+'
  END as risk_score_band,
  COUNT(*) as loan_count,
  SUM(loan_amount) as portfolio_value,
  ROUND(AVG(interest_rate), 2) as avg_interest_rate,
  
  -- Actual Performance
  ROUND(SUM(CASE WHEN days_past_due > 30 THEN loan_amount ELSE 0 END) / SUM(loan_amount) * 100, 2) as par_30_rate_pct,
  ROUND(SUM(actual_loss) / SUM(loan_amount) * 100, 2) as actual_loss_rate_pct,
  ROUND(SUM(expected_loss) / SUM(loan_amount) * 100, 2) as expected_loss_rate_pct,
  
  -- Model Accuracy
  ROUND((SUM(actual_loss) - SUM(expected_loss)) / NULLIF(SUM(expected_loss), 0) * 100, 2) as loss_variance_pct
FROM `dbt-analytics-430021.dbt_solubajo.dummy_credit_portfolio`
GROUP BY risk_score_band
ORDER BY 
  CASE risk_score_band
    WHEN '< 600' THEN 1
    WHEN '600-649' THEN 2
    WHEN '650-699' THEN 3
    WHEN '700-749' THEN 4
    WHEN '750+' THEN 5
  END;


-- =====================================================
-- KEY FINDINGS & RECOMMENDATIONS
-- =====================================================

/*
EXECUTIVE SUMMARY
=================

PORTFOLIO OVERVIEW:
- Total Portfolio: $65.5M across 300 loans
- Average Loan Size: $218,395
- Average Interest Rate: 20.5%
- Average Risk Score: 675
- Average Tenure: 23.8 months

RISK METRICS:
- Arrears Rate: 49% (147 loans with some delinquency)
- PAR 30+ Rate: 12.39% ($8.1M)
- PAR 90+ Rate: 2.44% ($1.6M)
- Default Rate: 0% (no loans in default status)
- Actual Loss Rate: 0.67% ($438K)

PROFITABILITY METRICS:
- Estimated Annual Interest Income: $13.5M (20.6% of portfolio)
- Total Actual Loss: $438,133
- Net Return on Portfolio: 19.95%
- Loss Coverage: 100% (actual = expected)

RISK TIER DISTRIBUTION:
- Low Risk: 37% of loans ($23.7M) - 20.02% net return
- Medium Risk: 28.7% of loans ($18.1M) - 19.67% net return
- High Risk: 34.3% of loans ($23.7M) - 20.09% net return

PRODUCT PERFORMANCE:
1. SME: Best performer - 10.72% PAR30, 20.34% net return
2. POS: 11.71% PAR30, 19.57% net return
3. Personal: 12.89% PAR30, 19.76% net return
4. Salary: Highest risk - 14.21% PAR30, 20.15% net return

STRENGTHS:
✓ Strong profitability with 19.95% net return
✓ No defaults recorded (0% default rate)
✓ Effective risk-based pricing across all tiers
✓ Low actual loss rate (0.67%)
✓ Expected losses match actual losses (good forecasting)

AREAS OF CONCERN:
⚠ High arrears rate at 49% - nearly half of loans have some delinquency
⚠ PAR 30+ at 12.39% exceeds industry benchmark (typically 5-8%)
⚠ Volatile PAR rates across origination cohorts (0% to 33.87%)
⚠ No active loans - entire portfolio appears closed/in collection
⚠ March 2023 cohort shows 33.87% PAR30 rate

RECOMMENDATIONS:
1. STRENGTHEN COLLECTIONS
   - Focus on early-stage delinquencies (PAR 1-30) to prevent escalation
   - Implement proactive outreach for loans at 1-7 days past due
   - Review collection strategies for effectiveness

2. REVIEW UNDERWRITING
   - Investigate March 2023 cohort (33.87% PAR30 rate)
   - Analyze what changed in underwriting during that period
   - Consider tightening credit criteria if needed

3. MONITOR CLOSELY
   - High arrears rate could lead to future defaults
   - Track early warning indicators
   - Implement more frequent portfolio reviews

4. INVESTIGATE PORTFOLIO STATUS
   - Clarify why no loans show as "Active"
   - May indicate data quality issue or portfolio lifecycle stage
   - Ensure status field is being updated correctly

5. OPTIMIZE PRODUCT MIX
   - SME loans show best performance - consider expanding
   - Salary loans show highest PAR30 - review underwriting
   - Maintain current risk-based pricing strategy (working well)

6. VALIDATE RISK MODEL
   - Risk scoring appears effective (all tiers profitable)
   - Continue monitoring actual vs expected losses
   - Consider recalibration if variances emerge

NEXT STEPS:
- Implement daily PAR monitoring dashboard
- Conduct deep dive on March 2023 cohort
- Review and enhance collection strategies
- Validate data quality for loan status field
- Set up automated alerts for high-risk loans
*/
