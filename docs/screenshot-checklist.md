# Screenshot Checklist

Capture each screenshot yourself. Do not use placeholder or generated images.

| # | Screenshot | What it must show | Captured? |
|---|---|---|---|
| 1 | Project structure in VS Code | Explorer panel expanded showing `src/`, `tests/`, `vulnerable/`, `scripts/`, `docs/`, `.github/workflows/`, `Dockerfile` | [ ] |
| 2 | Application running successfully | Terminal running `npm start` or `docker run -p 3000:3000 trivy-demo:fixed`, and a browser or PowerShell showing `/health` returning `{"status":"ok"}` | [ ] |
| 3 | Docker image build | Terminal output of `docker build --build-arg DEMO_SCENARIO=fixed ...` ending in a successful build, plus `docker images trivy-demo` | [ ] |
| 4 | GitHub Actions workflow and security-gate configuration | The workflow file in VS Code, showing the `Security gate` step with `exit-code: '1'` and the `Upload` step with `if: always()` | [ ] |
| 5 | Vulnerable scenario: Trivy finding and failed gate | GitHub Actions run (`scenario = vulnerable`) with the red `Security gate` step and its table listing CVE-2021-23337 / CVE-2026-4800 | [ ] |
| 6 | Vulnerability report or CVE details | The downloaded `trivy-report-vulnerable` artifact opened, showing `PkgName`, `InstalledVersion`, `FixedVersion`, `VulnerabilityID`, `Severity` | [ ] |
| 7 | Fixed scenario: successful gate | GitHub Actions run (`scenario = fixed`) with the green `Security gate` step and the job marked successful | [ ] |
| 8 | Before-and-after evaluation | The filled-in table from `docs/before-after-comparison.md` with the real CI run URLs and results | [ ] |

## Local alternatives

If GitHub Actions has not run yet, screenshots 5 to 8 can be taken from the local demo instead, but label them as
local runs. Run `scripts/demo.ps1` with the Trivy CLI installed, or follow the instructions it prints.

Do not present local output as a GitHub Actions run.
