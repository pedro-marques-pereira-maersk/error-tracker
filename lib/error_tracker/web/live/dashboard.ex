defmodule ErrorTracker.Web.Live.Dashboard do
  @moduledoc false

  use ErrorTracker.Web, :live_view

  import Ecto.Query

  alias ErrorTracker.Error
  alias ErrorTracker.Occurrence
  alias ErrorTracker.Repo
  alias ErrorTracker.Web.Search

  @per_page 10

  @impl Phoenix.LiveView
  def handle_params(params, uri, socket) do
    path = struct(URI, uri |> URI.parse() |> Map.take([:path, :query]))

    {:noreply,
     socket
     |> assign(
       path: path,
       search: Search.from_params(params),
       page: 1,
       search_form: Search.to_form(params)
     )
     |> paginate_errors()}
  end

  @impl Phoenix.LiveView
  def handle_event("search", params, socket) do
    search = Search.from_params(params["search"] || %{})

    %URI{} = path = socket.assigns.path
    path_w_filters = %{path | query: URI.encode_query(search)}

    {:noreply, push_patch(socket, to: URI.to_string(path_w_filters))}
  end

  @impl Phoenix.LiveView
  def handle_event("next-page", _params, socket) do
    {:noreply, socket |> assign(page: socket.assigns.page + 1) |> paginate_errors()}
  end

  @impl Phoenix.LiveView
  def handle_event("prev-page", _params, socket) do
    {:noreply, socket |> assign(page: socket.assigns.page - 1) |> paginate_errors()}
  end

  @impl Phoenix.LiveView
  def handle_event("resolve", %{"error_id" => id}, socket) do
    error = Repo.get(Error, id)
    {:ok, _resolved} = ErrorTracker.resolve(error)

    {:noreply, paginate_errors(socket)}
  end

  @impl Phoenix.LiveView
  def handle_event("unresolve", %{"error_id" => id}, socket) do
    error = Repo.get(Error, id)
    {:ok, _unresolved} = ErrorTracker.unresolve(error)

    {:noreply, paginate_errors(socket)}
  end

  @impl Phoenix.LiveView
  def handle_event("mute", %{"error_id" => id}, socket) do
    error = Repo.get(Error, id)
    {:ok, _muted} = ErrorTracker.mute(error)

    {:noreply, paginate_errors(socket)}
  end

  @impl Phoenix.LiveView
  def handle_event("unmute", %{"error_id" => id}, socket) do
    error = Repo.get(Error, id)
    {:ok, _unmuted} = ErrorTracker.unmute(error)

    {:noreply, paginate_errors(socket)}
  end

  defp paginate_errors(socket) do
    %{page: page, search: search} = socket.assigns
    offset = (page - 1) * @per_page
    query = filter(Error, search)

    total_errors = Repo.aggregate(query, :count)

    errors =
      Repo.all(
        from query,
          order_by: [desc: :last_occurrence_at],
          offset: ^offset,
          limit: @per_page
      )

    error_ids = Enum.map(errors, & &1.id)

    occurrences =
      if errors == [] do
        []
      else
        errors
        |> Ecto.assoc(:occurrences)
        |> where([o], o.error_id in ^error_ids)
        |> group_by([o], o.error_id)
        |> select([o], {o.error_id, count(o.id)})
        |> Repo.all()
      end

    assign(socket,
      errors: errors,
      occurrences: Map.new(occurrences),
      total_pages: (total_errors / @per_page) |> Float.ceil() |> trunc()
    )
  end

  defp filter(query, search) do
    search
    |> Map.drop([:context_field, :context_value])
    |> Enum.reduce(query, &do_filter/2)
    |> then(&do_filter_context(search, &1))
  end

  defp do_filter({:status, status}, query) do
    where(query, [error], error.status == ^status)
  end

  defp do_filter({field, value}, query) do
    # Postgres provides the ILIKE operator which produces a case-insensitive match between two
    # strings. SQLite3 only supports LIKE, which is case-insensitive for ASCII characters.
    Repo.with_adapter(fn
      :postgres -> where(query, [error], ilike(field(error, ^field), ^"%#{value}%"))
      :mysql -> where(query, [error], like(field(error, ^field), ^"%#{value}%"))
      :sqlite -> where(query, [error], like(field(error, ^field), ^"%#{value}%"))
    end)
  end

  defp do_filter_context(%{context_field: context_field, context_value: context_value}, query)
       when context_field not in [nil, ""] and context_value not in [nil, ""] do
    latest_occurrence_ids =
      from o in Occurrence,
        group_by: o.error_id,
        select: %{error_id: o.error_id, latest_id: max(o.id)}

    query =
      query
      |> join(:inner, [e], lo in subquery(latest_occurrence_ids), on: lo.error_id == e.id)
      |> join(:inner, [_e, lo], o in Occurrence, on: o.id == lo.latest_id)

    pattern = "%" <> context_value <> "%"

    Repo.with_adapter(fn
      :postgres ->
        where(
          query,
          [_, _, o],
          fragment("COALESCE(?->>?, '') ILIKE ?", o.context, ^context_field, ^pattern)
        )

      :mysql ->
        where(
          query,
          [_, _, o],
          fragment(
            "LOWER(COALESCE(JSON_UNQUOTE(JSON_EXTRACT(?, CONCAT('$.', ?))), '')) LIKE LOWER(?)",
            o.context,
            ^context_field,
            ^pattern
          )
        )

      :sqlite ->
        where(
          query,
          [_, _, o],
          fragment(
            "LOWER(COALESCE(json_extract(?, '$.' || ?), '')) LIKE LOWER(?)",
            o.context,
            ^context_field,
            ^pattern
          )
        )
    end)
  end

  defp do_filter_context(_, query), do: query
end
