# triage.ps1 - first-5-minutes snapshot for a Robot Shop incident.
# Usage:  .\scripts\triage.ps1            (namespace robot-shop)
param([string]$Namespace = "robot-shop")
$ErrorActionPreference = "Continue"
$prom = "prometheus-kps-kube-prometheus-stack-prometheus-0"

function Section($t) { Write-Host ""; Write-Host "=== $t ===" -ForegroundColor Cyan }

Section "Time (UTC)"
(Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss")

Section "Firing / pending alerts (Prometheus)"
try {
  $a = kubectl -n monitoring exec $prom -c prometheus -- wget -qO- "http://localhost:9090/api/v1/alerts" | ConvertFrom-Json
  $a.data.alerts | Where-Object { $_.labels.alertname -ne "Watchdog" -and $_.labels.alertname -ne "InfoInhibitor" } |
    ForEach-Object { "{0,-8} {1,-32} {2}" -f $_.state, $_.labels.alertname, $_.labels.severity }
} catch { "could not query Prometheus: $_" }

Section "Web SLO error ratio (5m / 1h)"
foreach ($q in "slo:web_error_ratio:rate5m","slo:web_error_ratio:rate1h") {
  try {
    $r = kubectl -n monitoring exec $prom -c prometheus -- wget -qO- "http://localhost:9090/api/v1/query?query=$q" | ConvertFrom-Json
    "{0,-30} {1:P2}" -f $q, [double]$r.data.result[0].value[1]
  } catch { "$q : n/a" }
}

Section "Pods NOT Running/Completed (all namespaces)"
kubectl get pods -A --no-headers | Where-Object { $_ -notmatch '\s(Running|Completed)\s' }

Section "Pods in $Namespace (check READY and RESTARTS)"
kubectl get pods -n $Namespace -o wide

Section "Deployments in $Namespace (READY should be n/n)"
kubectl get deploy -n $Namespace

Section "Recent Warning events in $Namespace"
kubectl get events -n $Namespace --field-selector type=Warning --sort-by=.lastTimestamp | Select-Object -Last 15

Section "Recent changes: Helm history"
helm history robot-shop -n $Namespace --max 5

Section "Recent changes: rollout history of focus services"
foreach ($d in "web","catalogue","cart","payment") {
  Write-Host "-- $d"; kubectl rollout history deployment/$d -n $Namespace | Select-Object -Last 4
}

Section "Last error logs per focus service (kubectl)"
foreach ($d in "web","catalogue","cart","payment") {
  Write-Host "-- $d"
  kubectl logs -n $Namespace deploy/$d --since=10m --tail=400 2>$null |
    Select-String -Pattern "error|exception|refused|timeout|ENOTFOUND|ECONN|5\d\d " -CaseSensitive:$false |
    Select-Object -Last 3 | ForEach-Object { $_.Line.Substring(0, [Math]::Min(220, $_.Line.Length)) }
}
