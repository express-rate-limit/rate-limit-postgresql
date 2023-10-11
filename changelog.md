# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.2](https://github.com/express-rate-limit/express-rate-limit-postgresql/releases/tag/v1.3.2)

### Added

- Enabled provenance statement generation, see
  https://github.com/express-rate-limit/express-rate-limit#406.

## [1.3.1](https://github.com/express-rate-limit/express-rate-limit-postgresql/releases/tag/v1.3.1)

### Changed

- Upgraded dependencies to fix security issues for
  [chai-js](https://github.com/express-rate-limit/rate-limit-postgresql/security/dependabot/1)
  and
  [sqlfluff](https://github.com/express-rate-limit/rate-limit-postgresql/security/dependabot/2)

## [1.3.0](https://github.com/express-rate-limit/express-rate-limit-postgresql/releases/tag/v1.3.0)

### Changed

- Stores call stored procedures instead of raw SQL

## [1.2.0](https://github.com/express-rate-limit/express-rate-limit-postgresql/releases/tag/v1.2.0)

### Changed

- `express-rate-limit` moved from `dependencies` to `peerDependencies`

## [1.1.1](https://github.com/express-rate-limit/express-rate-limit-postgresql/releases/tag/v1.1.1)

### Added

- Refactored `name` to `prefix` according the
  [express-rate-limit@6.11.1](https://github.com/express-rate-limit/express-rate-limit/releases/tag/v6.11.1)

## [1.1.0](https://github.com/express-rate-limit/express-rate-limit-postgresql/releases/tag/v1.1.0)

### Added

- Using [pkgroll](https://github.com/privatenumber/pkgroll) to bundle library

## [1.0.2](https://github.com/express-rate-limit/express-rate-limit-postgresql/releases/tag/v1.0.2)

### Added

- First release with core functionality according to
  [express-rate-limit guide](https://github.com/express-rate-limit/express-rate-limit/wiki/Creating-Your-Own-Store)
