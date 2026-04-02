# Power Query M — Patterns Reference

Quick reference for common M patterns. For full M documentation use `microsoft-docs`.

## Query Folding Patterns

### ✅ Filter before transform (folds to source)
```m
let
    Source = Sql.Database("server", "db"),
    Table  = Source{[Schema="dbo", Item="Sales"]}[Data],
    Filtered  = Table.SelectRows(Table, each [Year] = 2024),   // folds → SQL WHERE
    WithQuarter = Table.AddColumn(Filtered, "Quarter",
                    each Date.QuarterOfYear([Date]))            // doesn't fold, but small
in WithQuarter
```

### ❌ Transform before filter (breaks folding — loads ALL rows)
```m
let
    Source   = Sql.Database("server", "db"),
    Table    = Source{[Schema="dbo", Item="Sales"]}[Data],
    WithQuarter = Table.AddColumn(Table, "Quarter",             // loads ALL rows
                    each Date.QuarterOfYear([Date])),
    Filtered = Table.SelectRows(WithQuarter, each [Year] = 2024) // too late to fold
in Filtered
```

## Steps That Break Folding (move these AFTER native filter steps)
- `Table.AddColumn` with M functions (non-native)
- `Table.Buffer`
- Custom functions
- `List.Generate`, `Table.Combine` across different sources
- In-memory operations on binary columns

## Incremental Refresh (Dataflows Gen1 & Gen2)
```m
// Parameters must be named EXACTLY: RangeStart (DateTime), RangeEnd (DateTime)
let
    Source   = Sql.Database("server", "db"),
    Table    = Source{[Schema="dbo", Item="Sales"]}[Data],
    Filtered = Table.SelectRows(Table,
                 each [Date] >= RangeStart and [Date] < RangeEnd)
in Filtered
```

## Common Transform Patterns

### Conditional column
```m
Table.AddColumn(Source, "Category",
    each if [Amount] > 1000 then "High"
         else if [Amount] > 100 then "Medium"
         else "Low",
    type text)
```

### Dynamic column rename
```m
let
    OldNames = {"Col1", "Col2", "Col3"},
    NewNames = {"Customer", "Revenue", "Region"},
    Renamed  = Table.RenameColumns(Source, List.Zip({OldNames, NewNames}))
in Renamed
```

### Unpivot multiple value columns
```m
Table.UnpivotOtherColumns(Source, {"ID", "Name"}, "Attribute", "Value")
```

### Left outer join
```m
Table.NestedJoin(Orders, {"CustomerID"}, Customers, {"ID"},
                 "CustomerData", JoinKind.LeftOuter)
```

## Credential Safety
```m
// ❌ NEVER — hardcoded token
Source = Web.Contents("https://api.example.com/data", [
    Headers = [Authorization = "Bearer eyJhbGci..."]
])

// ✅ CORRECT — use Power Query credential store
Source = Web.Contents("https://api.example.com/data")
// Set via: Transform data → Data source settings → Edit permissions
```
