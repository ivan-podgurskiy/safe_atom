if Code.ensure_loaded?(Plug.Conn) do
  defmodule SafeAtom.Plug.Rejection do
    @moduledoc """
    Details about a request parameter rejected by `SafeAtom.Plug`.
    """

    @enforce_keys [:field, :value, :reason]
    defstruct [:field, :value, :reason]

    @type t :: %__MODULE__{
            field: atom(),
            value: term(),
            reason: SafeAtom.reason()
          }
  end

  defmodule SafeAtom.Plug do
    @moduledoc """
    Casts named request parameters against per-field atom whitelists.
    """

    alias SafeAtom.Plug.Rejection

    @type fields :: %{atom() => [atom()]}
    @type on_reject ::
            :drop
            | :halt
            | (Plug.Conn.t(), Rejection.t() -> Plug.Conn.t())

    @spec init(keyword()) :: keyword()
    def init(opts) do
      fields =
        case Keyword.fetch(opts, :fields) do
          {:ok, fields} -> fields
          :error -> raise_invalid_fields!(:missing)
        end

      on_reject = Keyword.get(opts, :on_reject, :drop)

      validate_fields!(fields)
      validate_on_reject!(on_reject)

      [fields: fields, on_reject: on_reject]
    end

    @spec validate_fields!(term()) :: :ok
    defp validate_fields!(fields) when is_map(fields) do
      if Enum.all?(fields, fn
           {field, allowed} when is_atom(field) and is_list(allowed) ->
             Enum.all?(allowed, &is_atom/1)

           _other ->
             false
         end) do
        :ok
      else
        raise_invalid_fields!(fields)
      end
    end

    defp validate_fields!(fields), do: raise_invalid_fields!(fields)

    @spec validate_on_reject!(term()) :: :ok
    defp validate_on_reject!(on_reject)
         when on_reject in [:drop, :halt] or is_function(on_reject, 2),
         do: :ok

    defp validate_on_reject!(on_reject) do
      raise ArgumentError,
            "SafeAtom.Plug requires :on_reject to be :drop, :halt, or a " <>
              "two-arity function, got: #{inspect(on_reject)}"
    end

    @spec raise_invalid_fields!(term()) :: no_return()
    defp raise_invalid_fields!(given) do
      raise ArgumentError,
            "SafeAtom.Plug requires a :fields option containing a map of " <>
              "atom field names to lists of atoms, got: #{inspect(given)}"
    end
  end
end
