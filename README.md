# SafeAtom

[![CI](https://github.com/ivan-podgurskiy/safe_atom/actions/workflows/ci.yml/badge.svg)](https://github.com/ivan-podgurskiy/safe_atom/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Whitelist-based casting of values to atoms without growing the VM atom table from
untrusted input.

`SafeAtom` never calls `String.to_atom/1` or `String.to_existing_atom/1` on
external data. Binary input is matched against `Atom.to_string/1` for atoms you
already listed in `:allowed`, and the returned atom always comes from that list.

## Installation

Add `safe_atom` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:safe_atom, "~> 0.1"}
  ]
end
```

Or depend on the Git repository:

```elixir
{:safe_atom, git: "https://github.com/ivan-podgurskiy/safe_atom.git"}
```

## Quick start

```elixir
SafeAtom.cast("user", allowed: [:user, :guest])
# => {:ok, :user}

SafeAtom.cast(:guest, allowed: [:user, :guest])
# => {:ok, :guest}

SafeAtom.cast("admin", allowed: [:user, :guest])
# => {:error, :not_allowed}

SafeAtom.cast!("user", allowed: [:user, :guest])
# => :user
```

## API

### `SafeAtom.cast/2`

Casts a binary or atom to one of the atoms in `allowed: [...]`.

- `:allowed` is required and must be a list of atoms.
- Binary input is compared to each allowed atom’s string form.
- Atom input must already be a member of `:allowed`.
- `nil` is treated as an atom; include `nil` in `:allowed` if you need it.

Returns `{:ok, atom()}` or `{:error, reason}`.

### `SafeAtom.cast!/2`

Same as `cast/2`, but raises `SafeAtom.Error` on failure. The exception carries
`value`, `reason`, and `allowed` for debugging.

### Error reasons

| Reason | When |
| --- | --- |
| `:missing_allowed` | `:allowed` was not provided |
| `:invalid_allowed` | `:allowed` is not a list of atoms |
| `:invalid_value` | Input is neither a binary nor an atom |
| `:not_allowed` | Input is valid but not in the whitelist |

## Why?

Atoms in the Erlang VM are not garbage-collected. Calling `String.to_atom/1` on
user-controlled strings can exhaust the atom table and crash the node.
`String.to_existing_atom/1` avoids creating new atoms but still walks the global
atom table for every lookup.

`SafeAtom` keeps casting explicit: you declare the finite set of atoms you accept,
and only those atoms can be returned.

## Telemetry

`SafeAtom` emits one event whenever `cast/2` returns an error:

| Event | Measurements | Metadata |
| --- | --- | --- |
| `[:safe_atom, :cast, :rejected]` | `%{}` | `%{reason, value, allowed}` |

Successful casts do not emit events. Attach a handler with `:telemetry.attach/4`
to log rejections or aggregate rates.

```elixir
:telemetry.attach(
  "safe-atom-rejections",
  [:safe_atom, :cast, :rejected],
  fn _event, _measurements, %{reason: reason, value: value}, _config ->
    Logger.warning("SafeAtom rejected #{inspect(value)}: #{reason}")
  end,
  nil
)
```

## Development

```bash
mix test
mix credo --strict
mix dialyzer
mix docs
```

## License

MIT © Ivan Podgurskiy. See [LICENSE](LICENSE).
