# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] - 2026-07-27

### Added

- `SafeAtom.Plug` for casting named, top-level request params against per-field atom whitelists.
- Rejection handling with default `:drop`, built-in `:halt`, and custom two-arity callbacks receiving `SafeAtom.Plug.Rejection`.
- Optional `{:plug, "~> 1.0"}` dependency for applications that use the Plug helper.

## [0.2.0] - 2026-06-09

### Added

- `SafeAtom.Ecto.Enum` — parameterized Ecto type with required `values:` for string-backed atom enum fields; cast, load, and dump use `SafeAtom.cast/2` without unsafe atom creation on external binaries.
- Optional `{:ecto, "~> 3.11"}` dependency for apps that use the Ecto type.

## [0.1.0] - 2026-05-19

### Added

- `SafeAtom.cast/2` for whitelist-based casting of binaries and atoms without growing the atom table from untrusted input.
- `SafeAtom.cast!/2` and `SafeAtom.Error` for raising on failed casts.
- Telemetry event `[:safe_atom, :cast, :rejected]` when `cast/2` returns an error.

[0.3.0]: https://github.com/ivan-podgurskiy/safe_atom/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/ivan-podgurskiy/safe_atom/releases/tag/v0.2.0
[0.1.0]: https://github.com/ivan-podgurskiy/safe_atom/releases/tag/v0.1.0
