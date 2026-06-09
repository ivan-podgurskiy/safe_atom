# SafeAtom roadmap

Defensive atom conversion for boundary inputs in Elixir — not a “security library”.

## What I wanted

Safely cast a string or atom to an atom from an explicit `:allowed` whitelist, without growing the atom table from user input.

- `cast/2` → `{:ok, atom}` or `{:error, reason}`
- `cast!/2` → atom or `SafeAtom.Error` with `value`, `reason`, and `allowed`
- Errors for bad input type, atom not in whitelist, string not in whitelist
- Telemetry `[:safe_atom, :cast, :rejected]` on rejections only
- README explaining the `String.to_atom/1` risk, tests, doctest, CI

Out of scope for the first release: global whitelists in config, Plug, `:on_reject` callbacks, auto-whitelist from all VM atoms.

## What we shipped (v0.1.0)

- `SafeAtom.cast/2` and `SafeAtom.cast!/2` with required `allowed: [atom()]`
- Binary input matched only against `Atom.to_string/1` for allowed atoms — no `String.to_atom/1` or `String.to_existing_atom/1` on external data
- `SafeAtom.Error` when `cast!/2` fails
- Telemetry on every `cast/2` error (metadata: `value`, `reason`, `allowed`)
- Error reasons: `:missing_allowed`, `:invalid_allowed`, `:invalid_value`, `:not_allowed`
- Unit tests, doctests, telemetry covered with `:telemetry_test`
- README (including Why?), ExDoc, Credo, Dialyzer, CI, Hex publish

## What we shipped (v0.2.0)

- `SafeAtom.Ecto.Enum` — Ecto type with required `values:` for string-backed atom enum fields (optional `ecto` dep)
- cast / load / dump via `SafeAtom.cast/2`; Ecto-style inclusion errors on changesets

## What’s next

- Plug helper for params
- Whitelist via `Application` config
- Per-field whitelists (`:allowed_per_field`)
