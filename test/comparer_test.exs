defmodule ComparerTest do
  use ExUnit.Case

  use ExUnit.Case
  import Comparer.JsonFixtures

  alias Comparer

  describe "added/removed request" do
    test "added request by different method on new version must return added_request" do
      json = json_fixtures()
      json2 = [put_in(json, ["request", "method"], "PATCH") | [json]]

      assert [
               %{
                 added_request: %{
                   "http_version" => "HTTP/1.1",
                   "request" => %{
                     "body" => "body",
                     "headers" => [],
                     "method" => "PATCH",
                     "url" => "same_url"
                   },
                   "response" => %{
                     "body" => "body",
                     "headers" => [],
                     "status_code" => 200,
                     "status_text" => "OK"
                   }
                 }
               },
               %{}
             ] == Comparer.compare_versions([json], json2)
    end

    test "added request by different url on new version must return added_request" do
      json = json_fixtures()
      json2 = [put_in(json, ["request", "url"], "different_url") | [json]]

      assert [
               %{
                 added_request: %{
                   "http_version" => "HTTP/1.1",
                   "request" => %{
                     "body" => "body",
                     "headers" => [],
                     "method" => "GET",
                     "url" => "different_url"
                   },
                   "response" => %{
                     "body" => "body",
                     "headers" => [],
                     "status_code" => 200,
                     "status_text" => "OK"
                   }
                 }
               },
               %{}
             ] == Comparer.compare_versions([json], json2)
    end

    test "removed request by different method on old version must return removed_request" do
      json = json_fixtures()
      json2 = [put_in(json, ["request", "method"], "PATCH") | [json]]

      assert [
               %{
                 removed_request: %{
                   "http_version" => "HTTP/1.1",
                   "request" => %{
                     "body" => "body",
                     "headers" => [],
                     "method" => "PATCH",
                     "url" => "same_url"
                   },
                   "response" => %{
                     "body" => "body",
                     "headers" => [],
                     "status_code" => 200,
                     "status_text" => "OK"
                   }
                 }
               },
               %{}
             ] == Comparer.compare_versions(json2, [json])
    end

    test "removed request by different url on old version must return removed_request" do
      json = json_fixtures()
      json2 = [put_in(json, ["request", "url"], "different_url") | [json]]

      assert [
               %{
                 removed_request: %{
                   "http_version" => "HTTP/1.1",
                   "request" => %{
                     "body" => "body",
                     "headers" => [],
                     "method" => "GET",
                     "url" => "different_url"
                   },
                   "response" => %{
                     "body" => "body",
                     "headers" => [],
                     "status_code" => 200,
                     "status_text" => "OK"
                   }
                 }
               },
               %{}
             ] == Comparer.compare_versions(json2, [json])
    end
  end

  describe "same_request with same header" do
    test "no diff must return empty changes" do
      json = json_fixtures()
      assert [%{}] == Comparer.compare_versions([json], [json])
    end

    test "http version diff must return change" do
      json = json_fixtures()
      json2 = put_in(json, ["http_version"], "HTTP/2.0")

      assert [
               %{
                 "http_version" => %{change: %{from: "HTTP/1.1", to: "HTTP/2.0"}}
               }
             ] == Comparer.compare_versions([json], [json2])
    end

    test "request.body diff must return change" do
      json = json_fixtures()
      json2 = put_in(json, ["request", "body"], "new_version_body")

      assert [
               %{
                 "request" => %{
                   "body" => %{change: %{from: "body", to: "new_version_body"}}
                 }
               }
             ] == Comparer.compare_versions([json], [json2])
    end

    test "response.body diff must return change" do
      json = json_fixtures()
      json2 = put_in(json, ["response", "body"], "new_version_body")

      assert [
               %{
                 "response" => %{
                   "body" => %{change: %{from: "body", to: "new_version_body"}}
                 }
               }
             ] == Comparer.compare_versions([json], [json2])
    end

    test "response.status_code diff must return change" do
      json = json_fixtures()
      json2 = put_in(json, ["response", "status_code"], 403)

      assert [
               %{
                 "response" => %{
                   "status_code" => %{change: %{from: 200, to: 403}}
                 }
               }
             ] == Comparer.compare_versions([json], [json2])
    end

    test "response.status_text diff must return change" do
      json = json_fixtures()
      json2 = put_in(json, ["response", "status_text"], "Forbidden")

      assert [
               %{
                 "response" => %{
                   "status_text" => %{change: %{from: "OK", to: "Forbidden"}}
                 }
               }
             ] == Comparer.compare_versions([json], [json2])
    end
  end

  describe "req/resp added header" do
    test "added req header must return added" do
      json = json_fixtures()
      header = header_fixtures()
      json2 = json_fixtures(header)

      assert [
               %{
                 "request" => %{
                   "headers" => [
                     %{
                       added: %{
                         "name" => "Content-Type",
                         "value" => "application/json; charset=utf-8"
                       }
                     },
                     %{added: %{"name" => "Content-Length", "value" => "40"}}
                   ]
                 }
               }
             ] == Comparer.compare_versions([json], [json2])
    end

    test "added resp header must return added" do
      json = json_fixtures()
      header = header_fixtures()
      json2 = json_fixtures([], header)

      assert [
               %{
                 "response" => %{
                   "headers" => [
                     %{
                       added: %{
                         "name" => "Content-Type",
                         "value" => "application/json; charset=utf-8"
                       }
                     },
                     %{added: %{"name" => "Content-Length", "value" => "40"}}
                   ]
                 }
               }
             ] == Comparer.compare_versions([json], [json2])
    end
  end

  describe "removed req/resp header" do
    test "removed req header must return added" do
      header = header_fixtures()
      json = json_fixtures(header)
      json2 = json_fixtures()

      assert [
               %{
                 "request" => %{
                   "headers" => [
                     %{
                       removed: %{
                         "name" => "Content-Type",
                         "value" => "application/json; charset=utf-8"
                       }
                     },
                     %{removed: %{"name" => "Content-Length", "value" => "40"}}
                   ]
                 }
               }
             ] == Comparer.compare_versions([json], [json2])
    end

    test "removed resp header must return added" do
      header = header_fixtures()
      json = json_fixtures([], header)
      json2 = json_fixtures()

      assert [
               %{
                 "response" => %{
                   "headers" => [
                     %{
                       removed: %{
                         "name" => "Content-Type",
                         "value" => "application/json; charset=utf-8"
                       }
                     },
                     %{removed: %{"name" => "Content-Length", "value" => "40"}}
                   ]
                 }
               }
             ] == Comparer.compare_versions([json], [json2])
    end
  end

  describe "change_order req/resp header" do
    test "change req header order must return change order" do
      header = header_fixtures()
      json = json_fixtures(header)
      json2 = json_fixtures(Enum.reverse(header))

      assert [
               %{
                 "request" => %{
                   "headers" => [
                     %{
                       change_order: %{
                         from_index: 1,
                         header: %{
                           "name" => "Content-Type",
                           "value" => "application/json; charset=utf-8"
                         },
                         to_index: 0
                       }
                     },
                     %{
                       change_order: %{
                         from_index: 0,
                         header: %{"name" => "Content-Length", "value" => "40"},
                         to_index: 1
                       }
                     }
                   ]
                 }
               }
             ] == Comparer.compare_versions([json], [json2])
    end

    test "change resp header order must return change order" do
      header = header_fixtures()
      json = json_fixtures([], header)
      json2 = json_fixtures([], Enum.reverse(header))

      assert [
               %{
                 "response" => %{
                   "headers" => [
                     %{
                       change_order: %{
                         from_index: 1,
                         header: %{
                           "name" => "Content-Type",
                           "value" => "application/json; charset=utf-8"
                         },
                         to_index: 0
                       }
                     },
                     %{
                       change_order: %{
                         from_index: 0,
                         header: %{"name" => "Content-Length", "value" => "40"},
                         to_index: 1
                       }
                     }
                   ]
                 }
               }
             ] == Comparer.compare_versions([json], [json2])
    end
  end

  describe "change req/resp header value" do
    test "change req header value must return change value" do
      json = json_fixtures(header_fixtures())
      json2 = json_fixtures(header_fixtures("50"))

      assert [
               %{
                 "request" => %{
                   "headers" => [
                     %{"name" => "Content-Length", "value" => %{change: %{from: "40", to: "50"}}}
                   ]
                 }
               }
             ] == Comparer.compare_versions([json], [json2])
    end

    test "change resp header order must return change order" do
      header_fixtures()
      json = json_fixtures([], header_fixtures())
      json2 = json_fixtures([], header_fixtures("50"))

      assert [
               %{
                 "response" => %{
                   "headers" => [
                     %{
                       "name" => "Content-Length",
                       "value" => %{change: %{from: "40", to: "50"}}
                     }
                   ]
                 }
               }
             ] == Comparer.compare_versions([json], [json2])
    end
  end

  describe "change req/resp header order and value" do
    test "change req header order and  value must return change order and change value" do
      json = json_fixtures(header_fixtures())
      json2 = json_fixtures(Enum.reverse(header_fixtures("50")))

      assert [
               %{
                 "request" => %{
                   "headers" => [
                     %{
                       change_order: %{
                         from_index: 1,
                         header: %{
                           "name" => "Content-Type",
                           "value" => "application/json; charset=utf-8"
                         },
                         to_index: 0
                       }
                     },
                     %{
                       change_order_and_value: %{
                         :from_index => 0,
                         :to_index => 1,
                         "Content-Length" => %{change: %{from: "40", to: "50"}}
                       }
                     }
                   ]
                 }
               }
             ] == Comparer.compare_versions([json], [json2])
    end

    test "change resp header order and  value must return change order and change value" do
      json = json_fixtures([], header_fixtures())
      json2 = json_fixtures([], Enum.reverse(header_fixtures("50")))

      assert [
               %{
                 "response" => %{
                   "headers" => [
                     %{
                       change_order: %{
                         from_index: 1,
                         header: %{
                           "name" => "Content-Type",
                           "value" => "application/json; charset=utf-8"
                         },
                         to_index: 0
                       }
                     },
                     %{
                       change_order_and_value: %{
                         :from_index => 0,
                         :to_index => 1,
                         "Content-Length" => %{change: %{from: "40", to: "50"}}
                       }
                     }
                   ]
                 }
               }
             ] == Comparer.compare_versions([json], [json2])
    end
  end
end
