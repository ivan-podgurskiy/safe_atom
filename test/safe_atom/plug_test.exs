defmodule SafeAtom.PlugTest do
  use ExUnit.Case, async: true

  doctest SafeAtom.Plug

  alias SafeAtom.Plug, as: PlugHelper
  alias SafeAtom.Plug.Rejection

  defp conn_with_params(params) do
    conn = Plug.Test.conn(:get, "/")
    %{conn | params: params}
  end

  describe "init/1" do
    test "normalizes valid fields with the default rejection policy" do
      fields = %{status: [:active, :archived]}

      assert PlugHelper.init(fields: fields) == [fields: fields, on_reject: :drop]
    end

    test "accepts :halt and a two-arity rejection callback" do
      fields = %{status: [:active]}
      callback = fn conn, _rejection -> conn end

      assert PlugHelper.init(fields: fields, on_reject: :halt) ==
               [fields: fields, on_reject: :halt]

      opts = PlugHelper.init(fields: fields, on_reject: callback)
      assert opts[:fields] == fields
      assert opts[:on_reject] == callback
    end

    test "allows an empty fields map and empty allowed lists" do
      assert PlugHelper.init(fields: %{}) == [fields: %{}, on_reject: :drop]

      assert PlugHelper.init(fields: %{status: []}) ==
               [fields: %{status: []}, on_reject: :drop]
    end

    test "raises when :fields is missing" do
      assert_raise ArgumentError, ~r/:fields/, fn ->
        PlugHelper.init([])
      end
    end

    test "raises when :fields is not a map" do
      assert_raise ArgumentError, ~r/:fields/, fn ->
        PlugHelper.init(fields: [status: [:active]])
      end
    end

    test "raises when a field key is not an atom" do
      assert_raise ArgumentError, ~r/:fields/, fn ->
        PlugHelper.init(fields: %{"status" => [:active]})
      end
    end

    test "raises when a field whitelist is not a list" do
      assert_raise ArgumentError, ~r/:fields/, fn ->
        PlugHelper.init(fields: %{status: :active})
      end
    end

    test "raises when a field whitelist contains a non-atom" do
      assert_raise ArgumentError, ~r/:fields/, fn ->
        PlugHelper.init(fields: %{status: [:active, "archived"]})
      end
    end

    test "raises when :on_reject is unsupported or has the wrong arity" do
      assert_raise ArgumentError, ~r/:on_reject/, fn ->
        PlugHelper.init(fields: %{}, on_reject: :raise)
      end

      assert_raise ArgumentError, ~r/:on_reject/, fn ->
        PlugHelper.init(fields: %{}, on_reject: fn conn -> conn end)
      end
    end
  end

  describe "cast_params/3 with successful and absent values" do
    test "casts a present string value and preserves unrelated params" do
      conn =
        conn_with_params(%{
          "status" => "active",
          "query" => "safe atoms"
        })

      result = PlugHelper.cast_params(conn, %{status: [:active, :archived]})

      assert result.params == %{
               "status" => :active,
               "query" => "safe atoms"
             }
    end

    test "casts a present allowed atom without changing the string key" do
      conn = conn_with_params(%{"status" => :active})

      result = PlugHelper.cast_params(conn, %{status: [:active, :archived]})

      assert result.params == %{"status" => :active}
    end

    test "ignores atom-keyed params" do
      conn = conn_with_params(%{status: "active"})

      result = PlugHelper.cast_params(conn, %{status: [:active]})

      assert result.params == %{status: "active"}
    end

    test "leaves the connection unchanged when the configured key is absent" do
      conn = conn_with_params(%{"query" => "safe atoms"})

      result = PlugHelper.cast_params(conn, %{status: [:active]})

      assert result == conn
    end

    test "handles successful, absent, and rejected fields in one call" do
      conn =
        conn_with_params(%{
          "status" => "active",
          "sort" => "sideways",
          "query" => "safe atoms"
        })

      result =
        PlugHelper.cast_params(conn, %{
          status: [:active, :archived],
          sort: [:asc, :desc],
          visibility: [:public, :private]
        })

      assert result.params == %{
               "status" => :active,
               "query" => "safe atoms"
             }
    end
  end

  describe "cast_params/3 with the default :drop policy" do
    test "deletes a non-whitelisted value" do
      conn = conn_with_params(%{"status" => "deleted", "query" => "keep"})

      result = PlugHelper.cast_params(conn, %{status: [:active, :archived]})

      assert result.params == %{"query" => "keep"}
    end

    test "routes invalid input types through rejection handling" do
      conn = conn_with_params(%{"status" => %{"nested" => "active"}})

      result = PlugHelper.cast_params(conn, %{status: [:active]})

      assert result.params == %{}
    end

    test "validates fields and :on_reject when called directly" do
      conn = conn_with_params(%{})

      assert_raise ArgumentError, ~r/:fields/, fn ->
        PlugHelper.cast_params(conn, %{"status" => [:active]})
      end

      assert_raise ArgumentError, ~r/:on_reject/, fn ->
        PlugHelper.cast_params(conn, %{status: [:active]}, on_reject: :raise)
      end
    end
  end

  describe "telemetry" do
    test "does not emit a rejection when the configured key is absent" do
      ref =
        :telemetry_test.attach_event_handlers(
          self(),
          [[:safe_atom, :cast, :rejected]]
        )

      on_exit(fn -> :telemetry.detach(ref) end)

      conn = conn_with_params(%{"query" => "keep"})
      assert PlugHelper.cast_params(conn, %{status: [:active]}) == conn
      refute_received {[:safe_atom, :cast, :rejected], ^ref, _, _}
    end

    test "reuses SafeAtom.cast/2 rejection telemetry" do
      ref =
        :telemetry_test.attach_event_handlers(
          self(),
          [[:safe_atom, :cast, :rejected]]
        )

      on_exit(fn -> :telemetry.detach(ref) end)

      conn = conn_with_params(%{"status" => "deleted"})
      PlugHelper.cast_params(conn, %{status: [:active, :archived]})

      assert_received {
        [:safe_atom, :cast, :rejected],
        ^ref,
        %{system_time: system_time},
        %{
          reason: :not_allowed,
          value: "deleted",
          allowed: [:active, :archived]
        }
      }

      assert is_integer(system_time)
    end
  end

  describe "call/2" do
    test "uses normalized module-plug options" do
      conn = conn_with_params(%{"status" => "active"})
      opts = PlugHelper.init(fields: %{status: [:active, :archived]})

      result = PlugHelper.call(conn, opts)

      assert result.params == %{"status" => :active}
    end
  end

  describe "cast_params/3 with :halt" do
    test "sends a 400 Bad Request response and halts" do
      conn = conn_with_params(%{"status" => "deleted"})

      result =
        PlugHelper.cast_params(
          conn,
          %{status: [:active, :archived]},
          on_reject: :halt
        )

      assert result.halted
      assert result.status == 400
      assert result.resp_body == "Bad Request"
      assert result.state == :sent
    end

    test "stops before processing later fields in sorted field order" do
      ref =
        :telemetry_test.attach_event_handlers(
          self(),
          [[:safe_atom, :cast, :rejected]]
        )

      on_exit(fn -> :telemetry.detach(ref) end)

      conn =
        conn_with_params(%{
          "alpha" => "invalid",
          "omega" => "also-invalid"
        })

      result =
        PlugHelper.cast_params(
          conn,
          %{omega: [:valid], alpha: [:valid]},
          on_reject: :halt
        )

      assert result.halted
      assert result.params["omega"] == "also-invalid"

      assert_received {
        [:safe_atom, :cast, :rejected],
        ^ref,
        _measurements,
        %{value: "invalid"}
      }

      refute_received {
        [:safe_atom, :cast, :rejected],
        ^ref,
        _measurements,
        %{value: "also-invalid"}
      }
    end
  end

  describe "cast_params/3 with a custom rejection callback" do
    test "passes complete rejection details and threads the returned conn" do
      callback = fn conn, %Rejection{} = rejection ->
        Plug.Conn.assign(conn, :safe_atom_rejection, rejection)
      end

      conn = conn_with_params(%{"status" => %{"nested" => "active"}})

      result =
        PlugHelper.cast_params(
          conn,
          %{status: [:active]},
          on_reject: callback
        )

      assert result.assigns.safe_atom_rejection == %Rejection{
               field: :status,
               value: %{"nested" => "active"},
               reason: :invalid_value
             }

      assert result.params == %{"status" => %{"nested" => "active"}}
      refute result.halted
    end

    test "stops processing when the callback returns a halted conn" do
      callback = fn conn, rejection ->
        conn
        |> Plug.Conn.assign(:safe_atom_rejection, rejection)
        |> Plug.Conn.halt()
      end

      conn =
        conn_with_params(%{
          "alpha" => "invalid",
          "omega" => "valid"
        })

      result =
        PlugHelper.cast_params(
          conn,
          %{omega: [:valid], alpha: [:valid]},
          on_reject: callback
        )

      assert result.halted
      assert result.assigns.safe_atom_rejection.field == :alpha
      assert result.params["omega"] == "valid"
    end
  end
end
