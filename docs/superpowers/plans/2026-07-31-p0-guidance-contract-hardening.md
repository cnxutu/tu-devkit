# P0 Guidance Contract Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make P0's runtime routing and workspace-template contract easier to apply and automatically verify.

**Architecture:** Keep the runtime decision summary in `ai-guidance/AGENTS.md`; retain the detailed maintenance matrix in `docs/project-guide.md`. Extend the existing Python validator and its regression suite rather than adding another validation command.

**Tech Stack:** Markdown, Python standard library, PowerShell-compatible `unittest`.

---

### Task 1: Add template-contract regression tests

**Files:**

- Create: `ai-guidance/tests/test_guidance_validation.py`

- [ ] **Step 1: Write failing tests for a missing P4 mapping and a duplicate P1 mapping**

Create temporary repository copies, alter only `workspace.example.yaml`, run `validate_guidance.py`, and assert a non-zero result with the expected diagnostic.

- [ ] **Step 2: Run the new tests before implementation**

Run: `python -m unittest ai-guidance/tests/test_guidance_validation.py -v`

Expected: both new cases fail because the validator currently does not inspect repository codes in `workspace.example.yaml`.

### Task 2: Validate the submitted workspace template

**Files:**

- Modify: `ai-guidance/scripts/validate_guidance.py`

- [ ] **Step 1: Add a validator for the committed template's repository-code set and placeholder paths**

Require exactly one `P0` through `P4` repository mapping, reject duplicates, and reject concrete `path:` values in the committed template.

- [ ] **Step 2: Run the regression tests after implementation**

Run: `python -m unittest ai-guidance/tests/test_guidance_validation.py -v`

Expected: all tests pass.

### Task 3: Add a compact runtime decision aid

**Files:**

- Modify: `ai-guidance/AGENTS.md`

- [ ] **Step 1: Add a small routing table after the engineering-task baseline**

Cover pure questions, single-project engineering work, cross-service work, and P0-rule/tool maintenance. Link to existing conditional sections instead of duplicating detailed maintenance guidance.

- [ ] **Step 2: Clarify workspace-map failure handling in the scope section**

State the separate outcomes for first access, a missing project entry, and an inaccessible configured path.

### Task 4: Verify the P0 contract

**Files:**

- Modify: `ai-guidance/tests/test-guidance-validation.sh`

- [ ] **Step 1: Invoke the new Python regression suite from the existing shell entry point**

- [ ] **Step 2: Run PowerShell-compatible validation and review the diff**

Run: `python ai-guidance/scripts/validate_guidance.py --repo-root .`; `python -m unittest ai-guidance/tests/test_guidance_validation.py -v`; `git diff --check`; `git diff -- ai-guidance/AGENTS.md ai-guidance/scripts/validate_guidance.py ai-guidance/tests`

Expected: validation and tests pass; the diff contains only the P0 routing, validator, and regression-test changes.
