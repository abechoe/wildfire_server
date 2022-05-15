defmodule WildfireServerTest do
  use ExUnit.Case
  doctest WildfireServer

  test "greets the world" do
    assert WildfireServer.hello() == :world
  end
end
