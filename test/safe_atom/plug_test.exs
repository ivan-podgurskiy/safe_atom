defmodule SafeAtom.PlugTest do
  use ExUnit.Case, async: true

  alias SafeAtom.Plug, as: PlugHelper

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
end
