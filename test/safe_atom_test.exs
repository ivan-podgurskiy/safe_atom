defmodule SafeAtomTest do
  use ExUnit.Case
  doctest SafeAtom

  test "example/1 doubles integers" do
    assert SafeAtom.example(3) == 6
  end
end
