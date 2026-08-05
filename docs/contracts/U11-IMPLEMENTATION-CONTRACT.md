# U11 Implementation Contract — Member app: dispute a meeting

**Unit:** U11  
**Authority:** `docs/MARKETPLACE-MASTER-EXECUTION-SSOT.md` §U11  
**Schema:** none · depends U9b  

## Runtime truths referenced by U11

| RT | Validation |
|---|---|
| **RT-9** | Visit ids from U9a/U9b list. |
| **RT-13** | ARB strings inserted as text. |

## Behaviour

1. On completed rows, offer Dispute beside Confirm.
2. Require `dispute_reason`; call `POST /suchak-meetings/{id}/dispute`.
3. Refusal surfaces as one sentence; success refreshes the list.

## Tests

- Reason required · dispute offered only for `completed` · posts reason.

## Rollback

`git revert <sha>`
