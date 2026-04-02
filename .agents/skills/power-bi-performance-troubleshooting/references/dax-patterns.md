# DAX Performance Patterns

## Anti-Patterns and Fixes

### Repeated CALCULATE (Most Common)
❌ Slow:
```dax
Sales Growth =
([Total Sales] - CALCULATE([Total Sales], PREVIOUSMONTH('Date'[Date]))) /
CALCULATE([Total Sales], PREVIOUSMONTH('Date'[Date]))
```
✅ Fast:
```dax
Sales Growth =
VAR CurrentMonth = [Total Sales]
VAR PreviousMonth = CALCULATE([Total Sales], PREVIOUSMONTH('Date'[Date]))
RETURN DIVIDE(CurrentMonth - PreviousMonth, PreviousMonth)
```
**Why**: Eliminates duplicate storage engine scan.

### FILTER() as Filter Argument
❌ Slow: `CALCULATE([Sales], FILTER(ALL(Products), Products[Cat]="A"))`
✅ Fast: `CALCULATE([Sales], Products[Cat]="A")`
**Why**: Direct column filter uses VertiPaq columnar index; FILTER() forces row-by-row scan.

### Nested CALCULATE
❌ Slow: `CALCULATE(CALCULATE([Sales], Year=2024), Category="A")`
✅ Fast: `CALCULATE([Sales], Year=2024, Category="A")`
**Why**: Single context transition is more efficient.

### High-cardinality iterator
❌ Slow: `SUMX(Sales, Sales[Qty] * RELATED(Products[Price]))`
✅ Fast: Pre-compute `Sales[LineTotal]` as calculated column if static, or ensure relationship exists for RELATED optimization.

### Time Intelligence without Date Table
❌ Slow/Incorrect: `DATEADD(Sales[InvoiceDate], -1, YEAR)`
✅ Correct: Mark a dedicated Date table, use `DATEADD('Date'[Date], -1, YEAR)`
