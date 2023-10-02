defmodule Comparer do
  def compare_versions(json1, json2) do
    json1
    |> identify_same_request(json2)
    |> handle_distinct_request()
    |> compare_same_requests()
  end

  defp identify_same_request(old_version_requests, new_version_requests) do
    acc = %{
      not_verified_old_version_requests: old_version_requests,
      same_requests: [],
      not_verified_new_version_requests: new_version_requests,
      result: []
    }

    Enum.reduce(old_version_requests, acc, fn old_version_req, acc ->
      do_identify_same_request(old_version_req, acc)
    end)
  end

  defp do_identify_same_request(
         old_version_req,
         %{
           not_verified_old_version_requests: old_version_requests,
           same_requests: same_requests,
           not_verified_new_version_requests: new_version_requests
         } = acc
       ) do
    case Enum.find(new_version_requests, fn new_version_req ->
           same_request?(old_version_req, new_version_req)
         end) do
      nil ->
        acc

      same_new_version_req ->
        %{
          acc
          | not_verified_old_version_requests:
              mark_as_verified(old_version_requests, old_version_req),
            same_requests: [{old_version_req, same_new_version_req} | same_requests],
            not_verified_new_version_requests:
              mark_as_verified(new_version_requests, same_new_version_req)
        }
    end
  end

  defp mark_as_verified(list, item) do
    List.delete(list, item)
  end

  defp handle_distinct_request(result) do
    result
    |> insert_removed_request()
    |> insert_added_request()
  end

  defp insert_removed_request(%{not_verified_old_version_requests: []} = acc), do: acc

  defp insert_removed_request(
         %{not_verified_old_version_requests: removed_requests, result: result} = acc
       ) do
    removed_req_result = Enum.map(removed_requests, &%{removed_request: &1})

    %{acc | result: removed_req_result ++ result}
  end

  defp insert_added_request(%{not_verified_new_version_requests: []} = acc), do: acc

  defp insert_added_request(
         %{not_verified_new_version_requests: added_requests, result: result} = acc
       ) do
    added_req_result = Enum.map(added_requests, &%{added_request: &1})

    %{acc | result: added_req_result ++ result}
  end

  defp compare_same_requests(%{result: result, same_requests: same_requests}) do
    compared_same_requests_result =
      Enum.map(same_requests, fn {req, req2} ->
        json_comparer(req, req2)
      end)

    result ++ compared_same_requests_result
  end

  defp json_comparer(map1, map2, path \\ [], accumulator \\ %{}) do
    Enum.reduce(map1, accumulator, fn
      {key, value}, acc when is_map(value) ->
        map2_value = Map.get(map2, key)

        json_comparer(value, map2_value, create_map_path(path, key), acc)

      {key, value}, acc ->
        map2_value = Map.get(map2, key)

        compare(value, map2_value, create_map_path(path, key), acc)
    end)
  end

  defp same_request?(%{"request" => request}, %{"request" => request2}) do
    same_method?(request, request2) && same_endpoint?(request, request2)
  end

  defp same_method?(%{"method" => method}, %{"method" => method}), do: true
  defp same_method?(_, _), do: false

  defp same_endpoint?(%{"url" => url}, %{"url" => url2}),
    do: String.bag_distance(url, url2) >= 0.95

  defp compare(value, value2, _path, acc) when value == value2, do: acc

  defp compare(list1, list2, path, acc) when is_list(list1) do
    diffs = compare_items_in_list(list1, list2)

    add_value_to_map_path(acc, path, diffs)
  end

  defp compare(value, value2, path, acc) do
    add_value_to_map_path(acc, path, set_change(value, value2))
  end

  defp compare_items_in_list(list1, list2) do
    list1
    |> Stream.with_index()
    |> Enum.reduce([], fn tuple_map_w_index, list ->
      cond do
        same_header_same_value_same_index?(tuple_map_w_index, list2) ->
          list

        same_header_diff_value_same_index?(tuple_map_w_index, list2) ->
          diff = handle_diff_value_same_index(tuple_map_w_index, list2)

          [diff | list]

        same_header_same_value_diff_index?(tuple_map_w_index, list2) ->
          diff = handle_same_header_same_value_diff_index(tuple_map_w_index, list2)

          [diff | list]

        same_header_diff_value_diff_index?(tuple_map_w_index, list2) ->
          diff = handle_same_header_diff_value_diff_index(tuple_map_w_index, list2)

          [diff | list]

        header_removed?(tuple_map_w_index, list2) ->
          diff = handle_removed_headers(tuple_map_w_index)

          [diff | list]

        _headers_added = true ->
          list
      end
    end)
    |> handle_headers_added(list1, list2)
  end

  defp set_change(value, value2), do: %{change: %{from: value, to: value2}}

  defp same_header_same_value_same_index?({map, index}, list2), do: Enum.at(list2, index) == map

  defp handle_diff_value_same_index({%{"name" => name, "value" => value}, index}, list2) do
    map2_value = Enum.at(list2, index)["value"]

    %{"name" => name, "value" => set_change(value, map2_value)}
  end

  defp same_header_same_value_diff_index?({map, _index}, list2) do
    Enum.member?(list2, map)
  end

  defp same_header_diff_value_diff_index?({%{"name" => h}, _index}, list2) do
    Enum.any?(list2, fn %{"name" => name} -> h == name end)
  end

  defp handle_same_header_same_value_diff_index({%{"name" => name} = map, index}, list2) do
    to_index = Enum.find_index(list2, fn %{"name" => header} -> name == header end)

    %{change_order: add_from_and_to_index(%{header: map}, index, to_index)}
  end

  defp add_from_and_to_index(map, index, to_index) do
    map
    |> Map.put(:from_index, index)
    |> Map.put(:to_index, to_index)
  end

  defp handle_same_header_diff_value_diff_index(
         {%{"name" => name, "value" => value}, index},
         list2
       ) do
    to_index = Enum.find_index(list2, fn %{"name" => header} -> name == header end)
    %{"value" => value2} = Enum.at(list2, to_index)

    %{
      change_order_and_value:
        add_from_and_to_index(%{name => set_change(value, value2)}, index, to_index)
    }
  end

  defp same_header_diff_value_same_index?({%{"name" => name, "value" => _value}, index}, list2) do
    map_list2 = Enum.at(list2, index)

    map_list2["name"] == name
  end

  defp header_removed?({%{"name" => header_removed}, _index}, list2),
    do: !Enum.any?(list2, fn %{"name" => name} -> name == header_removed end)

  defp handle_removed_headers({map, _index}), do: %{removed: map}

  defp handle_headers_added(headers, list1, list2) do
    list2
    |> Stream.reject(fn x -> x["name"] in Enum.map(list1, & &1["name"]) end)
    |> Enum.reduce(headers, fn header_added, acc ->
      [%{added: header_added} | acc]
    end)
  end

  defp add_value_to_map_path(map, [key], value) do
    Map.put(map, key, value)
  end

  defp add_value_to_map_path(map, [key | rest], value) do
    submap = Map.get(map, key, %{})

    updated_submap = add_value_to_map_path(submap, rest, value)

    Map.put(map, key, updated_submap)
  end

  defp create_map_path(path, key), do: path ++ [key]
end
