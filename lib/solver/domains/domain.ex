defmodule CPSolver.Domain do
  @callback dom(variable :: any()) :: list()
  @callback contains?(variable :: any(), value :: number()) :: boolean()
  @callback size(variable :: any()) :: integer()
  @callback min(variable :: any()) :: number()
  @callback max(variable :: any()) :: number()
  @callback remove(variable :: any(), value :: number()) :: any()
  @callback removeAbove(variable :: any(), value :: number()) :: any()
  @callback removeBelow(variable :: any(), value :: number()) :: any()
  @callback removeAllBut(variable :: any(), value :: number()) :: any()
  @callback fix(variable :: any(), value :: number()) :: any()
end
