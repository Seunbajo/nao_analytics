# Credit Portfolio Health Analysis

## Overview
Comprehensive risk and profitability analysis of the credit portfolio containing 300 loans worth $65.5M.

## Analysis Date
March 17, 2026

## Data Source
- **Database**: BigQuery (`dbt-analytics-430021.dbt_solubajo.dummy_credit_portfolio`)
- **Portfolio Size**: 300 loans, $65.5M total value
- **Average Loan**: $218,395
- **Average Interest Rate**: 20.5%

## Key Metrics

### Portfolio Overview
| Metric | Value |
|--------|-------|
| Total Loans | 300 |
| Total Portfolio Value | $65.5M |
| Average Loan Size | $218,395 |
| Average Interest Rate | 20.5% |
| Average Risk Score | 675 |
| Average Tenure | 23.8 months |

### Risk Metrics
| Metric | Value |
|--------|-------|
| Loans in Arrears | 147 (49%) |
| PAR 30+ Rate | 12.39% |
| PAR 90+ Rate | 2.44% |
| Default Rate | 0% |
| Actual Loss Rate | 0.67% |

### Profitability Metrics
| Metric | Value |
|--------|-------|
| Estimated Annual Interest Income | $13.5M |
| Net Return on Portfolio | 19.95% |
| Total Actual Loss | $438,133 |

## Risk Tier Distribution
- **Low Risk**: 111 loans (37%) - $23.7M - 20.02% net return
- **Medium Risk**: 86 loans (28.7%) - $18.1M - 19.67% net return
- **High Risk**: 103 loans (34.3%) - $23.7M - 20.09% net return

## Product Performance
| Product | Portfolio Value | PAR 30+ Rate | Net Return |
|---------|----------------|--------------|------------|
| Personal | $18.2M | 12.89% | 19.76% |
| SME | $16.1M | 10.72% | 20.34% |
| Salary | $15.7M | 14.21% | 20.15% |
| POS | $15.6M | 11.71% | 19.57% |

## Key Findings

### Strengths ✅
- Strong profitability with 19.95% net return on portfolio
- No defaults recorded (0% default rate)
- Effective risk-based pricing across all risk tiers
- Low actual loss rate at 0.67%

### Areas of Concern ⚠️
- High arrears rate at 49% (147 loans with some delinquency)
- PAR 30+ at 12.39% (above industry benchmark of 5-8%)
- Volatile PAR rates across origination cohorts (0% to 33.87%)
- No active loans reported - entire portfolio appears closed/in collection

## Recommendations

1. **Strengthen Collections**: Focus on early-stage delinquencies (PAR 1-30) to prevent escalation to higher PAR buckets

2. **Review Underwriting**: Investigate March 2023 cohort which shows 33.87% PAR30 rate - significantly above portfolio average

3. **Monitor Closely**: High arrears rate could lead to future defaults if not addressed

4. **Investigate Portfolio Status**: Clarify why no loans show as "Active" status - may indicate data quality issue or portfolio lifecycle stage

## SQL Queries
All analysis queries are available in `portfolio_health_analysis.sql`

## Files
- `portfolio_health_analysis.sql` - Complete SQL analysis queries
- `README.md` - This documentation file
