# Demonstration Video Script (5 to 7 minutes)

Target length: about 6 minutes. Times are approximate.

| Time | Section | Narration (summary) | On screen |
|---|---|---|---|
| 0:00-0:40 | Introduction and problem | Container images can carry vulnerable libraries. Manual scanning is not enough, so the pipeline must block unsafe images automatically. | Title slide or the README header |
| 0:40-1:20 | Aim and architecture | Node.js service, Docker build with a `DEMO_SCENARIO` argument, Trivy scanning, GitHub Actions gate. | README Mermaid diagram |
| 1:20-2:00 | Project structure | Walk through `src/`, `tests/`, `vulnerable/` (the controlled demo dependency set), `Dockerfile`, `.github/workflows/`, `scripts/demo.ps1`. | VS Code Explorer |
| 2:00-2:45 | Dockerized application | Run unit tests, start the container, call `/health` and `/greet?name=...`. Show the container runs as a non-root user. | Terminal: `npm test`, `docker run`, browser or `Invoke-WebRequest` |
| 2:45-3:20 | CI pipeline structure | Explain the steps: checkout, Node setup, `npm ci`, tests, scenario selection, Docker build, JSON report (exit 0), gate (exit 1), artifact upload with `if: always()`. | `trivy-security-gate.yml` in VS Code |
| 3:20-4:10 | Vulnerable scenario | Trigger the workflow manually with `scenario = vulnerable`. Show the red gate step. | GitHub Actions run page (only after the run has actually happened) |
| 4:10-4:40 | Trivy findings | Open the downloaded JSON report. Point to CVE-2021-23337 (HIGH, lodash 4.17.20, fixed in 4.17.21) and CVE-2026-4800 (HIGH, fixed in 4.18.0). | Artifact JSON in VS Code |
| 4:40-5:10 | Dependency remediation | Explain the fix: lodash upgraded to 4.18.1, exact pin, regenerated lockfile, npm tooling removed from the runtime image. Mention that 4.17.21 was tested and was not sufficient. | `package.json`, `package-lock.json`, `Dockerfile` |
| 5:10-5:45 | Fixed scenario | Trigger the workflow with `scenario = fixed`. Show the green gate step. | GitHub Actions run page |
| 5:45-6:15 | Before and after | Show the comparison table: versions, High and Critical counts, CVEs, gate results. | `docs/before-after-comparison.md` |
| 6:15-6:40 | Conclusion | The gate blocked the vulnerable image and passed the fixed one. Limitations: findings depend on the Trivy database, and only library findings are gated. | Summary slide |

## Before recording

1. Push the project to GitHub (see the README, section 17), and run both manual workflow scenarios once.
2. Note the run URLs. Do not show a run that has not actually happened.
3. Optional local fallback: run `scripts/demo.ps1` with the Trivy CLI installed, and say it is a local run.
