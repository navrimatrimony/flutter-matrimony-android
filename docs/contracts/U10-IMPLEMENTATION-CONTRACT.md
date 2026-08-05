# U10 Implementation Contract — Member app: confirm a meeting

**Unit:** U10  
**Authority:** `docs/MARKETPLACE-MASTER-EXECUTION-SSOT.md` §U10  
**Schema:** none · depends U9b  

## Runtime truths referenced by U10

| RT | Validation |
|---|---|
| **RT-9** | Visit ids come from U9a/U9b list only. |
| **RT-13** | ARB strings inserted as text. |

## Behaviour

1. On `SuchakMeetingsScreen` rows with `visit_status == completed`, offer Confirm.
2. Collect required `confirmation_note`; call `POST /suchak-meetings/{id}/confirm`.
3. Server refusal (422) surfaces as one sentence (response message).
4. On success, refresh the list.

## Tests

- Confirm action visible only for `completed`.
- Widget/flow test posts confirm with note.

## Out of scope

- Dispute (U11)
- Expanding U9a payload fields

## Rollback

`git revert <sha>`
