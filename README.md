# SafeAtom

[![CI](https://github.com/ivan-podgurskiy/safe_atom/actions/workflows/ci.yml/badge.svg)](https://github.com/ivan-podgurskiy/safe_atom/actions/workflows/ci.yml)
[![Hex pm](https://img.shields.io/hexpm/v/safe_atom.svg)](https://hex.pm/packages/safe_atom)
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
    {:safe_atom, "~> 0.3"}
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

## Ecto

`SafeAtom.Ecto.Enum` is a parameterized Ecto type for atom enum fields. It uses the
same whitelist rules as `SafeAtom.cast/2` for changeset input and database
load/dump. Values are stored as strings (like `Ecto.Enum`).

Add both `safe_atom` and `ecto` to your app:

```elixir
def deps do
  [
    {:safe_atom, "~> 0.3"},
    {:ecto, "~> 3.11"}
  ]
end
```

Migration:

```elixir
add :role, :string
```

Schema:

```elixir
field :role, SafeAtom.Ecto.Enum, values: [:user, :guest]
```

Changeset casting accepts whitelisted strings and atoms; invalid values produce
Ecto inclusion errors. On insert, whitelisted atoms dump to their string form; on
load, DB strings are matched against `values` without `String.to_atom/1`.

## Plug

`SafeAtom.Plug` casts selected top-level request params using a separate atom
whitelist for each field. Plug is optional, so applications using this helper
must include both dependencies:

```elixir
def deps do
  [
    {:safe_atom, "~> 0.3"},
    {:plug, "~> 1.0"}
  ]
end
```

Use it as a module plug in a router or controller pipeline:

```elixir
plug SafeAtom.Plug,
  fields: %{
    status: [:active, :archived],
    sort: [:asc, :desc]
  }
```

Configured field names are atoms, but the helper reads and updates only
string-keyed params. A successful cast produces values such as
`%{"status" => :active}` and leaves unrelated params unchanged.

Rejected values are dropped by default. To return a generic 400 response and
stop processing:

```elixir
plug SafeAtom.Plug,
  fields: %{status: [:active, :archived]},
  on_reject: :halt
```

For application-specific handling, pass a two-arity callback:

```elixir
plug SafeAtom.Plug,
  fields: %{status: [:active, :archived]},
  on_reject: fn conn, rejection ->
    conn
    |> Plug.Conn.assign(:safe_atom_rejection, rejection)
    |> Plug.Conn.send_resp(422, "invalid #{rejection.field}")
    |> Plug.Conn.halt()
  end
```

The callback receives a `SafeAtom.Plug.Rejection` with `field`, `value`, and
`reason`. The helper stops processing more fields if the callback returns a
halted connection.

For ad-hoc use in a controller action:

```elixir
conn =
  SafeAtom.Plug.cast_params(
    conn,
    %{status: [:active, :archived]},
    on_reject: :drop
  )
```

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
| `[:safe_atom, :cast, :rejected]` | `%{system_time: integer()}` | `%{reason, value, allowed}` |

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
