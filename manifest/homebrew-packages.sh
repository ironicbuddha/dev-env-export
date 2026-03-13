# Homebrew install manifest for the bootstrap flow.
#
# Keep active install targets in the arrays below.
# Put stale, uncertain, or no-longer-used apps in REVIEW_CASK_APPS so they stay
# visible without getting installed by default.

CLI_TOOLS=(
    # Development
    nvm
    python@3.13
    uv
    bun
    taproom

    # Cloud and infrastructure
    awscli
    gh

    # Build tools
    make
    gcc
)

OPTIONAL_CLI_TOOLS=(
    # Optional infrastructure tooling
    terraform
)

PRIMARY_CASK_APPS=(
    1password
    1password-cli
    warp
    zed
)

UTILITY_CASK_APPS=(
    raycast
    betterdisplay
    hiddenbar
    hammerspoon
    github
    obsidian
)

SUPPORTING_CASK_APPS=(
    docker
    firefox
)

REVIEW_CASK_APPS=(
    # No longer part of the default workflow as of March 2026.
    sublime-text
)
