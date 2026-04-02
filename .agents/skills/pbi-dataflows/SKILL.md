---
name: pbi-dataflows
description: >-
  Power Query M, Power BI Dataflows Gen1/Gen2, e Microsoft Fabric Data Pipelines.
  Usa quando l'utente lavora con trasformazioni dati, query M lente, dataflow in errore,
  gateway timeout, refresh che fallisce, vuole configurare output su Lakehouse,
  orchestrare pipeline Fabric, o chiede "query folding", "incremental refresh",
  "dataflow Gen2 vs Gen1", "pipeline Fabric", "M language", "Power Query ottimizzazione".
license: MIT
allowed-tools: runCommands, fetch
---

# PBI Dataflows — Power Query, Dataflows & Fabric Pipelines

> **Verification note:** Always load `microsoft-docs` and verify before advising on connector behavior, M function availability, or Fabric-specific dataflow features — these evolve rapidly.

Fornisci guidance operativa e codice M / PowerShell verificato su Power Query, Dataflows e Fabric Pipelines. Per ogni risposta su connector behavior, M functions o Fabric API: verifica prima con `microsoft-docs` — queste evolvono rapidamente.

---

## Part 1 — Power Query M Language

### Core Concepts

Power Query M is a **functional, case-sensitive** language. Every expression returns a value.

```m
// Basic structure: let ... in
let
    Source = Excel.Workbook(File.Contents("C:\data\sales.xlsx"), null, true),
    Sheet1 = Source{[Item="Sales",Kind="Sheet"]}[Data],
    PromotedHeaders = Table.PromoteHeaders(Sheet1, [PromoteAllScalars=true]),
    TypedTable = Table.TransformColumnTypes(PromotedHeaders, {
        {"Date", type date},
        {"Amount", type number},
        {"Region", type text}
    })
in
    TypedTable
```

### Type System

| M Type | Notes |
|--------|-------|
| `type text` | String |
| `type number` | Decimal number |
| `type date` | Date only |
| `type datetime` | Date + time |
| `type datetimezone` | With UTC offset |
| `type logical` | Boolean |
| `type binary` | File/blob content |
| `type table` | Tabular result |
| `type record` | Named fields |
| `type list` | Ordered sequence |
| `type null` | Missing value |

### Query Folding

**Query folding** = Power Query pushes transformation steps back to the data source as native queries (SQL, OData, etc.). This is critical for performance.

**Check if a step folds:**
- Right-click the step in Power Query Editor → "View Native Query"
- If greyed out → folding broke at that step

**Steps that break folding (avoid early in the query chain):**
- `Table.AddColumn` with M functions (not native)
- `Table.Buffer`
- Custom functions
- In-memory operations on binary columns
- `List.Generate`, `Table.Combine` across different sources

**Best practice:** Place all filter steps (remove rows, filter columns) as early as possible — before any steps that break folding.

```m
// GOOD: filter before transform
let
    Source = Sql.Database("server", "db"),
    Table = Source{[Schema="dbo",Item="Sales"]}[Data],
    FilteredRows = Table.SelectRows(Table, each [Year] = 2024),  // folds to SQL WHERE
    AddedColumn = Table.AddColumn(FilteredRows, "Quarter", each Date.QuarterOfYear([Date]))  // doesn't fold, but small dataset
in
    AddedColumn

// BAD: transform before filter
let
    Source = Sql.Database("server", "db"),
    Table = Source{[Schema="dbo",Item="Sales"]}[Data],
    AddedColumn = Table.AddColumn(Table, "Quarter", each Date.QuarterOfYear([Date])),  // loads ALL rows
    FilteredRows = Table.SelectRows(AddedColumn, each [Year] = 2024)  // too late to fold
in
    FilteredRows
```

### Parameters for Environment Promotion

Use parameters to avoid hardcoded server names, paths, or credentials:

```m
// Parameter: ServerName (type text, default: "dev-server")
// Parameter: DatabaseName (type text, default: "AdventureWorks")

let
    Source = Sql.Database(ServerName, DatabaseName),
    ...
in
    ...
```

In Fabric / Power BI Service: parameters can be set per workspace or deployment pipeline stage.

