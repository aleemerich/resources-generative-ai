---
name: post-change-cleanup-review
description: Reviews code after creation or modification for duplicates, unnecessary code, ambiguity, irrelevant code, and test-related code that needs cleanup. Use when code is created, modified, refactored, or when the user asks for a cleanup review.
license: MIT
metadata:
  tags: "code-review, cleanup, refactoring, quality"
  category: "engineering"
---

# Post-Change Cleanup Review

## When to Apply

Apply this skill whenever:
- Code is created, modified, or refactored.
- A pull request or local diff is prepared for review.
- The user explicitly requests a cleanup or hygiene review.

## Review Checklist

After any code change, scan the affected scope across five categories:

### 1. Duplicate Code
- [ ] Logic repeated across multiple functions or modules that should be consolidated.
- [ ] Similar functions or classes with only trivial parameter variations.
- [ ] Copy-pasted blocks that should be extracted into shared helpers.

### 2. Unnecessary Code
- [ ] Dead code (unreachable branches, functions never invoked).
- [ ] Redundant assertions, null checks, or variable reassignments.
- [ ] Unused imports, declared variables, or dangling parameters.

### 3. Ambiguity from Changes
- [ ] Identifier names that no longer accurately describe their updated behavior.
- [ ] Comments, docstrings, or schemas that contradict newly modified logic.
- [ ] Overlapping boundaries or split responsibilities between modules.

### 4. Irrelevant Code (Candidates for Deletion)
- [ ] Code rendered obsolete by the recent change (even if recently authored).
- [ ] Deprecated fallback branches or backward-compatibility shims no longer required.
- [ ] Superseded configuration flags or dead feature toggles.

### 5. Test-Related Code
- [ ] Test fixtures, mocks, or synthetic payloads referencing removed behavior.
- [ ] Tests that became redundant or assert stale expectations.
- [ ] Debug code, test assertions, or mock helpers that leaked into production files.

## Output Format

Report findings systematically using:

```markdown
## Post-Change Cleanup Review

### Duplicates
- [File:Line]: [Description of duplicate logic] — [Consolidation suggestion]

### Unnecessary
- [File:Line]: [Unused import/dead variable/redundant check] — [Removal suggestion]

### Ambiguity
- [File:Line]: [Mismatched name or outdated comment] — [Clarification suggestion]

### Irrelevant (Candidates for Removal)
- [File:Line]: [Obsolete code path] — [Removal suggestion]

### Tests
- [File:Line]: [Stale mock or test leak] — [Fix suggestion]

### Summary
[Brief overview of hygiene status and recommended priority fixes]
```

## Review Scope

- Directly modified files and their immediate callers/callees.
- Corresponding unit, integration, and end-to-end tests.
- Build configurations, schema definitions, and package manifests.

