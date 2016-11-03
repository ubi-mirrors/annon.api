defmodule Gateway.Acceptance.Plug.ProxyTest do
  use Gateway.AcceptanceCase
  alias Gateway.Test.Helper

  @api_url "apis"

  @consumer_id Helper.random_string(32)

  @consumer %{
    external_id: @consumer_id,
    metadata: %{"key": "value"},
  }

  @payload %{"id" => @consumer_id, "name" => "John Doe"}
  @token_secret "proxy_secret"

  test "proxy plugin" do

    api_id = @api_url
    |> post(Poison.encode!(get_api_proxy_data("/proxy/test")), :private)
    |> assert_status(201)
    |> get_body()
    |> Poison.decode!
    |> Map.get("data")
    |> Map.get("id")

    proxy_plugin = %{ name: "Proxy", is_enabled: true,
                      settings: %{
                        "proxy_to" => Poison.encode!(%{
                          host: get_host(:private),
                          path: "/apis/#{api_id}",
                          port: get_port(:private),
                          scheme: "http"
                          })
                      }
                    }

    url = @api_url <> "/#{api_id}/plugins"
    url
    |> post(Poison.encode!(proxy_plugin), :private)
    |> assert_status(201)

    response = "proxy/test"
    |> get(:public, [{"authorization", "Bearer #{jwt_token(@payload, @token_secret)}"}])
    |> assert_status(200)
    |> get_body()
    |> Poison.decode!
    |> Map.get("data")

    assert response["id"] == 1
    assert response["request"]["host"] == get_host(:public)
    assert response["request"]["path"] == "/proxy/test"
    assert response["request"]["port"] == get_port(:public)

  end

  test "proxy without sheme and path" do
    proxy_plugin = %{ name: "Proxy", is_enabled: true,
                      settings: %{
                        "proxy_to" => Poison.encode!(%{
                          host: get_host(:private),
                          port: get_port(:private),
                          })
                      }
                    }
    "/apis"
    |> get_api_proxy_data()
    |> Map.put(:plugins, [proxy_plugin])
    |> http_api_create()

    "apis"
    |> get(:public, [{"authorization", "Bearer #{jwt_token(@payload, @token_secret)}"}])
    |> assert_status(200)
  end

  def get_api_proxy_data(path) do
    get_api_model_data()
    |> Map.put(:request,
      %{host: get_host(:public), path: path, port: get_port(:public), scheme: "http", method: "GET"})
    |> Map.put(:plugins, [
      %{name: "JWT", is_enabled: true, settings: %{"signature" => @token_secret}}])
  end

end