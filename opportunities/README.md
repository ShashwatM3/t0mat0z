# Opportunity Work Lanes

Use one folder per opportunity so research, fixtures, tests, and prototype notes stay scoped until a slice becomes shared app code.

| Folder | Role | Current use |
|---|---|---|
| `field-scout-memory/` | Main product | Demo spine and integrated product story. |
| `novice-scout-guidance/` | Core module | Worker coaching flow and step prompts. |
| `leaf-stress-triage/` | Core module | Narrow issue classifier/verifier loop. |
| `zone-memory-map/` | Core module | Judge-visible zone log/map proof. |
| `supervisor-escalation-packet/` | Core module | Trust, uncertainty, and expert review packet. |
| `packing-harvest-qa-evidence-logger/` | Fallback | Indoor QA/batch evidence workflow. |
| `harvest-readiness-pre-check/` | Backup | Crop readiness triage, not final grading. |
| `input-safety-checklist/` | Backup | Farm-approved checklist and evidence log. |
| `post-harvest-risk-cold-chain-prep/` | Roadmap | Downstream payoff and routing context. |
| `farm-optimization-feedback-loop/` | Roadmap | Long-term memory/learning dashboard. |

Before building in a folder, add or update:

- `README.md` with the user, setting, object, action, and output.
- Test or verifier fixture before implementation.
- Manual acceptance checklist if device/DAT hardware is required.
- Clear stop condition for unsupported claims or missing evidence.
