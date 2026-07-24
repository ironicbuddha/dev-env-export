<!-- 
Sync Impact Report:
Version: 1.0.0 → 1.1.0
Modified principles: None
Added sections:
  - VI. Infrastructure Reliability & Containerization (new principle covering Docker, deployment, and operational concerns)
Modified principles: None
Templates requiring updates:
  ✅ plan-template.md - Constitution Check section expanded with infrastructure principle
  ✅ spec-template.md - Review checklist includes infrastructure considerations
  ✅ tasks-template.md - Task categorization includes infrastructure validation tasks
Follow-up TODOs: 
  - Fix Docker volume naming inconsistency between build-with-db.cmd and docker-compose.dev.yml
  - Standardize volume references to use docker_postgres-dev-data consistently
  - Update build scripts to verify volume mounting before seeding operations
-->

# Q-Agent Constitution

## Core Principles

### I. Code Quality & Maintainability (NON-NEGOTIABLE)

All code MUST meet the following standards:

- **Type Safety**: TypeScript strict mode enabled; no `any` types without explicit justification
- **Code Structure**: Follow single responsibility principle; functions <50 lines, files <500 lines
- **Documentation**: All public APIs documented with JSDoc; complex logic requires inline comments
- **Linting**: Zero ESLint errors; Prettier formatting enforced via pre-commit hooks
- **Dependency Management**: Regular updates; security vulnerabilities patched within 48 hours
- **Code Reviews**: Minimum 1 approval required; no self-merges allowed

**Rationale**: Q-Agent is a critical QA platform where code quality directly impacts user trust and testing accuracy. Maintainable code reduces bugs and enables rapid feature development.

### II. Testing Standards (NON-NEGOTIABLE)

Test-Driven Development (TDD) is mandatory for all new features:

- **Test-First Workflow**: Tests written → User approved → Tests fail → Implementation → Tests pass
- **Coverage Requirements**: Minimum 80% code coverage; critical paths require 100%
- **Test Types Required**:
  - **Unit Tests**: All services, utilities, and business logic (Jest)
  - **Integration Tests**: API routes, database operations, external service integrations
  - **Contract Tests**: API endpoints must have contract tests validating request/response schemas
  - **E2E Tests**: Critical user flows (authentication, test generation, execution) using Playwright
- **Test Quality**: Tests must be deterministic, fast (<5s per suite), and isolated
- **Continuous Testing**: All tests run on PR creation; must pass before merge

**Rationale**: As an autonomous testing platform, Q-Agent must exemplify testing best practices. Comprehensive testing prevents regressions and ensures reliability for users depending on test generation accuracy.

### III. User Experience Consistency

All user-facing features MUST maintain consistency across the platform:

- **Design System**: Use Shadcn/ui components exclusively; custom components require design review
- **Accessibility**: WCAG 2.1 AA compliance mandatory; keyboard navigation for all interactive elements
- **Responsive Design**: Mobile-first approach; test on 3 breakpoints (mobile/tablet/desktop)
- **Performance Perception**: Loading states for operations >200ms; skeleton screens for async content
- **Error Handling**: User-friendly error messages; technical details logged but not displayed
- **Internationalization**: Support 25+ languages via react-i18next; all strings externalized
- **Dark Theme**: Maintain contrast ratios; test all UI in both light/dark modes

**Rationale**: Consistent UX reduces cognitive load and training time. Q-Agent users need confidence that the platform works predictably across all features and devices.

### IV. Performance & Scalability

System performance MUST meet the following benchmarks:

- **Response Time**: API endpoints <200ms p95; database queries optimized with indexes
- **Page Load**: Initial page load <2s; Time to Interactive (TTI) <3s on 3G
- **Bundle Size**: JavaScript bundles <250KB gzipped; lazy-load non-critical components
- **Database**: Query optimization required; N+1 queries prohibited; use Prisma efficiently
- **Caching**: Implement Redis caching for frequently accessed data (>100 req/min)
- **Monitoring**: Application Performance Monitoring (APM) enabled; alerts for p95 >500ms
- **Scalability**: Design for 10,000+ concurrent users; horizontal scaling via containerization

**Rationale**: Performance directly impacts user productivity. Slow test generation or execution monitoring degrades the value proposition of an autonomous testing platform.

### V. Security & Data Protection (NON-NEGOTIABLE)

Security is paramount for handling sensitive test data and user information:

- **Authentication**: NextAuth.js with bcrypt; session tokens expire after 7 days
- **Authorization**: Role-Based Access Control (RBAC); principle of least privilege enforced
- **Input Validation**: All user inputs validated server-side using Zod schemas
- **SQL Injection**: Prisma ORM exclusively; raw SQL queries require security review
- **XSS Protection**: Content Security Policy (CSP) headers; sanitize all user-generated content
- **File Uploads**: Validate file types and sizes; scan for malware; store in isolated directories
- **Secrets Management**: Never commit secrets; use environment variables; rotate API keys quarterly
- **Audit Logging**: Log all authentication events, authorization failures, and data access
- **Dependencies**: Automated security scanning via Dependabot; critical CVEs patched immediately