### Credential Handling Rules

**Never hardcode credentials in M code.** Violations to look for:

```m
// ❌ NEVER DO THIS
Source = Web.Contents("https://api.example.com/data", [
    Headers = [Authorization = "Bearer eyJhbGci..."]  // hardcoded token
])

// ✅ CORRECT: use Power Query credential store
Source = Web.Contents("https://api.example.com/data")
// Set credentials in: Transform data → Data source settings → Edit permissions
```

**Scan for hardcoded credentials:**
```powershell
Select-String -Recurse -Include "*.json","*.m","*.pq" `
    -Pattern "(password|secret|api.?key|bearer|Authorization)\s*=\s*[`"'][^`"']{8,}" `
    -CaseSensitive:$false
```

### Common M Patterns

```m
// Conditional column
Table.AddColumn(Source, "Category",
    each if [Amount] > 1000 then "High" else if [Amount] > 100 then "Medium" else "Low")

// Dynamic column rename from a list
let
    OldNames = {"Col1", "Col2", "Col3"},
    NewNames = {"Customer", "Revenue", "Region"},
    Renamed = Table.RenameColumns(Source, List.Zip({OldNames, NewNames}))
in Renamed

// Unpivot multiple value columns
Table.UnpivotOtherColumns(Source, {"ID", "Name"}, "Attribute", "Value")

// Merge/join two tables
Table.NestedJoin(Orders, {"CustomerID"}, Customers, {"ID"}, "CustomerData", JoinKind.LeftOuter)
```

---

## Part 2 — Power BI Dataflows Gen1

### What They Are

Dataflows Gen1 live in the **Power BI Service** (app.powerbi.com). They are self-service ETL tools using Power Query Online. Output stored in Azure Data Lake Storage Gen2 (internal, managed by Microsoft).

### Architecture

```
Source → Power Query Online (M) → Azure Data Lake Storage → Dataset / Direct Query
```

### Key Concepts

**Computed entities:** An entity (table) that queries another entity in the same dataflow. Requires Premium or PPU workspace.

```
Entity A (loads from SQL) → Entity B (computed: filters/transforms Entity A)
```

**Linked entities:** Reference an entity from *another* dataflow (read-only). Enables reuse across workspaces.

### Refresh Strategy

- Schedule: up to 48 refreshes/day (Premium)
- Incremental refresh: supported — configure via Power Query date/time parameters `RangeStart` and `RangeEnd`
- Enhanced compute engine: accelerates computed entities (Premium only)

```m
// Incremental refresh filter — MUST be named exactly
let
    Source = Sql.Database("server", "db"),
    Table = Source{[Schema="dbo",Item="Sales"]}[Data],
    // RangeStart and RangeEnd are automatically created parameters
    Filtered = Table.SelectRows(Table, each [Date] >= RangeStart and [Date] < RangeEnd)
in
    Filtered
```

### Gateway Requirements

| Source type | Gateway needed? |
|-------------|----------------|
| Cloud sources (Azure SQL, SharePoint Online, Dynamics) | No |
| On-premises (SQL Server, Oracle, file shares) | Yes — On-premises data gateway |
| Private network (behind VPN/firewall) | Yes — VNet data gateway (Premium) |

---

## Part 3 — Microsoft Fabric Dataflows Gen2

### Key Differences from Gen1

| Feature | Gen1 | Gen2 |
|---------|------|------|
| Platform | Power BI Service | Microsoft Fabric |
| Output | Internal ADLSg2 | Any Fabric item (Lakehouse, Warehouse, etc.) |
| Staging | Always enabled (internal) | Configurable |
| Mashup engine | Legacy | Mashup v2 (better folding) |
| M compatibility | Full | Full + new connector features |
| CI/CD | Limited | Fabric Git Integration |

### Output Destinations

Dataflow Gen2 can write to:
- **Lakehouse table** (default for analytics)
- **Warehouse table**
- **Azure SQL Database**
- **Azure Data Explorer**
- **Fabric KQL Database**

```
Power Query Online (M) → Output destination config → Lakehouse table
```

### Staging

Staging is an intermediate ADLSg2 landing zone within Fabric. It improves performance for large datasets and enables computed entities. Default: enabled.

Disable staging only when:
- Source data is small (<100K rows)
- Direct output latency matters more than throughput

### Fabric Git Integration for Dataflows Gen2

When a Fabric workspace is connected to Git, Dataflow Gen2 items appear as folders:

```
{workspace-root}/
└── {dataflow-name}.DataflowRefreshable/
    ├── item.config.json
    ├── item.metadata.json
    └── mashup.json          ← Power Query M code (JSON-encoded)
