# Warp Configuration

Place tracked Warp configuration here.

Current intended tracked content:

- `warp/launch_configurations/*.yaml`

Tracked example:

- `warp/launch_configurations/dev-env-bootstrap.yaml`

Current intended target on macOS:

- `warp/launch_configurations/*.yaml` ->
  `~/.warp/launch_configurations/*.yaml`

Notes:

- Warp launch configuration files live in `~/.warp/launch_configurations/` on
  macOS.
- The `cwd:` values in Warp launch configs must be absolute paths or `""`.
- Warp supports Settings Sync for much of its in-app configuration, so this repo
  should only track local files that are intentionally portable.
- If Warp CLI setup becomes part of the bootstrap flow, document it here rather
  than hiding it in unrelated scripts.
- The tracked launch config in this repo opens:
  - a split `dev-env-export` tab rooted in this repository
  - a second `dev` tab rooted in `/Users/carlo/dev`

Keep this directory focused on portable launch configs and other explicit export
artifacts, not ephemeral app state.
