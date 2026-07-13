# Bootstrap Profiles

The bootstrap must support explicit Bootstrap Profiles because the Carlo
Baseline and Shared Baseline install materially different tools and personal
configuration. Profile selection is required for every run, using canonical
names `carlo-baseline` and `shared-baseline`, with `carlo` and `shared` accepted
as aliases. The master bootstrap owns profile validation and step selection,
normalizes the selected profile into `DEV_ENV_BOOTSTRAP_PROFILE`, and only
passes `--profile` to child scripts whose package or verification behavior
differs by profile.

The Shared Baseline is intentionally narrower than the Carlo Baseline. Its
zero-tool entry path starts from an extracted GitHub ZIP with Terminal opened
in that folder; it does not assume Git, Xcode Command Line Tools, Homebrew, an
editor, or preserved executable bits. It installs shared development tooling
and a Codex CLI-centered Shared AI Layer, but excludes Carlo-personal config, Claude,
Gemini, OpenSpec, GSD v2, AWS, Docker, 1Password installation/configuration,
Google Workspace CLI, Terraform, Codex skills, AI inventory, and personal
dotfiles. Shared package manifests should use common plus profile-specific
lists, and bootstrap completion should run profile-aware path and smoke
verification so missing Carlo-only tools are not treated as Shared Baseline
failures.
