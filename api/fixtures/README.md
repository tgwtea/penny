# fixtures

Test cases shared by the Go and Dart suites, so rules implemented on both sides cannot disagree silently.

| Folder | Rule | Read by |
| --- | --- | --- |
| `clashes/` | Clash detection (ADR 019) | `services/api/internal/scheduling/clash_test.go` (the pure rule and the database query), `apps/client/test/domain/clash_rule_test.dart` |

## clashes

Each file is one case:

```json
{
  "name": "what the case shows",
  "lessons": [
    {"id": "a", "start": "2026-11-19T16:00:00+08:00", "end": "2026-11-19T16:45:00+08:00",
     "status": "scheduled", "tutors": ["mei"], "students": ["sofia"]}
  ],
  "clashes": [
    {"lesson": "a", "with": "b", "tutor": "mei"}
  ]
}
```

`clashes` lists every clash from each lesson's point of view, so a clash between two lessons appears twice. Each entry names the tutor or the student booked twice. The rule: two lessons clash for a person when both are not cancelled, the person is on both, and their times overlap. Times are half-open, so a lesson ending at 16:45 does not clash with one starting at 16:45.
