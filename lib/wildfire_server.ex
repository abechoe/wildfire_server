defmodule WildfireServer do
  use Application

  def start(_type, _args) do
    children = [
      Plug.Cowboy.child_spec(
        scheme: :http,
        plug: WildfireServer.Router,
        options: [dispatch: dispatch(), port: 4000]
      ),
      Registry.child_spec(keys: :duplicate, name: Registry.WildfireServer)
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: WildfireServer.Applicaiton)
  end

  def dispatch do
    [
      {:_,
       [
         {"/ws/[...]", WildfireServer.SocketHandler, []},
         {:_, Plug.Cowboy.Handler, {WildfireServer.Router, []}}
       ]}
    ]
  end
end
