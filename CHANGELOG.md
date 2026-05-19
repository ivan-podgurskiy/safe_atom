# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-05-19

### Added

- `SafeAtom.cast/2` for whitelist-based casting of binaries and atoms without growing the atom table from untrusted input.
- `SafeAtom.cast!/2` and `SafeAtom.Error` for raising on failed casts.
- Telemetry event `[:safe_atom, :cast, :rejected]` when `cast/2` returns an error.

[0.1.0]: https://github.com/ivan-podgurskiy/safe_atom/releases/tag/v0.1.0
