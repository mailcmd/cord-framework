defmodule CORD.Application do
  @moduledoc false

  use Application
  require Logger

  @config Application.compile_env!(:cord, :http)
  @local_config Application.compile_env(:cord, :local_config, [])

  @impl true
  def start(_type, _args) do
    Logger.configure(level: Application.get_env(:logger, :level))

    port = Keyword.get(@local_config, :port, Keyword.fetch!(@config, :port))
    sport = Keyword.get(@local_config, :https_port, Keyword.fetch!(@config, :https_port))

    http_server =
      if is_list(port) do
        Enum.map(port, &cowboy_child(&1))
      else
        [ cowboy_child(port) ]
      end

    # sorry for this :'(
    https_server =
      if @local_config[:https] do
        if is_list(sport) do
          Enum.map(sport, &cowboy_child(&1, :https))
        else
          [ cowboy_child(sport, :https) ]
        end
      else
        []
      end

    children = http_server ++ https_server ++ [
      # Channels manager
      {CORD.ChannelsMaster, [:broadcast]},
      # Events manager
      {CORD.EventsMaster,
        {
          Keyword.get(@local_config, :events_pop_interval),
          Keyword.get(@local_config, :websocket_manager)
        }
      },
      # Permanent Storage
      {CORD.PermanentStorage, []}
    ]
    # User defined APP
    ++ (@local_config[:app_supervisor] && [@local_config[:app_supervisor]] || [])

    opts = [strategy: :one_for_one, name: CORD.Supervisor]

    Logger.log(:notice,
               "[CORD] Starting CORD services in ports "<>
               "#{inspect port} #{inspect (@local_config[:https] && sport || "")}..."
    )
    Supervisor.start_link(children, opts)
  end

  defp dispatcher do
    [
      {:_,
       [
         {
           "/websocket", CORD.Websocket, [
             websocket_manager: Keyword.get(@local_config, :websocket_manager)
           ]
         },
         {:_, Plug.Cowboy.Handler, {CORD.Webserver, @config}},
       ]
      }
    ]
  end

  defp cowboy_child(port, scheme \\ :http)
  defp cowboy_child(port, :http) do
    Supervisor.child_spec(
      {
        Plug.Cowboy,
        scheme: :http,
        plug: {CORD.Webserver, @config},
        options: [
          port: port,
          ref: {:ranch_listener, "http_#{port}"},
          dispatch: dispatcher()
        ]
      },
      id: {:cowboy, port}
    )
  end

  defp cowboy_child({port, keyfile, certfile}, :https) do
    Supervisor.child_spec(
      {
        Plug.Cowboy,
        scheme: :https,
        plug: {CORD.Webserver, @config},
        options: [
          port: port,
          ref: {:ranch_listener, "https_#{port}"},
          dispatch: dispatcher(),
          keyfile: keyfile,
          certfile: certfile,
          otp_app: :secure_app
        ]
      },
      id: {:cowboy, port}
    )
  end

  defp cowboy_child(port, :https) do
    Supervisor.child_spec(
      {
        Plug.Cowboy,
        scheme: :https,
        plug: {CORD.Webserver, @config},
        options: [
          port: port,
          ref: {:ranch_listener, "https_#{port}"},
          dispatch: dispatcher(),
          keyfile: Keyword.get(@local_config, :keyfile),
          certfile: Keyword.get(@local_config, :certfile),
          otp_app: :secure_app
        ]
      },
      id: {:cowboy, port}
    )
  end
  
end
