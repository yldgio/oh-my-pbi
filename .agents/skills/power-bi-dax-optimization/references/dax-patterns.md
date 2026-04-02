# DAX Optimization Patterns Reference

## Performance Patterns

### VAR for Repeated Calculations
❌ Bad:
```dax
Sales Growth =
DIVIDE(
    [Total Sales] - CALCULATE([Total Sales], PREVIOUSMONTH('Date'[Date])),
    CALCULATE([Total Sales], PREVIOUSMONTH('Date'[Date]))
)
```
✅ Good:
```dax
Sales Growth =
VAR CurrentPeriod = [Total Sales]
VAR PreviousPeriod = CALCULATE([Total Sales], PREVIOUSMONTH('Date'[Date]))
RETURN DIVIDE(CurrentPeriod - PreviousPeriod, PreviousPeriod)
```

### DIVIDE vs Division Operator
❌ Bad: `[Sales] / [Units]`
✅ Good: `DIVIDE([Sales], [Units], 0)`

### COUNTROWS vs COUNT
❌ Bad: `COUNT(Sales[OrderID])`
✅ Good: `COUNTROWS(Sales)`

### SELECTEDVALUE vs VALUES
❌ Bad: `VALUES('Date'[Year])`
✅ Good: `SELECTEDVALUE('Date'[Year], "All Years")`

### Filter with Table Expression
❌ Bad: `CALCULATE([Sales], FILTER(ALL(Products), Products[Category] = "A"))`
✅ Good: `CALCULATE([Sales], Products[Category] = "A")`

## Readability Patterns

### Descriptive Variable Names
❌ Bad: `VAR x = CALCULATE([Sales], SAMEPERIODLASTYEAR('Date'[Date]))`
✅ Good: `VAR SalesLastYear = CALCULATE([Sales], SAMEPERIODLASTYEAR('Date'[Date]))`

### Error Handling with IFERROR
❌ Bad: `[Ratio] + 0` (to avoid errors)
✅ Good: `IF(ISBLANK([Denominator]), BLANK(), DIVIDE([Numerator], [Denominator]))`
