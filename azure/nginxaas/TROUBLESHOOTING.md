# NGINXaaS Troubleshooting & Monitoring Reference

A collection of queries and commands for monitoring and troubleshooting the NGINXaaS deployment, upstream health checks, connectivity, and backend VM status.

---

## Table of Contents

- [Environment Setup](#environment-setup)
  - [Export Variables](#export-variables)
  - [Retrieve Resource IDs](#retrieve-resource-ids)
- [Azure Monitor Metrics API](#azure-monitor-metrics-api)
  - [Discover Available Metrics and Dimensions](#discover-available-metrics-and-dimensions)
  - [Query Upstream Peer State](#query-upstream-peer-state)
  - [Split by Peer Address](#split-by-peer-address)
  - [Get Latest Metric Only](#get-latest-metric-only)
  - [One-Liner: Check All Peers UP/DOWN](#one-liner-check-all-peers-updown)
  - [Continuous Monitoring (Watch Mode)](#continuous-monitoring-watch-mode)
- [Log Analytics KQL Queries](#log-analytics-kql-queries)
  - [Raw Error Logs](#raw-error-logs)
  - [Health Check Status for All Peers](#health-check-status-for-all-peers)
  - [Health Check Status for a Specific Peer](#health-check-status-for-a-specific-peer)
  - [Latest Log Entry for a Specific Peer](#latest-log-entry-for-a-specific-peer)
- [Log Analytics CLI Queries](#log-analytics-cli-queries)
  - [All Peers Status](#all-peers-status)
  - [Specific Peer Status](#specific-peer-status)
  - [Latest Log for a Peer](#latest-log-for-a-peer)
  - [Continuous Log Monitoring (Watch Mode)](#continuous-log-monitoring-watch-mode)
- [NGINXaaS Connectivity Test](#nginxaas-connectivity-test)
  - [Run a Connectivity Test via curl](#run-a-connectivity-test-via-curl)
  - [One-Liner: Full Connectivity Test](#one-liner-full-connectivity-test)
- [Traffic Generation](#traffic-generation)
- [Important Notes](#important-notes)
  - [Metric Ingestion Delays](#metric-ingestion-delays)
  - [Azure Monitor Metric Details](#azure-monitor-metric-details)
  - [Log Analytics Details](#log-analytics-details)
  - [Active Health Check Configuration](#active-health-check-configuration)

---

## Environment Setup

### Export Variables

Set these environment variables once per session. All commands in this document reference them so you don't need to replace placeholders every time.

```bash
#  Azure Identity 
export SUBSCRIPTION_ID=$(az account show --query id -o tsv)
export TOKEN=$(az account get-access-token --query accessToken -o tsv)

#  Resource Names (update these to match your deployment) 
export PROJECT_PREFIX="your-project-prefix"
export RESOURCE_GROUP="${PROJECT_PREFIX}-rg"
export NGINXAAS_NAME="${PROJECT_PREFIX}-nginxaas"
export WORKSPACE_NAME="${PROJECT_PREFIX}-azure-log"

#  Derived IDs (auto-retrieved) 
export WORKSPACE_ID=$(az monitor log-analytics workspace show \
  --resource-group $RESOURCE_GROUP \
  --workspace-name $WORKSPACE_NAME \
  --query customerId -o tsv)

export NGINXAAS_ENDPOINT=$(az resource show \
  --resource-group $RESOURCE_GROUP \
  --resource-type "Nginx.NginxPlus/nginxDeployments" \
  --name $NGINXAAS_NAME \
  --query properties.ipAddress -o tsv 2>/dev/null)


#  NGINXaaS Connectivity Test API Key 
# Found in the Azure Portal under NGINXaaS > Connectivity Test page

# Generate a new random key or specify a value for it.
export NGINXAAS_API_KEY_NAME="${PROJECT_PREFIX}-nginxaas-api-key"
export NGINXAAS_API_KEY_CLEAR=$(uuidgen)
export NGINXAAS_API_KEY=$(echo -n $NGINXAAS_API_KEY_CLEAR | base64)

# require latest nginx extension
# az extension add --name nginx --upgrade --allow-preview
# Create an api-key
az nginx deployment api-key create \
--resource-group $RESOURCE_GROUP \
--deployment-name $NGINXAAS_NAME \
--name $NGINXAAS_API_KEY_NAME \
--secret-text $NGINXAAS_API_KEY_CLEAR

# Update an api-key
az nginx deployment api-key update \
--resource-group $RESOURCE_GROUP \
--deployment-name $NGINXAAS_NAME \
--name $NGINXAAS_API_KEY_NAME \
--secret-text $NGINXAAS_API_KEY_CLEAR

export NGINXAAS_FQDN=$(az resource show \
  --resource-group $RESOURCE_GROUP \
  --resource-type "Nginx.NginxPlus/nginxDeployments" \
  --name $NGINXAAS_NAME \
  --query properties.dataplaneApiEndpoint -o tsv 2>/dev/null)
export NGINXAAS_FQDN=$(echo "$NGINXAAS_FQDN" | sed 's|https://||')

#  Peer IPs (update with your actual VM public IPs) 
# export PEER1_IP="20.116.56.217"
# export PEER2_IP="20.116.105.47"

PEER1_IP=$(az network public-ip list \
  --resource-group $RESOURCE_GROUP \
  --query "[?contains(name, 'vm1')].[ipAddress]" -o tsv)

PEER2_IP=$(az network public-ip list \
  --resource-group $RESOURCE_GROUP \
  --query "[?contains(name, 'vm2')].[ipAddress]" -o tsv)

```

### Retrieve Resource IDs

Useful `az` commands to look up resource information:

```bash
# Get your Azure user Object ID (needed for Grafana admin assignment)
az ad signed-in-user show --query id -o tsv

# Get subscription ID
az account show --query id -o tsv

# Get the NGINXaaS deployment details
az resource show \
  --resource-group $RESOURCE_GROUP \
  --resource-type "Nginx.NginxPlus/nginxDeployments" \
  --name $NGINXAAS_NAME \
  -o json | jq .

# Get Log Analytics workspace ID
az monitor log-analytics workspace show \
  --resource-group $RESOURCE_GROUP \
  --workspace-name $WORKSPACE_NAME \
  --query customerId -o tsv

# Get the NGINXaaS public IP address
az network public-ip show \
  --resource-group $RESOURCE_GROUP \
  --name ${PROJECT_PREFIX}-public-ip \
  --query ipAddress -o tsv

# List VM public IPs
az network public-ip list \
  --resource-group $RESOURCE_GROUP \
  --query "[?contains(name, 'vm')].{name:name, ip:ipAddress}" -o table

# Get VM status (running/stopped)
az vm list \
  --resource-group $RESOURCE_GROUP \
  --show-details \
  --query "[].{name:name, state:powerState, publicIp:publicIps}" -o table
```

---

## Azure Monitor Metrics API

### Discover Available Metrics and Dimensions

List all available metrics and their dimensions for your NGINXaaS deployment:

```bash
curl -s --header "Authorization: Bearer $TOKEN" \
  "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Nginx.NginxPlus/nginxDeployments/$NGINXAAS_NAME/providers/microsoft.insights/metricDefinitions?api-version=2024-02-01" \
  | jq '.value[] | {name: .name.value, dimensions: .dimensions }'
```

Look up dimensions for a specific metric:

```bash
curl -s --header "Authorization: Bearer $TOKEN" \
  "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Nginx.NginxPlus/nginxDeployments/$NGINXAAS_NAME/providers/microsoft.insights/metricDefinitions?api-version=2024-02-01" \
  | jq '.value[] | select(.name.value == "plus.http.upstream.peers.state.up") | .dimensions'
```

### Query Upstream Peer State

Basic query for the upstream peer state metric:

```bash
curl -s --header "Authorization: Bearer $TOKEN" \
  "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Nginx.NginxPlus/nginxDeployments/$NGINXAAS_NAME/providers/microsoft.insights/metrics?metricnames=plus.http.upstream.peers.state.up&api-version=2024-02-01" | jq .
```

### Split by Peer Address and Upstream

Add the `$filter` parameter with the `peer.address` and `upstream` dimensions to get per-peer, per-upstream results:

> **Important:** You must include both `peer.address eq '*'` and `upstream eq '*'` in the filter to get both dimensions in the response. Using `peer.address eq '*'` alone will return `upstream` as `null`.

```bash
curl -s --header "Authorization: Bearer $TOKEN" \
  "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Nginx.NginxPlus/nginxDeployments/$NGINXAAS_NAME/providers/microsoft.insights/metrics?metricnames=plus.http.upstream.peers.state.up&api-version=2024-02-01&\$filter=peer.address%20eq%20'*'%20and%20upstream%20eq%20'*'" | jq .
```

### Get Latest Metric Only

Use a tight `timespan` and `interval` to limit results to the most recent data point:

```bash
curl -s --header "Authorization: Bearer $TOKEN" \
  "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Nginx.NginxPlus/nginxDeployments/$NGINXAAS_NAME/providers/microsoft.insights/metrics?metricnames=plus.http.upstream.peers.state.up&api-version=2024-02-01&\$filter=peer.address%20eq%20'*'%20and%20upstream%20eq%20'*'&timespan=PT5M&interval=PT1M&aggregation=Minimum" | jq .
```

> **Note:** Use `aggregation=Minimum`  this is the supported aggregation type for this metric. The Azure Portal metric explorer also confirms `Min` as the valid aggregation.

### One-Liner: Check All Peers UP/DOWN

A single command that returns a clean UP/DOWN status per peer:

```bash
curl -s --header "Authorization: Bearer $TOKEN" \
  "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Nginx.NginxPlus/nginxDeployments/$NGINXAAS_NAME/providers/microsoft.insights/metrics?metricnames=plus.http.upstream.peers.state.up&api-version=2024-02-01&\$filter=peer.address%20eq%20'*'%20and%20upstream%20eq%20'*'&timespan=PT5M&interval=PT1M&aggregation=Minimum" \
  | jq -r '.value[].timeseries[] | {upstream: ([.metadatavalues[] | select(.name.value == "upstream")] | .[0].value), peer: ([.metadatavalues[] | select(.name.value == "peer.address")] | .[0].value), state: (if (.data | last | .minimum // 0) == 1 then "UP" else "DOWN" end)} | .upstream + "/" + .peer + " = " + .state'
```

Example output:

```
app/4.205.36.224:80 = DOWN
app/4.205.87.15:80 = UP
api/4.205.36.224:80 = UP
```

### Continuous Monitoring (Watch Mode)

Poll every 3 seconds:

```bash
watch -n 3 'curl -s --header "Authorization: Bearer $TOKEN" \
  "https://management.azure.com/subscriptions/'$SUBSCRIPTION_ID'/resourceGroups/'$RESOURCE_GROUP'/providers/Nginx.NginxPlus/nginxDeployments/'$NGINXAAS_NAME'/providers/microsoft.insights/metrics?metricnames=plus.http.upstream.peers.state.up&api-version=2024-02-01&\$filter=peer.address%20eq%20'\''*'\''%20and%20upstream%20eq%20'\''*'\''&timespan=PT5M&interval=PT1M&aggregation=Minimum" \
  | jq -r ".value[].timeseries[] | {upstream: ([.metadatavalues[] | select(.name.value == \"upstream\")] | .[0].value), peer: ([.metadatavalues[] | select(.name.value == \"peer.address\")] | .[0].value), state: (if (.data | last | .minimum // 0) == 1 then \"UP\" else \"DOWN\" end)} | .upstream + \"/\" + .peer + \" = \" + .state"'
```

> **Note:** Azure Monitor metrics have a **1-2 minute ingestion delay**. Even though you poll every 3 seconds, the data only updates every ~1 minute. For faster detection, use the [Log Analytics queries](#log-analytics-kql-queries) instead.

---

## Log Analytics KQL Queries

Log Analytics queries are **faster** (~30-60 second delay) than Azure Monitor metrics (~1-2 minutes) for detecting upstream state changes. These can be run in the Azure Portal under **Log Analytics > Logs**, or via the [CLI one-liners](#log-analytics-cli-queries) below.

### Raw Error Logs

View the latest NGINX error logs sorted by time:

```kql
NGXOperationLogs
| where FilePath == "/var/log/nginx/error.log"
| sort by TimeGenerated desc
| take 100
```

### Health Check Status for All Peers

Derive UP/DOWN state from health check failure logs. If a peer has had a health check failure within the last 5 minutes, it is marked as **DOWN**:

> **Why 5 minutes?** Log Analytics has a 30-60 second ingestion delay. A 2-minute window can cause false UPs when the latest failure log hasn't been ingested yet. 5 minutes provides a safe buffer while still detecting recovery within a reasonable timeframe.

```kql
NGXOperationLogs
| where FilePath == "/var/log/nginx/error.log"
| where Message has "health check"
| where TimeGenerated > ago(24h)
| parse Message with * "peer " PeerAddress " in upstream \"" UpstreamName "\"" *
| summarize LastFailure = max(TimeGenerated) by PeerAddress, UpstreamName
| extend State = iff(LastFailure > ago(5m), "DOWN", "UP")
| extend MinutesSinceFailure = round(datetime_diff('second', now(), LastFailure) / 60.0, 1)
| project PeerAddress, UpstreamName, State, LastFailure, MinutesSinceFailure
| order by PeerAddress asc
```

Example output:

| PeerAddress | UpstreamName | State | LastFailure | MinutesSinceFailure |
|-------------|-------------|-------|-------------|---------------------|
| 4.205.36.224:80 | app | DOWN | 2026-03-03T17:22:58Z | 1.2 |
| 4.205.87.15:80  | app | UP   | 2026-03-03T14:00:40Z | 197.5 |

### Health Check Status for a Specific Peer

Filter by a specific peer IP address (replace the IP with your actual peer IP or use `$PEER1_IP`):

```kql
NGXOperationLogs
| where FilePath == "/var/log/nginx/error.log"
| where Message has "health check"
| where TimeGenerated > ago(24h)
| where Message has "4.205.36.224"
| parse Message with * "peer " PeerAddress " in upstream \"" UpstreamName "\"" *
| summarize LastFailure = max(TimeGenerated) by PeerAddress, UpstreamName
| extend State = iff(LastFailure > ago(5m), "DOWN", "UP")
| extend MinutesSinceFailure = round(datetime_diff('second', now(), LastFailure) / 60.0, 1)
| project PeerAddress, UpstreamName, State, LastFailure, MinutesSinceFailure
```

### Latest Log Entry for a Specific Peer

Return the single most recent health check log entry for a peer, with a `HowLongAgo` column showing elapsed time:

```kql
NGXOperationLogs
| where FilePath == "/var/log/nginx/error.log"
| where Message has "health check"
| where Message has "4.205.36.224"
| top 1 by TimeGenerated desc
| extend HowLongAgo = now() - TimeGenerated
| project TimeGenerated, HowLongAgo, Message
```

Example output:

| TimeGenerated | HowLongAgo | Message |
|---------------|------------|---------|
| 2026-03-03T17:22:58Z | 00:03:22 | ...connect() failed (111: Connection refused) while connecting to upstream (status 0), health check "" of peer 4.205.36.224:80 in upstream "app"... |

> **Note:** `TimeGenerated` is always in UTC. The `HowLongAgo` column provides a relative time so you don't need to do timezone math.

---

## Log Analytics CLI Queries

These are `az` CLI equivalents of the KQL queries above, using the exported `$WORKSPACE_ID` variable.

### All Peers Status

```bash
az monitor log-analytics query \
  --workspace $WORKSPACE_ID \
  --analytics-query "NGXOperationLogs | where FilePath == '/var/log/nginx/error.log' | where Message has 'health check' | where TimeGenerated > ago(24h) | parse Message with * 'peer ' PeerAddress ' in upstream \"' UpstreamName '\"' * | summarize LastFailure=max(TimeGenerated) by PeerAddress, UpstreamName | extend State=iff(LastFailure > ago(5m), 'DOWN', 'UP') | extend MinutesSinceFailure=round(datetime_diff('second', now(), LastFailure) / 60.0, 1) | project PeerAddress, UpstreamName, State, LastFailure, MinutesSinceFailure" \
  -o table
```

### Specific Peer Status

```bash
az monitor log-analytics query \
  --workspace $WORKSPACE_ID \
  --analytics-query "NGXOperationLogs | where FilePath == '/var/log/nginx/error.log' | where Message has 'health check' | where TimeGenerated > ago(24h) | where Message has '$PEER1_IP' | summarize LastFailure=max(TimeGenerated) | extend State=iff(LastFailure > ago(5m), 'DOWN', 'UP') | extend MinutesSinceFailure=round(datetime_diff('second', now(), LastFailure) / 60.0, 1) | project State, LastFailure, MinutesSinceFailure" \
  -o table
```

### Latest Log for a Peer

```bash
az monitor log-analytics query \
  --workspace $WORKSPACE_ID \
  --analytics-query "NGXOperationLogs | where FilePath == '/var/log/nginx/error.log' | where Message has 'health check' | where Message has '$PEER1_IP' | top 1 by TimeGenerated desc | extend HowLongAgo=now()-TimeGenerated | project TimeGenerated, HowLongAgo, Message" \
  -o table
```

### Continuous Log Monitoring (Watch Mode)

Poll every 5 seconds for all peers status:

```bash
watch -n 5 "az monitor log-analytics query \
  --workspace $WORKSPACE_ID \
  --analytics-query \"NGXOperationLogs | where FilePath == '/var/log/nginx/error.log' | where Message has 'health check' | where TimeGenerated > ago(24h) | parse Message with * 'peer ' PeerAddress ' in upstream \\\\\\\"' UpstreamName '\\\\\\\"' * | summarize LastFailure=max(TimeGenerated) by PeerAddress, UpstreamName | extend State=iff(LastFailure > ago(5m), 'DOWN', 'UP') | extend MinutesSinceFailure=round(datetime_diff('second', now(), LastFailure) / 60.0, 1) | project PeerAddress, State, LastFailure, MinutesSinceFailure\" \
  -o table"
```

---

## NGINXaaS Connectivity Test

The NGINXaaS deployment exposes a connectivity test tool that uses `netcat` to initiate a TCP connection from the NGINXaaS nodes to a given IP and port. This is useful for verifying that NGINXaaS can reach your upstream servers.

### Run a Connectivity Test via curl

The connectivity test is a two-step process:

**Step 1:** Submit the test  returns an `operationId`:

```bash
PEER_IP=$PEER1_IP
OP_ID=$(curl -s \
  -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: ApiKey $NGINXAAS_API_KEY" \
  -d "{\"ipAddress\":\"$PEER_IP\",\"port\":80,\"protocol\":\"tcp\",\"command\":\"nc\"}" \
  "https://$NGINXAAS_FQDN/connectivity" \
  | jq -r '.operationId')

echo "Operation ID: $OP_ID"
```

**Step 2:** Poll for results:

```bash
curl -s \
  -H "Authorization: ApiKey $NGINXAAS_API_KEY" \
  "https://$NGINXAAS_FQDN/connectivity-operation/$OP_ID" | jq .
```

> **Note:** The POST uses `Authorization: ApiKey <base64>` header (not basic auth). The API key is base64-encoded and can be found in the NGINXaaS connectivity test page in the Azure Portal.

### One-Liner: Full Connectivity Test

Submit and poll in a single command. Tests connectivity to a specific peer from all NGINXaaS nodes:

```bash
PEER_IP=$PEER1_IP
OP_ID=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: ApiKey $NGINXAAS_API_KEY" \
  -d "{\"ipAddress\":\"$PEER_IP\",\"port\":80,\"protocol\":\"tcp\",\"command\":\"nc\"}" \
  "https://$NGINXAAS_FQDN/connectivity" \
  | jq -r '.operationId') && \
for i in $(seq 1 10); do \
  sleep 1; \
  RESULT=$(curl -s \
    -H "Authorization: ApiKey $NGINXAAS_API_KEY" \
    "https://$NGINXAAS_FQDN/connectivity-operation/$OP_ID"); \
  echo "$RESULT" | jq -e '.results' >/dev/null 2>&1 && \
  echo "$RESULT" | jq -r '.results[] | "Source: " + .source + " | Result: " + .result' && \
  break; \
done
```

To test the second peer, replace `$PEER1_IP` with `$PEER2_IP`.

---

## Traffic Generation

Use the included `generate_traffic.sh` script to generate a mix of legitimate and malicious traffic against the NGINXaaS deployment. This is useful for populating Grafana dashboards, Azure Portal metrics, and Log Analytics with realistic data.

```bash
# Get the NGINXaaS public IP
echo $NGINXAAS_ENDPOINT

# Run indefinitely (Ctrl+C to stop)
./generate_traffic.sh $NGINXAAS_ENDPOINT

# Run for 2 minutes
./generate_traffic.sh $NGINXAAS_ENDPOINT 120
```

The script sends approximately:
- **80% legitimate requests**  `/`, `/coffee.html`, `/tea.html`
- **20% malicious requests**  XSS, SQL injection, path traversal, command injection (triggers WAF blocks)

Traffic is sent with randomized User-Agent headers and 0.2-1.0 second delays between requests. A summary is printed on exit (Ctrl+C).

---

## VM Backend Management

Useful commands for testing upstream health detection by stopping/starting NGINX on the backend VMs.

### Check VM Status

```bash
az vm list \
  --resource-group $RESOURCE_GROUP \
  --show-details \
  --query "[].{name:name, state:powerState, publicIp:publicIps}" -o table
```

### Stop NGINX on a Backend VM

```bash
# Stop nginx on VM1 (triggers health check failures)
az vm run-command invoke \
  --resource-group $RESOURCE_GROUP \
  --name ${PROJECT_PREFIX}-vm1 \
  --command-id RunShellScript \
  --scripts "sudo systemctl stop nginx"

# Verify it's stopped
az vm run-command invoke \
  --resource-group $RESOURCE_GROUP \
  --name ${PROJECT_PREFIX}-vm1 \
  --command-id RunShellScript \
  --scripts "sudo systemctl status nginx" 2>&1 | head -20
```

### Start NGINX on a Backend VM

```bash
# Start nginx on VM1 (peer recovers after 3 successful health checks ~15s)
az vm run-command invoke \
  --resource-group $RESOURCE_GROUP \
  --name ${PROJECT_PREFIX}-vm1 \
  --command-id RunShellScript \
  --scripts "sudo systemctl start nginx && sudo systemctl status nginx"
```

### Stop/Start Both VMs

```bash
# Stop both (run in parallel)
az vm run-command invoke --resource-group $RESOURCE_GROUP --name ${PROJECT_PREFIX}-vm1 --command-id RunShellScript --scripts "sudo systemctl stop nginx" &
az vm run-command invoke --resource-group $RESOURCE_GROUP --name ${PROJECT_PREFIX}-vm2 --command-id RunShellScript --scripts "sudo systemctl stop nginx" &
wait

# Start both
az vm run-command invoke --resource-group $RESOURCE_GROUP --name ${PROJECT_PREFIX}-vm1 --command-id RunShellScript --scripts "sudo systemctl start nginx" &
az vm run-command invoke --resource-group $RESOURCE_GROUP --name ${PROJECT_PREFIX}-vm2 --command-id RunShellScript --scripts "sudo systemctl start nginx" &
wait
```

---

## Important Notes

### Metric Ingestion Delays

| Data Source | Typical Delay | Best For |
|-------------|---------------|----------|
| Azure Monitor Metrics API | 1-2 minutes | Dashboard charts, historical trends |
| Log Analytics (KQL) | 30-60 seconds | Near real-time troubleshooting |
| NGINXaaS Connectivity Test | ~2-3 seconds | On-demand network connectivity checks |
| NJS Probe (`/probe`) | Real-time | Instant backend reachability check |

### Azure Monitor Metric Details

- **Metric namespace (v3 SKU):** `NGINX.NGINXPLUS/nginxDeployments`
- **Metric name:** `plus.http.upstream.peers.state.up` (not `plus.http.upstream.peers.state`)
- **Supported aggregation:** `Minimum` (the Azure Portal metric explorer confirms this)
- **Dimensions for per-peer, per-upstream split:** `peer.address` and `upstream`
- Use `$filter=peer.address eq '*' and upstream eq '*'` to split by all peers and upstreams
- Use `$filter=peer.address eq '*' and upstream eq '<name>'` to filter by a specific upstream
- Using `peer.address eq '*'` alone returns `upstream` as `null`  always include both dimensions
- The `orderby` parameter is **not supported** by the Metrics API (it's a Log Analytics / OData feature)

### Log Analytics Details

- **Table name:** `NGXOperationLogs`
- **Error log path filter:** `FilePath == "/var/log/nginx/error.log"`
- Health check **failures** are logged to the error log. Successful health checks are **not** logged by default.
- A peer that has **never failed** a health check will not appear in log-based queries.
- `TimeGenerated` is always in **UTC**. Use `extend MinutesSinceFailure = round(datetime_diff('second', now(), LastFailure) / 60.0, 1)` for relative time.
- **Use `ago(5m)` threshold** (not `ago(2m)`) for UP/DOWN detection to account for ingestion delay. A 2-minute window causes false UPs.
- **Use `where TimeGenerated > ago(24h)`** to filter out stale entries from previous deployments with different peer IPs.

### Active Health Check Configuration

The NGINXaaS deployment is configured with active health checks in the NGINX configuration (`nginx.tf`):

```nginx
health_check interval=5s passes=3 fails=3;
```

- Probes each upstream every **5 seconds** by requesting `/`
- Marks a peer as **unhealthy** after **3 consecutive failures** (~15 seconds)
- Marks a peer as **healthy** after **3 consecutive successes** (~15 seconds)
- Detection by NGINXaaS: ~15 seconds
- Visible in Azure Monitor metrics: ~1-2 minutes after detection
- Visible in Log Analytics: ~30-60 seconds after detection

