if Code.ensure_loaded?(Ecto.ParameterizedType) do
  defmodule SafeAtom.Ecto.Enum do
    @moduledoc """
    Parameterized Ecto type for whitelist-based atom enum fields.

    Requires `values:` — a list of atoms allowed for the field. Values are stored
    as strings in the database. Cast, load, and dump use `SafeAtom.cast/2` so
    external binaries never go through `String.to_atom/1` or
    `String.to_existing_atom/1`.

    ## Schema

        field :role, SafeAtom.Ecto.Enum, values: [:user, :guest]

    ## Examples

        iex> params = SafeAtom.Ecto.Enum.init(values: [:user, :guest])
        iex> SafeAtom.Ecto.Enum.cast("user", params)
        {:ok, :user}

        iex> params = SafeAtom.Ecto.Enum.init(values: [:user, :guest])
        iex> SafeAtom.Ecto.Enum.cast("admin", params)
        {:error, [validation: :inclusion, enum: [:user, :guest]]}

        iex> params = SafeAtom.Ecto.Enum.init(values: [:user, :guest])
        iex> SafeAtom.Ecto.Enum.dump(:user, fn _, v -> {:ok, v} end, params)
        {:ok, "user"}
    """

    use Ecto.ParameterizedType

    @impl true
    def init(opts) do
      values =
        case Keyword.fetch(opts, :values) do
          {:ok, values} -> values
          :error -> raise_invalid_values!(opts)
        end

      cond do
        not is_list(values) -> raise_invalid_values!(values)
        not Enum.all?(values, &is_atom/1) -> raise_invalid_values!(values)
        true -> %{values: values}
      end
    end

    @impl true
    def type(_params), do: :string

    @impl true
    def cast(nil, _params), do: {:ok, nil}

    def cast(value, %{values: values}) when is_binary(value) or is_atom(value) do
      case SafeAtom.cast(value, allowed: values) do
        {:ok, atom} -> {:ok, atom}
        {:error, :not_allowed} -> {:error, [validation: :inclusion, enum: values]}
      end
    end

    def cast(_value, _params), do: :error

    @impl true
    def load(nil, _loader, _params), do: {:ok, nil}

    def load(value, _loader, %{values: values}) when is_binary(value) do
      case SafeAtom.cast(value, allowed: values) do
        {:ok, atom} -> {:ok, atom}
        {:error, :not_allowed} -> :error
      end
    end

    def load(_value, _loader, _params), do: :error

    @impl true
    def dump(nil, _dumper, _params), do: {:ok, nil}

    def dump(value, _dumper, %{values: values}) when is_atom(value) do
      if value in values do
        {:ok, Atom.to_string(value)}
      else
        :error
      end
    end

    def dump(_value, _dumper, _params), do: :error

    defp raise_invalid_values!(given) do
      raise ArgumentError,
            "SafeAtom.Ecto.Enum requires a :values option, a list of atoms, got: " <>
              inspect(given)
    end
  end
end
