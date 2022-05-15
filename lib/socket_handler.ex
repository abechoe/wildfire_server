defmodule WildfireServer.SocketHandler do
  @behaviour :cowboy_websocket

  def init(request, _state) do
    state = %{registry_key: request.path}

    {:cowboy_websocket, request, state}
  end

  def websocket_init(state) do
    Registry.register(Registry.WildfireServer, state.registry_key, {})

    resp =
      HTTPoison.get(
        "https://services9.arcgis.com/RHVPKKiFTONKtxq3/ArcGIS/rest/services/USA_Wildfires_v1/FeatureServer/query?layerDefs=%5B%7B%22layerId%22%3A+0%2C+%22where%22%3A+%22IncidentName%3D%27San+Luis%27%22%7D%2C+%7B%22layerId%22%3A+1%2C+%22where%22%3A+%22IncidentName%3D%27San+Luis%27%22%7D%5D&geometry=&geometryType=esriGeometryEnvelope&inSR=&spatialRel=esriSpatialRelIntersects&outSR=&datumTransformation=&applyVCSProjection=false&returnGeometry=true&maxAllowableOffset=&geometryPrecision=&returnIdsOnly=false&returnCountOnly=false&returnDistinctValues=false&returnZ=false&returnM=false&sqlFormat=none&f=pjson&token="
      )

    {:ok, %{body: body}} = resp
    {:ok, resp_json} = Jason.decode(body)

    layers = Map.get(resp_json, "layers")

    [layer1_wildfire, layer2_wildfire] =
      Enum.map(layers, fn layer ->
        %{"features" => [%{"attributes" => attributes, "geometry" => geometry}]} = layer

        %{
          irwin_id: Map.get(attributes, "IrwinID") || Map.get(attributes, "IRWINID"),
          incident_name: Map.get(attributes, "IncidentName"),
          geometry: geometry
        }
      end)

    merged =
      Map.merge(layer1_wildfire, layer2_wildfire, fn key, v1, v2 ->
        case key do
          :geometry -> [v1, v2]
          _ -> v2
        end
      end)

    {:ok, encoded} = Jason.encode(merged)

    Registry.WildfireServer
    |> Registry.dispatch(state.registry_key, fn entries ->
      for {pid, _} <- entries do
        Process.send(pid, encoded, [])
      end
    end)

    {:ok, state}
  end

  def websocket_handle({:text, json}, state) do
    payload = Jason.decode!(json)
    message = payload["data"]["message"]

    Registry.WildfireServer
    |> Registry.dispatch(state.registry_key, fn entries ->
      for {pid, _} <- entries do
        if pid != self() do
          Process.send(pid, message, [])
        end
      end
    end)

    {:reply, {:text, message}, state}
  end

  def websocket_info(info, state) do
    {:reply, {:text, info}, state}
  end
end
