# Incident Runbook: Robot Shop on EKS

**Goal:** restore service first, understand it second. Record the time of every action.

## 0. Roles (solo drill: you hold all three)
- **Incident commander (IC):** decides, keeps the loop moving.
- **Operator:** runs commands.
- **Scribe:** keeps the timeline: `note "what happened"` (see section 6).

## 1. The loop

`Detect -> Triage (5 min) -> Mitigate -> Verify -> Root cause -> Postmortem`

Do **not** start deep debugging before a mitigation has been tried, unless no mitigation is safe.

## 2. Detect: where the first signal comes from

| Signal | Where |
|---|---|
| SLO burn alert | Prometheus Alerts / Alertmanager / Slack `#robot-shop-alerts` |
| Error or latency spike | Grafana "Robot Shop - Requests, Errors, Latency" |
| User report | "checkout fails", "page won't load" |

## 3. Triage (first 5 minutes)

1. Run `.\scripts\triage.ps1`.
2. Answer four questions:
   - **What** is broken? (which service is red on the RED dashboard; which pods are not Ready)
   - **Since when?** (the dashboard step change; event timestamps)
   - **What changed?** (Helm history, rollout history, recent `kubectl` edits)
   - **How bad?** (web 5m error ratio, which journeys fail: browse / cart / checkout)
3. Declare severity: **SEV1** = shop unusable (web errors > 50%); **SEV2** = a journey broken
   (fast-burn alert); **SEV3** = degraded (slow burn only).

## 4. Signal map: which tool answers which question

| Question | Tool | Example |
|---|---|---|
| Which service, how bad? | Grafana RED dashboard | Service drop-down, error % panel |
| What does the service say? | Grafana Logs dashboard / Explore (Loki) | `{service="cart", level="error"}` |
| Where is the time going? | Jaeger | Service payment, Find Traces, open a slow or red trace |
| Is it running at all? | kubectl | `get pods`, `describe pod`, `logs --previous` |
| What changed? | Helm / rollout history | `helm history robot-shop -n robot-shop`, `kubectl rollout history deploy/<svc> -n robot-shop` |

## 5. Common failure signatures and their mitigation

| Symptom | Likely cause | Mitigation (do first) | Then investigate |
|---|---|---|---|
| Pods `CrashLoopBackOff` right after a change | Bad config / env / image | `kubectl rollout undo deploy/<svc> -n robot-shop` or `helm rollback robot-shop <rev> -n robot-shop` | `logs --previous`, `rollout history --revision=N` |
| `ImagePullBackOff` / `ErrImagePull` | Wrong image tag | `helm rollback` / `rollout undo` | `describe pod` events |
| Deployment `0/0` | Scaled to zero | `kubectl scale deploy/<svc> --replicas=1 -n robot-shop` | Who scaled it (events, audit) |
| `OOMKilled`, restarts climbing | Memory limit too low / leak | Raise the limit via chart, `helm upgrade` | `describe pod` Last State, memory trend |
| Pods Running but 5xx from one service | Dependency down or misconfigured (DB, Redis, host env) | Restore the dependency / undo the env change | Service error logs (Loki), `describe deploy` env |
| `Pending` pods | No capacity / missing Secret or PVC | Free capacity / create the missing object | `describe pod` events |
| Everything slow | Node pressure, a noisy neighbour | Restart the hot pod, scale out | `kubectl top` (if metrics-server), Jaeger spans |

## 6. Timeline helper (paste once per PowerShell window)

    function note($m) { "$((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss'))Z  $m" | Tee-Object -FilePath docs\incident\timeline.log -Append }

## 7. Verify mitigation

- `slo:web_error_ratio:rate5m` back to its baseline (~5% in this demo, because of load-gen `ERROR=1`).
- RED dashboard error panel back to baseline, all pods Ready, fast-burn alert **resolved**.

## 8. Communication (post in `#robot-shop-alerts` every ~15 min)

> **[SEV2] Checkout/cart failing**. Impact: ~X% of web requests failing since HH:MM UTC.
> Mitigation in progress: rolling back <service>. Next update HH:MM.

## 9. Close out

Write the postmortem within 5 working days using `docs/incident/postmortem-template.md`.
Record error-budget impact (see the template for the PromQL).
