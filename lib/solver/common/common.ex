defmodule CPSolver.Common do
  @type domain_change :: :fixed | :domain_change | :min_change | :max_change
  @type domain_get_operation :: :size | :fixed? | :min | :max | :contains?
  @type domain_update_operation :: :remove | :removeAbove | :removeBelow | :fix
end
