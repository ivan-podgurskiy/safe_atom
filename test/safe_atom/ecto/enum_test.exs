defmodule SafeAtom.Ecto.EnumTest do
  use ExUnit.Case, async: true

  alias SafeAtom.Ecto.Enum, as: Type

  describe "init/1" do
    test "raises ArgumentError when :values is missing" do
      assert_raise ArgumentError, ~r/:values/, fn -> Type.init([]) end
    end

    test "raises ArgumentError when :values is not a list" do
      assert_raise ArgumentError, ~r/:values/, fn -> Type.init(values: :user) end
    end

    test "raises ArgumentError when :values contains non-atoms" do
      assert_raise ArgumentError, ~r/:values/, fn ->
        Type.init(values: [:user, "guest"])
      end
    end

    test "returns params map with :values when input is valid" do
      assert Type.init(values: [:user, :guest]) == %{values: [:user, :guest]}
    end

    test "allows an empty list of values" do
      assert Type.init(values: []) == %{values: []}
    end
  end

  describe "type/1" do
    test "returns :string regardless of params" do
      params = Type.init(values: [:user, :guest])
      assert Type.type(params) == :string
    end
  end

  describe "cast/2" do
    setup do
      {:ok, params: Type.init(values: [:user, :guest])}
    end

    test "nil casts to {:ok, nil}", %{params: params} do
      assert Type.cast(nil, params) == {:ok, nil}
    end

    test "binary matching a whitelisted atom casts to that atom", %{params: params} do
      assert Type.cast("user", params) == {:ok, :user}
      assert Type.cast("guest", params) == {:ok, :guest}
    end

    test "whitelisted atom casts to itself", %{params: params} do
      assert Type.cast(:user, params) == {:ok, :user}
    end

    test "binary not in whitelist returns Ecto-style inclusion error", %{params: params} do
      assert Type.cast("admin", params) ==
               {:error, [validation: :inclusion, enum: [:user, :guest]]}
    end

    test "atom not in whitelist returns Ecto-style inclusion error", %{params: params} do
      assert Type.cast(:admin, params) ==
               {:error, [validation: :inclusion, enum: [:user, :guest]]}
    end

    test "non-binary, non-atom input returns :error", %{params: params} do
      assert Type.cast(123, params) == :error
      assert Type.cast(%{}, params) == :error
      assert Type.cast([1, 2], params) == :error
    end
  end

  describe "load/3" do
    setup do
      {:ok, params: Type.init(values: [:user, :guest])}
    end

    test "nil loads to {:ok, nil}", %{params: params} do
      assert Type.load(nil, fn _, v -> {:ok, v} end, params) == {:ok, nil}
    end

    test "binary matching a whitelisted atom loads to that atom", %{params: params} do
      assert Type.load("user", fn _, v -> {:ok, v} end, params) == {:ok, :user}
    end

    test "binary not in whitelist returns :error (no unsafe atom creation)", %{params: params} do
      assert Type.load("admin", fn _, v -> {:ok, v} end, params) == :error
    end

    test "non-binary DB value returns :error", %{params: params} do
      assert Type.load(123, fn _, v -> {:ok, v} end, params) == :error
    end
  end

  describe "dump/3" do
    setup do
      {:ok, params: Type.init(values: [:user, :guest])}
    end

    test "nil dumps to {:ok, nil}", %{params: params} do
      assert Type.dump(nil, fn _, v -> {:ok, v} end, params) == {:ok, nil}
    end

    test "whitelisted atom dumps to its string representation", %{params: params} do
      assert Type.dump(:user, fn _, v -> {:ok, v} end, params) == {:ok, "user"}
      assert Type.dump(:guest, fn _, v -> {:ok, v} end, params) == {:ok, "guest"}
    end

    test "non-whitelisted atom returns :error", %{params: params} do
      assert Type.dump(:admin, fn _, v -> {:ok, v} end, params) == :error
    end

    test "non-atom value returns :error", %{params: params} do
      assert Type.dump("user", fn _, v -> {:ok, v} end, params) == :error
      assert Type.dump(123, fn _, v -> {:ok, v} end, params) == :error
    end
  end
end