**Rationale**: Q-Agent handles sensitive business requirements, test cases, and potentially proprietary information. Security breaches would destroy user trust and violate compliance requirements.

### VI. Infrastructure Reliability & Containerization

Deployment infrastructure MUST be reliable, reproducible, and maintainable:

- **Container Standards**: Use multi-stage Docker builds; Alpine-based images for minimal size
- **Volume Management**: Named volumes with consistent naming across all compose files and scripts
- **Volume Naming**: Use full project-prefixed names (e.g., `docker_postgres-dev-data`) consistently
- **Database Initialization**: Verify volume mounting before schema application or seeding operations
- **Health Checks**: All services MUST have health check endpoints; containers depend on healthy state
- **Entrypoint Scripts**: Handle startup dependencies (database ready, migrations complete)
- **Environment Consistency**: Dev, staging, production use identical Docker configurations
- **Image Tagging**: Semantic versioning for images; never use `latest` in production
- **Volume Backups**: Automated backup procedures for persistent volumes; test restore regularly
- **Startup Sequence**: Database → Schema/Seed → Application (strict dependency ordering)
- **Error Recovery**: Containers MUST restart on failure with exponential backoff
- **Resource Limits**: Define memory/CPU limits and reservations for all services

**Rationale**: Q-Agent deploys across three environments (domain, Rancher Desktop, offline). Infrastructure inconsistencies lead to data loss, failed deployments, and production incidents. Volume naming mismatches between build scripts and compose files have caused database seeding to fail silently, with data written to wrong volumes.

## Development Standards

### Quality Gates

All pull requests MUST pass the following gates before merge:

1. **Automated Checks**:
   - CI/CD pipeline green (all tests passing)
   - ESLint and TypeScript compilation with zero errors
   - Code coverage threshold met (≥80%)
   - No high/critical security vulnerabilities
   - Bundle size analysis (no regressions >10%)

2. **Code Review**:
   - At least 1 approval from a core maintainer
   - Constitution compliance verified
   - Architecture decisions documented
   - Breaking changes explicitly noted and versioned

3. **Testing Verification**:
   - TDD workflow documented (test-first proof)
   - Integration tests cover new API routes
   - E2E tests updated for user-facing changes
   - Manual testing checklist completed for UI changes

### Breaking Changes Policy

- **Major Version**: Breaking API changes, database schema migrations requiring data migration
- **Minor Version**: New features, backward-compatible API additions, optional new fields
- **Patch Version**: Bug fixes, performance improvements, documentation updates
- All breaking changes MUST include:
  - Migration guide with before/after examples
  - Deprecation warnings added 1 minor version before removal
  - Changelog entry with upgrade instructions

## Compliance & Monitoring

### Constitution Enforcement

- **Pre-commit Hooks**: Automated linting, formatting, and test execution
- **PR Templates**: Checklist includes constitution compliance verification
- **Quarterly Reviews**: Architecture and code quality audits against constitution principles
- **Violation Process**: Documented exceptions require justification and remediation plan

### Performance Monitoring

- **Continuous Monitoring**: Real-time APM tracking response times, error rates, and throughput
- **Alerting**: Automated alerts for performance degradation (>20% regression)
- **Quarterly Benchmarks**: Performance regression testing against baseline metrics
- **User Analytics**: Track feature usage and user satisfaction scores

### Security Reviews

- **Monthly**: Dependency vulnerability scans and updates
- **Quarterly**: Penetration testing and security audit
- **Annually**: Comprehensive security assessment by external auditor
- **Incident Response**: Documented process for security breach handling

## Governance

### Amendment Process

1. **Proposal**: Submit amendment via pull request to this constitution file
2. **Discussion**: Minimum 7-day comment period for core team feedback
3. **Approval**: Requires 2/3 majority vote from core maintainers
4. **Documentation**: Update version, changelog, and dependent templates
5. **Migration**: If amendment changes development workflow, provide migration guide
6. **Communication**: Announce changes via team channels and update agent guidance files

### Version Semantics

- **MAJOR**: Backward-incompatible principle removals or redefinitions (e.g., removing TDD requirement)
- **MINOR**: New principles added or materially expanded guidance (e.g., adding accessibility standards)
- **PATCH**: Clarifications, wording improvements, typo fixes, non-semantic changes

### Compliance Verification

- All pull requests MUST verify compliance with current constitution version
- Complexity introduced that violates principles requires documented justification
- Agents (Claude, Copilot, Gemini, etc.) MUST consult this constitution before code generation
- Use agent-specific guidance files (`.github/copilot-instructions.md`, `CLAUDE.md`, etc.) for runtime development guidance

**Version**: 1.1.0 | **Ratified**: 2025-10-06 | **Last Amended**: 2025-10-16
