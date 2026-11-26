# Project rules

- This repository contains the native iOS Plan Manager app. It has no login or self-hosted backend.
- Keep local data and backup compatibility when changing existing models.
- After each logical code change, increment the marketing version by +0.01 with `scripts/bump_plan_manager_version.sh`. Use X.YY formatting.
- `Plan Manager/project.yml` is the source of project configuration; regenerate with XcodeGen when adding sources or changing settings.
- Never commit API keys, local databases, exported user backups, signing certificates, or Xcode user state.
- Run the Swift package tests and relevant iOS builds. Distinguish compiled tests from tests actually executed, and local checks from CI results.
