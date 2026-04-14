defmodule ErrorTracker.Web.DashboardTest do
  use ErrorTracker.Test.ConnCase, async: true

  test "filters errors by context field", %{conn: conn} do
    try do
      raise RuntimeError, "Whoops!"
    rescue
      e -> ErrorTracker.report(e, [], %{team: :awesome})
    end

    try do
      raise ArgumentError, "Oh No! Not another one!"
    rescue
      e -> ErrorTracker.report(e, [], %{team: :ghost})
    end

    assert ErrorTracker.Error |> repo().all() |> length() == 2

    {:ok, view, _html} = live(conn, "/dashboard?context_field=team&context_value=awesome")

    assert has_element?(view, ~s/[name="search[context_field]"][value="team"]/)
    assert has_element?(view, ~s/[name="search[context_value]"][value="awesome"]/)

    assert has_element?(view, "tr", "(RuntimeError) Whoops!")

    refute has_element?(view, "tr", "(ArgumentError) Oh No! Not another one!")
  end

  def repo do
    Application.fetch_env!(:error_tracker, :repo)
  end
end
