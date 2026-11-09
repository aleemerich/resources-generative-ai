# AGENTS.md Template and Reference

## Standard Template

````markdown
# AGENTS.md

**Project:** [2–4 sentences: core business mission, target audience, and primary technical constraints that cannot be inferred from code.]

## Toolchain

| Action | Command | Authority |
| :--- | :--- | :--- |
| Build | `[command]` | [Config / output location] |
| Test | `[command]` | [Runner config / test flags] |
| Lint | `[command]` | See [linter config file] |
| Type check | `[command]` | See [tsconfig / mypy.ini] |

## Judgment Boundaries

**NEVER**
- Commit secrets, credentials, API keys, or `.env` files.
- Introduce new external dependencies without explicit prior approval.
- Bypass failing tests or disable type checks to make builds pass.

**ASK**
- Before creating or modifying database schema migrations.
- Before altering existing public API contracts or event payloads.
- Before executing destructive filesystem operations or force pushes.

**ALWAYS**
- Outline the proposed approach before applying multi-file edits.
- Write or update corresponding unit tests alongside implementation.
- Handle error boundaries and external timeouts explicitly.

## Context Map

```yaml
[service/monorepo structure]
notable:
  [paths that would surprise someone who knows standard framework defaults]
```
````

## Section Guidance

- **Project Mission**: Focus on what the system does and non-negotiable invariants (e.g. offline-first, strict financial precision, event-driven ordering).
- **Toolchain**: Exact commands; point directly to the authoritative config file so the agent understands where linters read rules.
- **NEVER / ASK / ALWAYS**: Delineates autonomous execution from mandatory human escalation.
- **Context Map**: High-level map only. Never list every file or standard MVC directories.

## Synthetic Example: Web Application Backend

```markdown
# AGENTS.md

**Project:** Resilient order processing backend API. Handles checkout workflows, inventory reservation, and payment webhooks. Core constraints: strict idempotency on all webhooks, zero unhandled promise rejections, sub-100ms response targets.

## Toolchain

| Action | Command | Authority |
| :--- | :--- | :--- |
| Build | `pnpm build` | See tsconfig.build.json |
| Test | `pnpm test` | See vitest.config.ts |
| Lint | `pnpm lint` | See biome.json |
| Type check | `pnpm typecheck` | See tsconfig.json |

## Judgment Boundaries

**NEVER**
- Commit API secrets or stripe private keys to version control.
- Add external dependencies without user confirmation.
- Modify existing database columns directly without an explicit migration script.

**ASK**
- Before modifying schema migrations under `prisma/migrations/`.
- Before adding new payment gateway webhook handlers.

**ALWAYS**
- Verify tests pass before declaring a task complete (`pnpm test`).
- Ensure webhook handlers implement idempotent deduplication using the transaction ID.

## Context Map

```yaml
packages/
  api/: Express / tRPC entry points
  domain/: Pure domain entities and pricing calculation rules
  infra/: Database repositories and external payment adapters
notable:
  infra/db/client.ts: Custom Prisma connection pool with retry backoff
```
```

