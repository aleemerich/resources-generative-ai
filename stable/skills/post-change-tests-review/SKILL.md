---
name: post-change-tests-review
description: Analyzes all existing tests (unit and integration) after code changes. Reviews test relevance, duplicates, compatibility with changes, and need for new tests. Use when code is modified, refactored, or when the user asks for a test review.
license: MIT
metadata:
  tags: "testing, test-review, tdd, quality-assurance"
  category: "engineering"
---

# Post-Change Tests Review

## When to Apply

Apply this skill whenever:
- Production code or test suites are modified.
- Refactoring affects interfaces, contracts, or business logic.
- New endpoints, events, or database schemas are added.
- The user requests a test audit or coverage check.

## Workflow

### 1. Identify Test Scope

Locate all relevant test suites in the workspace:
- **Unit tests**: `*.test.ts`, `*.spec.js`, `test_*.py`, `*_test.go`, `*Test.java`, etc.
- **Integration & E2E tests**: `tests/`, `integration/`, `e2e/`, `cypress/`, `playwright/`.
- **Test configurations**: `jest.config.*`, `vitest.config.*`, `pytest.ini`, `pom.xml`, `go.mod`.

### 2. Map Changes to Tests

For each modified file or function:
- Identify tests that exercise the changed logic directly or indirectly.
- Find tests asserting return values, side effects, or error cases.
- Flag tests depending on altered database schemas, network payloads, or mock fixtures.

### 3. Relevance Analysis

Categorize affected tests into four explicit states:

| Status | Meaning | Action Required |
| :--- | :--- | :--- |
| **Relevant** | Continues to validate intended behavior faithfully | Keep and verify execution passes |
| **Obsolete** | Exercises deprecated or completely deleted paths | Remove or archive test |
| **Misaligned** | Asserts obsolete expectations or outdated contracts | Update assertions and mock expectations |
| **Gap** | Newly introduced logic or edge cases lack coverage | Design and write new test scenarios |

### 4. Duplicate Detection

- [ ] Tests asserting the same scenario with only cosmetic differences.
- [ ] Overlapping unit and integration tests covering identical low-level edge cases.
- [ ] Redundant assertions across parameterized test suites.

### 5. Compatibility Check

- [ ] Assertions match updated schemas, return types, and status codes.
- [ ] Mock definitions reflect real interface signatures.
- [ ] Test fixtures and dates use valid, non-expired formats.
- [ ] External service stubs or event topics remain accurate.

### 6. New Test Recommendations

Flag when new coverage is mandatory:
- Uncovered branch conditions, error throws, or early returns.
- Boundary values, empty collections, or null/undefined handling.
- Concurrency, race condition, or idempotent replay scenarios.

## Output Format

Report findings systematically:

```markdown
## Post-Change Tests Review

### Scope
- Changed Files: [List of modified files]
- Tests Discovered: [Count of unit tests] unit, [Count of integration tests] integration

### Relevance Matrix
| Test File:Case | Status | Diagnostic Notes |
| :--- | :--- | :--- |
| `tests/auth.test.ts:testLogin` | Relevant | Nominal flow confirmed |
| `tests/token.test.ts:testOldExpiry` | Obsolete | Token refresh path was deprecated |
| `tests/billing.test.ts:testInvoice` | Misaligned | Expects 200 instead of new 201 Created |
| `src/services/payment.ts:45` | Gap | Missing test for gateway timeout error |

### Duplicates
- `testA` and `testB`: [Description of overlap] — [Consolidation suggestion]

### Compatibility Issues
- [Test Name]: [Signature/payload mismatch] — [Required update]

### New Tests Recommended
- [Scenario]: [Risk rationale and suggested test type]

### Action Items
1. [ ] Run affected test command: `npm test -- <path>`
2. [ ] Apply specific assertion update
3. [ ] Implement test case for missing gap
```

