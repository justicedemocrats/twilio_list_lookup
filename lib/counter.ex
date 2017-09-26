defmodule Counter do
  use Agent

  def start_link do
    Agent.start_link fn -> 0 end, name: __MODULE__
  end

  def inc do
    Agent.update __MODULE__, fn i -> i + 1 end
  end

  def get do
    Agent.get __MODULE__, fn i -> i end
  end
end
