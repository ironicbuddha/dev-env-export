# Dev Stack

This file describes the actual development stack this repo is meant to support.

It is not a list of every tool Carlo has ever touched. It is the current stack
that should shape bootstrap decisions, package choices, plugins, and day-to-day
defaults.

## Primary Languages

- TypeScript as the default language for application code across frontend and
  backend work
- Python mainly for scripting, automation, document workflows, and cases where
  the library support is materially better

## Frontend Stack

- Next.js 16.2.10
- Vite
- Tailwind CSS
- shadcn/ui

## Backend Stack

- Node.js 24.18.0 LTS and TypeScript for APIs, services, Lambdas, and microservice-style
  workloads
- Python only where scripting ergonomics or library support make it the better
  tool

## Cloud And Hosting

- AWS for cloud infrastructure and services
- Vercel for frontend hosting and deployment

## What This Means For The Bootstrap Repo

The bootstrap should stay friendly to this stack by default:

- strong Node.js 24.18.0 LTS support for TypeScript across frontend and backend work
- Homebrew-managed `nvm` with Node versions installed through `nvm`
- `pnpm` preferred for new TypeScript-first repos
- `bun` available for modern JS or TS workflows where it is the better fit
- Python kept practical for scripting, automation, document tooling, and
  library-driven edge cases
- `uv` available as a fast Python package and environment tool
- new repos should start with a basic lint and format baseline for Markdown,
  CSS, TSX, and Python
- editor and agent support should be strongest for TypeScript while still
  keeping Python usable
- AWS CLI and related auth flows treated as first-class
- Vercel support kept available where it still matches real usage
- browser automation and frontend tooling kept practical for UI-heavy work

## What This Does Not Mean

- every framework-specific package belongs in the machine bootstrap
- every plugin for every language should be enabled by default
- old tools should stick around just because they once matched the stack

This file is here to guide curation, not to justify hoarding.