```

**Warning:** `mashup.json` encodes M as escaped JSON. Do not edit directly — use Fabric portal or Dataflow editor.

---

## Part 4 — Fabric Data Pipelines

### What They Are

Fabric Data Pipelines are **orchestration** tools (similar to Azure Data Factory). They schedule and chain activities: Copy Data, Dataflow, Notebook, Stored Procedure, etc.

Use pipelines for:
- Scheduled data ingestion (Copy activity)
- Orchestrating multiple dataflows
- Error handling and retry logic
- Cross-workspace dependencies

**Do NOT use pipelines for data transformation** — use Dataflow Gen2 or Notebooks for that.

### Key Activities

| Activity | Purpose |
|----------|---------|
| Copy Data | Move data from A to B (many connectors) |
| Dataflow | Run a Dataflow Gen2 |
| Notebook | Run a Fabric Notebook (PySpark/Spark SQL) |
| Stored Procedure | Call SQL stored procedure |
| Set Variable | Set pipeline variable |
| If Condition | Branch logic |
| ForEach | Loop over an array |
| Wait | Pause execution |

### Trigger Types

| Trigger | When to use |
|---------|------------|
| Schedule | Recurring refresh (daily, hourly) |
| Manual | On-demand runs |
| Storage event | When a file lands in OneLake/ADLS |
| Custom event | Via Azure Event Grid |

### Pipeline JSON (Git Integration)

```
{workspace-root}/
└── {pipeline-name}.DataPipeline/
    ├── item.config.json
    ├── item.metadata.json
    └── pipeline-content.json   ← pipeline definition
```

---

## Part 5 — Common Pitfalls

### Folding breaks silently

**Symptom:** Dataflow refresh is very slow despite filtering.
**Diagnosis:** Right-click step → "View Native Query" is greyed out.
**Fix:** Move custom M steps after all native filter steps.

### Credential scope mismatch

**Symptom:** Dataflow works for creator, fails for refresh service account.
**Fix:** Reconfigure data source credentials in workspace settings under the service account identity.

### Gateway timeout on large loads

**Symptom:** On-premises refresh fails after ~2 hours.
**Fix:**
1. Enable incremental refresh with `RangeStart`/`RangeEnd`
2. Or switch to Fabric Lakehouse as staging + pipeline for initial full load

### Gen2 output destination schema drift

**Symptom:** Dataflow fails with schema mismatch after source changes.
**Fix:** Re-map output destination column types in the Dataflow editor. Auto-detection can be re-run.

### M code lost after Git merge

**Symptom:** `mashup.json` shows merge conflicts.
**Fix:** Do NOT manually edit `mashup.json`. Use Fabric portal to export/re-import the dataflow. This is a known v1 limitation — see `git-workflow` skill for conflict detection.

---

## Fabric CLI — Dataflow Operations

```powershell
# List dataflows in a workspace
fab get items --workspace $workspaceId --type "DataflowRefreshable"

# Trigger dataflow refresh
$body = @{} | ConvertTo-Json
Invoke-RestMethod -Method POST `
    -Uri "https://api.fabric.microsoft.com/v1/workspaces/$workspaceId/items/$dataflowId/jobs/instances?jobType=Refresh" `
    -Headers @{ Authorization = "Bearer $token" } `
    -ContentType "application/json" `
    -Body $body

# Check refresh status
Invoke-RestMethod -Method GET `
    -Uri "https://api.fabric.microsoft.com/v1/workspaces/$workspaceId/items/$dataflowId/jobs/instances/$jobId" `
    -Headers @{ Authorization = "Bearer $token" }
```

> **Verify REST API endpoints with `microsoft-docs` before using** — Fabric API surface changes frequently.
