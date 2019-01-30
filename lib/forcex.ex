defmodule Forcex do
  @moduledoc """
  The main module for interacting with Salesforce
  """

  require Logger

  @type client :: map
  @type response :: map | {number, any}
  @type method :: :get | :put | :post | :patch | :delete

  @api Application.get_env(:forcex, :api) || Forcex.Api.Http

  @spec json_request(method, String.t, map | String.t, list, list) :: response
  def json_request(method, url, body, headers, options) do
    Logger.warn("API: #{inspect(@api)}")
    Logger.warn("#{method} #{url} #{format_body(body)} #{inspect(headers)} #{inspect(options)}")
    @api.raw_request(method, url, format_body(body), headers, options)
  end

  @spec post(String.t, map | String.t, client) :: response
  def post(path, body \\ "", client) do
    url = client.endpoint <> path

    headers = [{"Content-Type", "application/json"}] ++ client.authorization_header

    Logger.warn("POST #{url}")
    Logger.warn("|#{inspect(headers)}")
    Logger.warn("|#{body}")
    Logger.warn("|#{inspect(client)}")

    json_request(:post, url, body, headers, [])
  end

  @spec patch(String.t, String.t, client) :: response
  def patch(path, body \\ "", client) do
    url = client.endpoint <> path
    headers = [{"Content-Type", "application/json"}]
    json_request(:patch, url, body, headers ++ client.authorization_header, [])
  end

  @spec delete(String.t, client) :: response
  def delete(path, client) do
    url = client.endpoint <> path
    @api.raw_request(:delete, url, "", client.authorization_header, [])
  end

  @spec get(String.t, map | String.t, list, client) :: response
  def get(path, body \\ "", headers \\ [], client) do
    url = client.endpoint <> path
    Logger.debug("get with url: #{url}")

    req = json_request(:get, url, body, headers ++ client.authorization_header, [])

    Logger.debug("json request: #{inspect(req)}")

    req
  end

  @spec versions(client) :: response
  def versions(%Forcex.Client{} = client) do
    get("/services/data", client)
  end

  @spec services(client) :: response
  def services(%Forcex.Client{} = client) do
    Logger.warn("Calling services with client: #{inspect(client)}")
    Logger.warn("URL: /services/data/v#{client.api_version}")

    response = get("/services/data/v#{client.api_version}", client)

    Logger.warn("Received response #{inspect(response)}")

    response
  end

  @basic_services [
    limits: :limits,
    describe_global: :sobjects,
    quick_actions: :quickActions,
    recently_viewed_items: :recent,
    tabs: :tabs,
    theme: :theme,
  ]

  for {function, service} <- @basic_services do
    @spec unquote(function)(client) :: response
    def unquote(function)(%Forcex.Client{} = client) do
      client
      |> service_endpoint(unquote(service))
      |> get(client)
    end
  end

  @spec describe_sobject(String.t, client) :: response
  def describe_sobject(sobject, %Forcex.Client{} = client) do
    base = service_endpoint(client, :sobjects)

    "#{base}/#{sobject}/describe/"
    |> get(client)
  end

  def attachment_body(binary_path, %Forcex.Client{} = client) do
    base = service_endpoint(client, "sobjects")

    "#{base}/Attachment/#{binary_path}/Body"
    |> get(client)
  end

  @spec metadata_changes_since(String.t, String.t, client) :: response
  def metadata_changes_since(sobject, since, client) do
    base = service_endpoint(client, :sobjects)

    "#{base}/#{sobject}/describe/"
    |> get("", [{"If-Modified-Since", since}], client)
  end

  @spec composite_query(map, client) :: response
  def composite_query(body, %Forcex.Client{} = client) do
    service_endpoint(client, :composite)
    |> post(body, client)
  end

  @spec query(String.t, client) :: response
  def query(query, %Forcex.Client{} = client) do
    base = service_endpoint(client, :query)
    params = %{"q" => query} |> URI.encode_query

    "#{base}/?#{params}"
    |> get(client)
  end

  @spec query_all(String.t, client) :: response
  def query_all(query, %Forcex.Client{} = client) do
    base = service_endpoint(client, :queryAll)
    params = %{"q" => query} |> URI.encode_query

    "#{base}/?#{params}"
    |> get(client)
  end

  @spec service_endpoint(client, String.t) :: String.t
  defp service_endpoint(%Forcex.Client{services: services}, service) do
    Map.get(services, service)
  end

  defp format_body(""), do: ""
  defp format_body(body), do: Poison.encode!(body)
end
