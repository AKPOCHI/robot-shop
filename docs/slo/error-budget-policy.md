# Error Budget Policy: Robot Shop `web` Availability

| | |
|---|---|
| **Service** | `web` (Robot Shop storefront / API gateway, namespace `robot-shop`) |
| **Owner** | Robot Shop team (on call: AKPOCHI TIMOTHY PAUL) |
| **Status** | Active from 2026-10-22, reviewed quarterly |

## 1. SLI and SLO

- **SLI (availability):** proportion of HTTP requests served by `web` that do **not** return a 5xx status.
  Measured by Grafana Beyla (eBPF) as `http_server_request_duration_seconds_count`, recorded as
  `slo:web_error_ratio:rate{5m,30m,1h,6h}` (see `K8s/slo/web-availability-slo.yaml`).
- **SLO:** **99.5%** of requests succeed over a **rolling 30-day window**.
- **Error budget:** **0.5%** of requests. At ~12.8 req/s (~33M requests / 30 days) that is
  **~166,000 failed requests**, or about **3.6 hours of total outage** per 30 days.

## 2. Alerting (multi-window, multi-burn-rate)

| Alert | Condition | Meaning | Response |
|---|---|---|---|
| `WebAvailabilityFastBurn` (critical) | 5xx > 7.2% over 1h **and** 5m, for 2m | Budget gone in ~2 days | **Page**: on call responds within 15 min |
| `WebAvailabilitySlowBurn` (warning) | 5xx > 3% over 6h **and** 30m, for 15m | Budget gone in ~5 days | **Ticket**: investigate same working day |

Both alerts are sent to Slack `#robot-shop-alerts`, including when they resolve.

## 3. Policy by remaining budget (30-day window)

| Budget left | State | What we do |
|---|---|---|
| **> 50%** | Normal | Ship as usual. Normal change review. |
| **25-50%** | Caution | Releases need a rollback plan and must be watched on the RED dashboard for 30 min after deploy. |
| **< 25%** | Restricted | Only bug fixes, security fixes and reliability work ship. Feature releases need team-lead approval. |
| **Exhausted (0%)** | **Freeze** | **Feature freeze** until the 30-day availability is back above 99.5%. The team's priority becomes reliability work from the postmortem. |

## 4. Incidents and postmortems

- Any single incident that consumes **more than 20% of the monthly budget** requires a
  blameless **postmortem within 5 working days**, with at least one tracked action item.
- Recurring causes (the same failure twice in 30 days) are escalated to the next planning cycle.

## 5. Exclusions and known caveats

- **Planned maintenance** announced 24h in advance does not count against the budget.
- **Synthetic fault injection:** in this demo environment, load-gen runs with `ERROR=1`, which
  deliberately triggers payment failures surfacing as `web` 5xx (~5%). This keeps the slow-burn
  alert firing and means the budget is effectively exhausted. In production this traffic would be
  excluded, or `ERROR` set to `0`.
- Prometheus retention is **2 days** here, so true 30-day compliance cannot be computed in-cluster.
  Production would use longer retention (or Thanos / Mimir) for the full window.

## 6. Review

This policy, the 99.5% target and the burn-rate thresholds are reviewed **quarterly**, or after any
freeze. Changes are made by pull request to this file.
