defmodule SafeAtom do
  @moduledoc """
  Safe, whitelist-based casting of values to atoms.

  `SafeAtom` returns only atoms that are explicitly present in the `:allowed`
  list.

  Binary input is never converted with `String.to_atom/1` or
  `String.to_existing_atom/1`. Instead, binary values are compared with the
  string representation of atoms already present in `:allowed`.

  This avoids creating new atoms from external input and avoids querying the VM
  atom table for arbitrary binary values.

  ## Examples

      iex> SafeAtom.cast("user", allowed: [:user, :guest])
      {:ok, :user}

      iex> SafeAtom.cast(:user, allowed: [:user, :guest])
      {:ok, :user}

      iex> SafeAtom.cast("admin", allowed: [:user, :guest])
      {:error, :not_allowed}

      iex> SafeAtom.cast(:admin, allowed: [:user, :guest])
      {:error, :not_allowed}

      iex> SafeAtom.cast("anything", allowed: [])
      {:error, :not_allowed}

      iex> SafeAtom.cast("user", [])
      {:error, :missing_allowed}

      iex> SafeAtom.cast("user", allowed: ["user"])
      {:error, :invalid_allowed}

      iex> SafeAtom.cast(123, allowed: [:user])
      {:error, :invalid_value}

      iex> SafeAtom.cast(nil, allowed: [:user])
      {:error, :not_allowed}

      iex> SafeAtom.cast(nil, allowed: [nil])
      {:ok, nil}

  ## Error reasons

    * `:missing_allowed` - the `:allowed` option was not provided.
    * `:invalid_allowed` - `:allowed` is not a list of atoms.
    * `:invalid_value` - the input value is not a binary or an atom.
    * `:not_allowed` - the input value is valid, but does not match any allowed atom.

  ## Telemetry events

  `SafeAtom` emits the following [Telemetry](https://hexdocs.pm/telemetry/) events:

  ### `[:safe_atom, :cast, :rejected]`

  Emitted whenever `cast/2` returns `{:error, reason}`.

  * **measurements**:
    * `:system_time` - `System.system_time/0` at the moment of rejection
  * **metadata**:
    * `:reason` - one of `:missing_allowed`, `:invalid_allowed`, `:invalid_value`, or `:not_allowed`
    * `:value` - the input value passed to `cast/2`
    * `:allowed` - the `:allowed` option value, or `nil` when the option is missing
  """

  @type reason ::
          :missing_allowed
          | :invalid_allowed
          | :invalid_value
          | :not_allowed

  @doc """
  Casts a binary or atom to one of the explicitly allowed atoms.

  The `:allowed` option is required and must be a list of atoms.

  For binary input, `SafeAtom` compares the input with `Atom.to_string/1` for
  each allowed atom. The returned atom is always taken from the `:allowed` list.

  Returns `{:error, :missing_allowed}` when called with options that do not
  contain `:allowed`.

  ## Examples

      iex> SafeAtom.cast("user", allowed: [:user, :guest])
      {:ok, :user}

      iex> SafeAtom.cast(:guest, allowed: [:user, :guest])
      {:ok, :guest}

      iex> SafeAtom.cast("admin", allowed: [:user, :guest])
      {:error, :not_allowed}

      iex> SafeAtom.cast(:admin, allowed: [:user, :guest])
      {:error, :not_allowed}

      iex> SafeAtom.cast("user", allowed: [])
      {:error, :not_allowed}

      iex> SafeAtom.cast("user", [])
      {:error, :missing_allowed}

      iex> SafeAtom.cast("user", allowed: :user)
      {:error, :invalid_allowed}

      iex> SafeAtom.cast("user", allowed: [:user, "guest"])
      {:error, :invalid_allowed}

      iex> SafeAtom.cast(123, allowed: [:user])
      {:error, :invalid_value}

      iex> SafeAtom.cast(nil, allowed: [nil])
      {:ok, nil}

  """
  @spec cast(term(), keyword()) :: {:ok, atom()} | {:error, reason()}
  def cast(value, allowed: allowed) do
    cond do
      not is_list(allowed) ->
        reject(value, :invalid_allowed, allowed)

      not Enum.all?(allowed, &is_atom/1) ->
        reject(value, :invalid_allowed, allowed)

      not is_binary(value) and not is_atom(value) ->
        reject(value, :invalid_value, allowed)

      true ->
        case find_allowed(value, allowed) do
          {:ok, allowed_atom} -> {:ok, allowed_atom}
          :error -> reject(value, :not_allowed, allowed)
        end
    end
  end

  @spec cast(term(), term()) :: {:error, :missing_allowed}
  def cast(value, _opts), do: reject(value, :missing_allowed, nil)

  @spec cast!(term(), keyword()) :: atom()
  def cast!(value, opts) do
    case cast(value, opts) do
      {:ok, atom} ->
        atom

      {:error, reason} ->
        raise SafeAtom.Error,
          value: value,
          reason: reason,
          allowed: allowed_from_opts(opts)
    end
  end

  @spec find_allowed(atom(), [atom()]) :: {:ok, atom()} | :error
  defp find_allowed(value, allowed) when is_atom(value) do
    if value in allowed do
      {:ok, value}
    else
      :error
    end
  end

  @spec find_allowed(binary(), [atom()]) :: {:ok, atom()} | :error
  defp find_allowed(value, allowed) when is_binary(value) do
    Enum.find_value(allowed, :error, fn allowed_atom ->
      if Atom.to_string(allowed_atom) == value do
        {:ok, allowed_atom}
      end
    end)
  end

  @spec allowed_from_opts(term()) :: term()
  defp allowed_from_opts(opts) when is_list(opts), do: Keyword.get(opts, :allowed)
  defp allowed_from_opts(_opts), do: nil

  @spec reject(term(), reason(), term()) :: {:error, reason()}
  defp reject(value, reason, allowed) do
    :telemetry.execute(
      [:safe_atom, :cast, :rejected],
      %{system_time: System.system_time()},
      %{reason: reason, value: value, allowed: allowed}
    )

    {:error, reason}
  end
end
