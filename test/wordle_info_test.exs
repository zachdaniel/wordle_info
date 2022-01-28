defmodule WordleInfoTest do
  use ExUnit.Case
  doctest WordleInfo

  test "greets the world" do
    assert WordleInfo.hello() == :world
  end
end
