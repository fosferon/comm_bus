defmodule CommBus.Template.Engine do
  @moduledoc "Template engine behavior."

  alias CommBus.Template.{RenderError, RenderResult}

  @callback render(String.t(), map(), keyword()) ::
              {:ok, RenderResult.t()} | {:error, RenderError.t()}
end
