defmodule SafeAtomTest do
  use ExUnit.Case

  doctest SafeAtom

  describe "cast/2" do
    test "returns invalid_value for unsupported input type" do
      assert SafeAtom.cast(1, allowed: [:any_atom]) == {:error, :invalid_value}
      assert SafeAtom.cast(%{}, allowed: [:any_atom]) == {:error, :invalid_value}
    end

    test "returns invalid_allowed when allowed is not a list" do
      assert SafeAtom.cast(:any_atom, allowed: "test") == {:error, :invalid_allowed}
    end

    test "returns invalid_allowed when allowed contains non-atoms" do
      assert SafeAtom.cast("user", allowed: ["user", :admin]) == {:error, :invalid_allowed}
    end

    test "returns not_allowed when binary input is not in allowed" do
      assert SafeAtom.cast("admin", allowed: [:user, :guest]) == {:error, :not_allowed}
    end

    test "casts binary input to the matching allowed atom" do
      assert SafeAtom.cast("user", allowed: [:user, :guest]) == {:ok, :user}
    end

    test "accepts atom input when it is allowed" do
      assert SafeAtom.cast(:guest, allowed: [:user, :guest]) == {:ok, :guest}
    end

    test "treats nil as an atom and returns not_allowed when it is not allowed" do
      assert SafeAtom.cast(nil, allowed: [:user]) == {:error, :not_allowed}
    end

    test "accepts nil when it is explicitly allowed" do
      assert SafeAtom.cast(nil, allowed: [nil]) == {:ok, nil}
    end

    test "returns not_allowed when allowed list is empty" do
      assert SafeAtom.cast("user", allowed: []) == {:error, :not_allowed}
    end

    test "returns missing_allowed when allowed option is missing" do
      assert SafeAtom.cast("user", []) == {:error, :missing_allowed}
    end
  end

  describe "cast!/2" do
    test "returns the atom when casting succeeds" do
      assert SafeAtom.cast!("user", allowed: [:user]) == :user
    end

    test "raises SafeAtom.Error when casting fails" do
      assert_raise SafeAtom.Error, fn ->
        SafeAtom.cast!("admin", allowed: [:user])
      end
    end

    test "raises SafeAtom.Error when opts is not a keyword list" do
      error =
        assert_raise SafeAtom.Error, fn ->
          SafeAtom.cast!("user", :bad)
        end

      assert error.reason == :missing_allowed
      assert error.value == "user"
      assert error.allowed == nil
    end

    test "raises SafeAtom.Error with failure details" do
      error =
        assert_raise SafeAtom.Error, fn ->
          SafeAtom.cast!("admin", allowed: [:user])
        end

      assert error.reason == :not_allowed
      assert error.value == "admin"
      assert error.allowed == [:user]
    end
  end
end
