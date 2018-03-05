defmodule CapuliTest do
  use ExUnit.Case
  doctest Capuli

  test "greets the world" do
    assert Capuli.hello() == :world
  end
end
