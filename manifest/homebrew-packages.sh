# Homebrew install manifest for the bootstrap flow.
#
# Keep active install targets in the arrays below.
# Put stale, uncertain, or no-longer-used apps in REVIEW_CASK_APPS so they stay
# visible without getting installed by default.

COMMON_BREW_PACKAGES=(
    # Development
    nvm
    python@3.13
    uv
    bun

    # Collaboration and build tools
    git
    gh
    jq
    make
    mole
    gcc

    # Document and media tooling for AI workflows
    pandoc
    poppler
    tesseract
    imagemagick
)

SHARED_BASELINE_BREW_PACKAGES=(
)

CARLO_BASELINE_BREW_PACKAGES=(
    # Development convenience
    taproom

    # Cloud, infrastructure, and personal workflow CLIs
    awscli
    docker
    gemini-cli
    googleworkspace-cli
)

OPTIONAL_CLI_TOOLS=(
    # Optional infrastructure tooling
    terraform
)

COMMON_CASK_APPS=(
    warp
    zed
    raycast
    hiddenbar
    hammerspoon
    github
)

SHARED_BASELINE_CASK_APPS=(
)

CARLO_BASELINE_CASK_APPS=(
    1password
    1password-cli
    betterdisplay
    obsidian
    docker
    firefox
)

REVIEW_CASK_APPS=(
    # No longer part of the default workflow as of March 2026.
    sublime-text
)
