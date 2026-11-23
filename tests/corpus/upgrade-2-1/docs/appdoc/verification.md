# Verification

Evidence Register (2.1): each claim, the lines that support it and the command that re-checks it.

| Claim | Source | Re-run |
|---|---|---|
| A password is set in code (V1) | `app/main.py:6` | `grep -n password app/main.py` |
| Operators launch the entry point (7.1) | `app/main.py:2` | `sed -n 2p app/main.py` |

Summary: 2 of 2 claims verified.
