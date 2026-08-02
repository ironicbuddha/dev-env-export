# Homebrew install manifest for the bootstrap flow.
#
# Keep required install targets in the active arrays below. A failed active
# formula or cask gates the selected bootstrap profile; only review/optional
# arrays are non-gating and are not installed automatically.
# Put stale, uncertain, or no-longer-used apps in REVIEW_CASK_APPS so they stay
# visible without getting installed by default.

COMMON_BREW_PACKAGES=(
    # Development
    nvm
    python@3.14
    uv

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
    # Runtime and deployment convenience
    bun

    # Cloud, infrastructure, and personal workflow CLIs
    awscli
    googleworkspace-cli
)

OPTIONAL_CLI_TOOLS=(
    # Optional development convenience
    taproom

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

    # Carlo's selected productivity and communication apps.
    chatgpt
    claude
    google-chrome
    google-drive
    libreoffice
    macdown
    obsidian
    slack
    utm
    vlc
    zoom
)

OPTIONAL_MANUAL_CASKS=(
    # Install manually only when a project needs them. They are not profile
    # requirements and do not carry application state through bootstrap.
    docker
    firefox
)

REVIEW_CASK_APPS=(
    # Removed from the active Carlo Baseline as of July 2026.
    betterdisplay
    sublime-text
)
