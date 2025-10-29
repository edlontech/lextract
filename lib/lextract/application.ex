defmodule LeXtract.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      LeXtract.Tokenizer
    ]

    opts = [strategy: :one_for_one, name: LeXtract.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
