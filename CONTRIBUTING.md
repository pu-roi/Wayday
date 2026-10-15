# Contributing to Wayday

## Current phase

Wayday is establishing its foundation. Application development has not started. Documentation, repository configuration, and project skills are the current deliverables. A roadmap stage describes future work; it does not authorize starting that stage.

Read the [product scope](docs/wayday/PRODUCT.md), [decisions](docs/wayday/DECISIONS.md), and [agent instructions](AGENTS.md) before proposing changes.

## Making a change

1. Keep the change within the requested scope. Preserve the original abstract, prototypes, and screenshots unless their modification is requested.
2. Update the decision log when an agreed technical or product choice changes. Mark assumptions as assumptions.
3. Keep documentation links relative to their source file so they work in other checkouts.
4. For a new dependency or service, record its purpose, license, costs, limits, expiry, and replacement path in the stack inventory. Recheck official sources when adopting a specific version.
5. Keep secrets, personal coordinates, signing credentials, generated builds, and large downloaded datasets out of commits.

Use descriptive branch names. Coding assistants default to the `codex/` prefix when creating a branch. Do not create a branch or commit merely to edit the foundation unless the task calls for it.

## Verification

For documentation changes, verify local links, source claims, terminology, and consistency. Check that ignore patterns do not hide source references or screenshots.

The current prototype check, run from the repository root, is:

```powershell
node docs/Asikaso-Prototype/docs/v2-planner-checks.cjs
```

It verifies simulated prototype behavior. It does not prove real routing quality, language accuracy, or reminder delivery.

New project skills should pass the installed skill-creator's `quick_validate.py` validator. That validator is an authoring tool, not a required application dependency. Review skill triggers and references as well as syntax.

When application code exists, add meaningful tests for timing, persistence, service failures, and platform behavior. Future tooling and checks are outlined in [Development](docs/wayday/DEVELOPMENT.md).

## Review notes

Describe the problem, resulting behavior or documentation change, and checks performed. Identify any unresolved decision. Do not describe recommended or simulated features as implemented.

## Licensing

Do not assign an open-source license to the team's original work without an explicit ownership decision. Retain required notices for third-party code, fonts, and data. OSM data licensing is separate from application code licensing.
