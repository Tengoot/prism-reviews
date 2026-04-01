# PRism Reviews

Expertise-based PR review routing with round-robin rotation. Filters GitHub review requests into four queues (direct, team, expertise, maintainer) and suggests the next reviewer per expertise tag.

## Requirements

- macOS with [Homebrew](https://brew.sh/)
- [GitHub CLI](https://cli.github.com/) (`gh`) installed and authenticated

## Installation

### Homebrew (recommended)

```sh
brew tap Tengoot/prism
brew install prism-reviews
```

To update:

```sh
brew upgrade prism-reviews
```

### From source

Requires Ruby >= 4.0:

```sh
gem build prism_reviews.gemspec
gem install prism_reviews-0.1.0.gem
```

## Configuration

Create `~/.config/prism/config.yml`:

```yaml
github_org: my-org

expertise_tags:
  backend: [api-service, admin-portal]
  frontend: [web-app, dashboard-ui]

reviewers:
  alice:
    github: alice-gh
    tags: [backend]
    maintainer: [api-service]
  bob:
    github: bob-gh
    tags: [backend, frontend]

include:
  - pattern: "feature/*"
    scope: expertise
  - pattern: "fix/*"
    scope: expertise
  - pattern: "dependabot/*"
    scope: maintainer

# Optional: shared state repo for rotation (GitHub org/repo)
state_repo: my-org/prism-state
```

### Fields

| Field | Required | Description |
|-------|----------|-------------|
| `github_org` | yes | GitHub organization name |
| `expertise_tags` | yes | Map of tag names to repository lists |
| `reviewers` | yes | Map of reviewer names to their GitHub handle, tags, and optional maintainer repos |
| `include` | no | Branch pattern inclusion rules (see below) |
| `state_repo` | no | GitHub repo for shared rotation state (enables `claim`/`skip`/`reassign`) |

### Include rules

When include rules are defined for a queue, only PRs matching at least one pattern are shown. Queues with no include rules pass all PRs through.

| Field | Required | Description |
|-------|----------|-------------|
| `pattern` | yes | Glob pattern matched against the PR branch name |
| `scope` | yes | Which queue to filter: `expertise`, `maintainer`, or `all` |
| `repos` | no | Limit the rule to specific repos (short names). Omit to apply to all repos |

## Usage

### List PRs

```sh
prism list                          # show filtered PR queues
prism list --no-color               # plain text output
prism list --config path/to/config  # custom config path
```

PRs are grouped into four queues by priority:

1. **Direct Requests** -- you are an explicitly requested reviewer
2. **Team** -- authored by a configured teammate
3. **Expertise** -- in repos matching your expertise tags, from outside the team
4. **Maintainer** -- in repos you maintain (includes dependency update PRs)

### Claim a PR

```sh
prism claim api-service 123
```

Advances the rotation pointer for all matching expertise tags and pushes state to the shared repo.

### Skip a reviewer

```sh
prism skip alice --until 2026-04-15   # skip until a date
prism skip alice                       # skip indefinitely
```

### Reassign a PR

```sh
prism reassign api-service 123 bob
```

Updates the rotation pointer to the named reviewer.

## Rotation

When `state_repo` is configured, PRism pulls `rotation-state.json` from a shared Git repo before each operation. The rotation is per-tag and round-robin. Multi-expertise PRs prefer the reviewer covering the most matching tags. Skipped reviewers are excluded until their skip date passes.

State is pushed after each `claim`, `skip`, or `reassign`. Push conflicts are retried once automatically.

## Development

```sh
bundle install
bundle exec rspec
bundle exec rubocop
```
