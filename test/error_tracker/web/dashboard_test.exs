defmodule ErrorTracker.Web.DashboardTest do
  use ErrorTracker.Test.ConnCase, async: true

  test "filters errors by team", %{conn: conn} do
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

    {:ok, view, _html} = live(conn, "/dashboard?team=awesome")

    assert has_element?(view, ~s/[name="search[team]"][value="awesome"]/)

    assert has_element?(view, "tr", "(RuntimeError) Whoops!")

    refute has_element?(view, "tr", "(ArgumentError) Oh No! Not another one!")
  end

  def repo do
    Application.fetch_env!(:error_tracker, :repo)
  end
end
