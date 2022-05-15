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
        "https://services9.arcgis.com/RHVPKKiFTONKtxq3/ArcGIS/rest/services/USA_Wildfires_v1/FeatureServer/query?layerDefs=%5B%7B%22layerId%22%3A+0%7D%2C+%7B%22layerId%22%3A+1%7D%5D&geometry=&geometryType=esriGeometryEnvelope&inSR=&spatialRel=esriSpatialRelIntersects&outSR=&datumTransformation=&applyVCSProjection=false&returnGeometry=true&maxAllowableOffset=&geometryPrecision=&returnIdsOnly=false&returnCountOnly=false&returnDistinctValues=false&returnZ=false&returnM=false&sqlFormat=none&f=pjson&token="
      )

    {:ok, %{body: body}} = resp
    {:ok, resp_json} = Jason.decode(body)

    layers = Map.get(resp_json, "layers")

    [layer1_wildfires, layer2_wildfires] =
      Enum.map(layers, fn layer ->
        %{"features" => features} = layer

        features
      end)

    merged =
      Enum.map(layer1_wildfires, fn wf ->
        %{"attributes" => attributes_l1_wf} = wf

        matching_wf =
          Enum.find(layer2_wildfires, fn l2_wf ->
            %{"attributes" => attributes_l2_wf} = l2_wf
            Map.get(attributes_l2_wf, "IRWINID") == Map.get(attributes_l1_wf, "IrwinID")
          end)

        case matching_wf do
          nil ->
            %{}

          _ ->
            Map.merge(wf, matching_wf, fn key, v1, v2 ->
              case key do
                "geometry" -> [v1, v2]
                _ -> v2
              end
            end)
        end
      end)
      |> Enum.filter(fn wf -> Map.keys(wf) |> length > 0 end)

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
