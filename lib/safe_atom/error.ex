defmodule SafeAtom.Error do
  @moduledoc """
  Exception raised by `SafeAtom.cast!/2`.
  """

  defexception [:value, :reason, :allowed]

  @type t :: %__MODULE__{
          value: term(),
          reason: SafeAtom.reason(),
          allowed: term()
        }

  @impl true
  def message(%__MODULE__{value: value, reason: reason, allowed: allowed}) do
    "failed to cast #{inspect(value)} to allowed atom: " <>
      "#{inspect(reason)} (allowed: #{inspect(allowed)})"
  end
end
