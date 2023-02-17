defmodule SaturnPhoenix.QueriesPage do
  use Phoenix.LiveDashboard.PageBuilder

  @impl true
  def menu_link(_, _) do
    {:ok, "Saturn"}
  end

  @impl true
  def render_page(_assigns) do
    # TODO: Maybe promote `queries` to top-level?
    all_queries = Saturn.Aggregator.queries()

    table(
      columns: table_columns(),
      id: :saturn_queries,
      row_attrs: &row_attrs/1,
      row_fetcher: &fetch_queries(all_queries, &1, &2),
      rows_name: "queries",
      title: "Queries"
    )
  end

  defp fetch_queries(queries, params, _node) do
    %{search: search, sort_by: sort_by, sort_dir: sort_dir, limit: limit} = params

    results =
      queries
      |> Enum.map(fn {%Saturn.Query{query: query, stacktrace: stacktrace},
                      %Saturn.QueryStats{count: count, time: time}} ->
        %{query: query, stacktrace: stacktrace, count: count, time: time}
      end)
      |> Enum.map(fn %{stacktrace: stacktrace} = query ->
        %{
          query
          | stacktrace: Enum.map_join(stacktrace || [], "\n", &format_mfa(Tuple.delete_at(&1, 3)))
        }
      end)
      |> then(&if(search, do: apply_search(&1, search), else: &1))
      |> Enum.sort_by(&Map.get(&1, sort_by), sort_dir)
      |> Enum.take(limit)

    {results, Enum.count(queries)}
  end

  defp apply_search(queries, search) do
    Enum.filter(queries, fn %{query: query, stacktrace: stacktrace} ->
      query =~ search or stacktrace =~ search
    end)
  end

  defp table_columns() do
    [
      %{
        field: :query,
        header: "Query",
        format: &format_query/1
      },
      %{
        field: :stacktrace,
        header: "Stacktrace",
        format: &format_stacktrace/1
      },
      %{
        field: :count,
        header: "Count",
        sortable: :desc
      },
      %{
        field: :time,
        header: "Total Time (ms)",
        sortable: :desc,
        format: &format_time/1
      }
    ]
  end

  defp format_query(query) do
    assigns = %{query: query}

    ~H"""
    <code><%= @query %></code>
    """
  end

  defp format_stacktrace(stacktrace) do
    assigns = %{stacktrace: stacktrace}

    ~H"""
    <pre><code><%= @stacktrace %></code></pre>
    """
  end

  defp format_mfa({mod, fun, arity}) do
    "#{String.replace_prefix(to_string(mod), "Elixir.", "")}.#{fun}/#{arity}"
  end

  defp format_time(time) do
    System.convert_time_unit(time, :native, :millisecond)
  end

  defp row_attrs(_table) do
    []
  end
end
