defmodule Comparer.JsonFixtures do
  def json_fixtures(header_req \\ [], header_resp \\ []) do
    %{
      "http_version" => "HTTP/1.1",
      "request" => %{
        "body" => "body",
        "headers" => header_req,
        "method" => "GET",
        "url" => "same_url"
      },
      "response" => %{
        "body" => "body",
        "headers" => header_resp,
        "status_code" => 200,
        "status_text" => "OK"
      }
    }
  end

  def header_fixtures(new_value \\ "40") do
    [
      %{"name" => "Content-Length", "value" => new_value},
      %{"name" => "Content-Type", "value" => "application/json; charset=utf-8"}
    ]
  end
end
