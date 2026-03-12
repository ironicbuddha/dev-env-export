# Dev Stack

This file describes the actual development stack this repo is meant to support.

It is not a list of every tool Carlo has ever touched. It is the current stack
that should shape bootstrap decisions, package choices, plugins, and day-to-day
defaults.

## Primary Languages

- TypeScript
- Python

## Frontend Stack

- Next.js
- Vite
- Tailwind CSS
- shadcn/ui

## Backend Stack

- Django
- Flask

## Cloud And Hosting

- AWS for cloud infrastructure and services
- Vercel for frontend hosting and deployment

## What This Means For The Bootstrap Repo

The bootstrap should stay friendly to this stack by default:

- solid Node.js and npm or nvm support for TypeScript, Next.js, and Vite work
- Homebrew-managed `nvm` with Node versions installed through `nvm`
- `pnpm` preferred for new TypeScript-heavy repos
- `bun` available for modern JS or TS workflows where it is the better fit
- strong Python support for Django and Flask work
- `uv` available as a fast Python package and environment tool
- good editor and agent support for both TS and Python
- AWS CLI and related auth flows treated as first-class
- Vercel support kept available where it still matches real usage
- browser automation and frontend tooling kept practical for UI-heavy work

## What This Does Not Mean

- every framework-specific package belongs in the machine bootstrap
- every plugin for every language should be enabled by default
- old tools should stick around just because they once matched the stack

This file is here to guide curation, not to justify hoarding.
