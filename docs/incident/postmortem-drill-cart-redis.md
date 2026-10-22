# Postmortem: <short title>

| | |
|---|---|
| **Date** | YYYY-MM-DD |
| **Severity** | SEV1 / SEV2 / SEV3 |
| **Duration** | HH:MM - HH:MM UTC (detection to resolution) |
| **Author** | Theophilus Shaibu |
| **Status** | Draft / Final |

*Blameless: we describe what the system and process allowed to happen, not who to blame.*

## 1. Summary
Two or three sentences: what broke, who was affected, how it was fixed.

## 2. Impact
- **User impact:** which journeys failed (browse / cart / checkout), for how long.
- **SLO impact:** web error ratio peaked at **X%**. Failed requests during the incident: **N**,
  which is **Y% of the 30-day error budget** (budget = ~166,000 requests).
- PromQL used (Grafana Explore or Prometheus, set the time range to the incident):

      sum(increase(http_server_request_duration_seconds_count{k8s_namespace_name="robot-shop",k8s_deployment_name="web",http_response_status_code=~"5.."}[<duration>]))

## 3. Timeline (UTC)
| Time | Event |
|---|---|
| HH:MM | Change / fault introduced |
| HH:MM | First signal (alert / dashboard / user) |
| HH:MM | Triage started (`triage.ps1`) |
| HH:MM | Mitigation applied: <command> |
| HH:MM | Service verified healthy |
| HH:MM | Root cause identified |

## 4. Detection
How we found out, and how long after the fault. Did the SLO alert fire? Was it fast enough?

## 5. Mitigation
What restored service and why that action was chosen first.

## 6. Root cause (5 whys)
1. Why did users see errors? ...
2. Why did <service> fail? ...
3. Why ...?
4. Why ...?
5. Why ...?  -> **root cause**

**Evidence:** log lines (Loki query), `kubectl` output, dashboard or trace screenshots.

## 7. What went well / what went badly / where we got lucky
- Went well:
- Went badly:
- Lucky:

## 8. Action items
| # | Action | Type (prevent / detect / mitigate) | Owner | Due |
|---|---|---|---|---|
| 1 | | | | |

## 9. Lessons learned
One or two sentences the team should remember.
