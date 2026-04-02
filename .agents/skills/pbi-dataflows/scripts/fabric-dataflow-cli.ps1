<#
.SYNOPSIS
    Fabric Dataflow CLI operations via REST API.
    Reference: https://learn.microsoft.com/en-us/rest/api/fabric/dataflow
    IMPORTANT: Verify endpoint URLs with microsoft-docs before using — Fabric API evolves frequently.

.PARAMETER workspaceId
    The Fabric workspace GUID.

.PARAMETER dataflowId
    The Dataflow item GUID.

.PARAMETER token
    Bearer token (obtain via: az account get-access-token --resource https://api.fabric.microsoft.com)
#>

param(
    [string]$workspaceId,
    [string]$dataflowId,
    [string]$token
)

$baseUrl = "https://api.fabric.microsoft.com/v1"
$headers = @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" }

# List all dataflows in workspace
function Get-FabricDataflows {
    param([string]$workspaceId)
    $uri = "$baseUrl/workspaces/$workspaceId/items?type=DataflowRefreshable"
    Invoke-RestMethod -Method GET -Uri $uri -Headers $headers
}

# Trigger a dataflow refresh
function Start-DataflowRefresh {
    param([string]$workspaceId, [string]$dataflowId)
    $uri = "$baseUrl/workspaces/$workspaceId/items/$dataflowId/jobs/instances?jobType=Refresh"
    $response = Invoke-RestMethod -Method POST -Uri $uri -Headers $headers -Body "{}"
    Write-Host "Refresh triggered. Job ID: $($response.id)"
    return $response
}

# Check refresh status
function Get-DataflowRefreshStatus {
    param([string]$workspaceId, [string]$dataflowId, [string]$jobId)
    $uri = "$baseUrl/workspaces/$workspaceId/items/$dataflowId/jobs/instances/$jobId"
    Invoke-RestMethod -Method GET -Uri $uri -Headers $headers
}

# Poll until refresh completes (with timeout)
function Wait-DataflowRefresh {
    param(
        [string]$workspaceId,
        [string]$dataflowId,
        [string]$jobId,
        [int]$timeoutMinutes = 60
    )
    $deadline = (Get-Date).AddMinutes($timeoutMinutes)
    do {
        Start-Sleep -Seconds 30
        $status = Get-DataflowRefreshStatus -workspaceId $workspaceId -dataflowId $dataflowId -jobId $jobId
        Write-Host "$(Get-Date -Format 'HH:mm:ss') Status: $($status.status)"
    } until ($status.status -in @("Succeeded","Failed","Cancelled") -or (Get-Date) -gt $deadline)
    return $status
}
