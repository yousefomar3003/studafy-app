# ADR-0030: Flat SQL dispatchers, and no more rename-and-wrap

- Status: Accepted for local/disposable use
- Date: 2026-09-28
- Decision owner: repository owner (GitHub `@yousefomar3003`)
- Relates to: ADR-0010 (strangler refactor and forward-only migrations)

## Context

Migrations are forward-only, so an existing SQL function cannot be edited in
place. From API-041 on, the way to add operations to a dispatcher was:

1. rename the current function to `<name>_pre_<change>`;
2. create a new `<name>` that handles the new operations and passes
   everything else to the renamed one.

After three weeks this left 63 renamed functions. `private.authz_authorize`
was twenty nested security-definer calls deep for an original academic
action, `api042_command` was fifteen, and `api042_query` thirteen. Which layer
owned an operation could only be found by reading migrations in order, and
the suffixes (`_pre_s9_roster`, `_pre_receipts`) named history, not
behaviour.

## Decision

### Flatten what can be flattened safely

A layer that begins "if this is not one of my operations, pass it down" is
*exclusive*: it answers its own operations completely. A run of exclusive
layers becomes:

- one **named handler per layer**, named for what it does
  (`authz_meetings`, `ops_query_messaging`, `ops_command_invitations`), whose
  body is the layer's own with only that guard removed; and
- one **dispatcher** that sends each operation to its handler. Where two
  layers claimed the same operation, the newer always answered first, so the
  dispatcher lists handlers newest first and the older claim is left out.

Flattened (migrations `202609280001` to `202609280003`):

| Function | Calls before | Calls after |
| -------- | ------------ | ----------- |
| `private.authz_authorize` | 20 | 1 (plus its handler) |
| `private.api042_query` | 13 | 1 |
| `private.api042_command` | 15 | 7 |

### Prove each one before it ships

A flattening is applied only after a **differential check** on a throwaway
copy of the database, loaded with every pgTAP fixture:

1. record the old function's answer for every fixture user × operation ×
   resource (× school, for queries);
2. apply the migration and record again;
3. require zero differences.

The first two runs covered 482,664 authorization decisions and 285,600 query
answers, and both matched exactly. The check also caught a bug in the
generator: one layer was losing a whole block, not just its guard. It was
fixed before anything shipped. Commands change data, so they cannot be
compared this way. They are covered by the transformation (bodies copied
verbatim, and each handler checked to differ from its layer only by the
removed guard), all 34 pgTAP suites and the API integration suites.

### Middleware layers stay, for now

Some layers are not exclusive: they rewrite a request, call the rest of the
chain, and post-process the result. Examples are the messaging safety
checks, meeting links, receipts, attachments, the class-code salt, and the
guardian read and download rules. These cannot be merged into a dispatcher
without re-deriving their logic, so they are unchanged.

Twenty-four remain:

- `api042_command`: 6
- `api041_query`: 6
- `api041_command`: 4
- `api044_*`: 3
- `file051_authorize_download`: 3
- `file050_authorize_target`: 2

The chains are at most seven deep. Rewriting them as one function each is
future work, and needs the same differential check plus command fixtures.

### No new chains

`scripts/check-migration-immutability.ts` rejects a new migration that
renames a private function to `*_pre_*` or `*_before_*`. To change a
dispatcher:

- **A new operation:** add a handler and a line in the dispatcher.
- **A changed operation:** `create or replace` its handler.

## Consequences

- An operation's owner is visible in one place: its dispatcher.
- Handlers are revoked from every client and runtime role. Only the
  dispatchers keep the grants the API has always had, so the permission
  surface pinned by `auth030_grants.sql` is unchanged.
- The names of the old generations are gone. The Family+ test that proved the
  ungated query was not callable now proves it does not exist.
