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

    Configured field names are atoms, while request param lookups use their string
    forms. Successful values remain under string keys. Rejected values are dropped
    by default.

    ## Module plug

        plug SafeAtom.Plug,
          fields: %{status: [:active, :archived], sort: [:asc, :desc]}

    Use `on_reject: :halt` to send a 400 response and halt the connection, or pass
    a two-arity function that receives the connection and a
    `SafeAtom.Plug.Rejection` structure.

    ## Function plug

        iex> conn = Plug.Test.conn(:get, "/")
        iex> conn = %{conn | params: %{"status" => "active", "query" => "keep"}}
        iex> conn = SafeAtom.Plug.cast_params(conn, %{status: [:active, :archived]})
        iex> conn.params
        %{"query" => "keep", "status" => :active}

        iex> conn = Plug.Test.conn(:get, "/")
        iex> conn = %{conn | params: %{"status" => "deleted"}}
        iex> conn = SafeAtom.Plug.cast_params(conn, %{status: [:active]})
        iex> conn.params
        %{}
    """

    @behaviour Plug

    alias SafeAtom.Plug.Rejection

    @type fields :: %{atom() => [atom()]}
    @type on_reject ::
            :drop
            | :halt
            | (Plug.Conn.t(), Rejection.t() -> Plug.Conn.t())

    @impl Plug
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

    @impl Plug
    @spec call(Plug.Conn.t(), keyword()) :: Plug.Conn.t()
    def call(conn, opts) do
      cast_params(
        conn,
        Keyword.fetch!(opts, :fields),
        on_reject: Keyword.fetch!(opts, :on_reject)
      )
    end

    @spec cast_params(Plug.Conn.t(), fields(), keyword()) :: Plug.Conn.t()
    def cast_params(conn, fields, opts \\ []) do
      normalized_opts = init(Keyword.put(opts, :fields, fields))
      on_reject = Keyword.fetch!(normalized_opts, :on_reject)

      fields
      |> Enum.sort_by(fn {field, _allowed} -> field end)
      |> Enum.reduce_while(conn, fn {field, allowed}, current_conn ->
        cast_field(current_conn, field, allowed, on_reject)
      end)
    end

    @spec cast_field(Plug.Conn.t(), atom(), [atom()], on_reject()) ::
            {:cont, Plug.Conn.t()} | {:halt, Plug.Conn.t()}
    defp cast_field(conn, field, allowed, on_reject) do
      key = Atom.to_string(field)

      case Map.fetch(conn.params, key) do
        :error ->
          {:cont, conn}

        {:ok, value} ->
          case SafeAtom.cast(value, allowed: allowed) do
            {:ok, atom} ->
              {:cont, put_param(conn, key, atom)}

            {:error, reason} ->
              rejection = %Rejection{
                field: field,
                value: value,
                reason: reason
              }

              conn
              |> handle_rejection(key, rejection, on_reject)
              |> continue_or_halt()
          end
      end
    end

    @spec put_param(Plug.Conn.t(), String.t(), atom()) :: Plug.Conn.t()
    defp put_param(conn, key, value) do
      %{conn | params: Map.put(conn.params, key, value)}
    end

    @spec handle_rejection(
            Plug.Conn.t(),
            String.t(),
            Rejection.t(),
            on_reject()
          ) :: Plug.Conn.t()
    defp handle_rejection(conn, key, _rejection, :drop) do
      %{conn | params: Map.delete(conn.params, key)}
    end

    defp handle_rejection(conn, _key, _rejection, :halt) do
      conn
      |> Plug.Conn.send_resp(400, "Bad Request")
      |> Plug.Conn.halt()
    end

    defp handle_rejection(conn, _key, rejection, on_reject)
         when is_function(on_reject, 2) do
      on_reject.(conn, rejection)
    end

    @spec continue_or_halt(Plug.Conn.t()) ::
            {:cont, Plug.Conn.t()} | {:halt, Plug.Conn.t()}
    defp continue_or_halt(%Plug.Conn{halted: true} = conn), do: {:halt, conn}
    defp continue_or_halt(conn), do: {:cont, conn}

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
