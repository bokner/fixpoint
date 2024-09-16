defmodule CPSolver.Constraint.Factory do
  alias CPSolver.Constraint.{
    Sum,
    ElementVar,
    Element2D,
    Modulo,
    Absolute,
    LessOrEqual,
    Equal,
    Reified
  }

  alias CPSolver.Propagator.Modulo, as: ModuloPropagator
  alias CPSolver.IntVariable, as: Variable
  alias CPSolver.BooleanVariable
  alias CPSolver.Variable.Interface
  alias CPSolver.DefaultDomain, as: Domain
  alias CPSolver.Variable.View.Factory, as: ViewFactory

  def element(array, x, opts \\ []) do
    y_domain = Enum.reduce(array,
      MapSet.new(), fn el, acc ->
        Interface.domain(el) |> Domain.to_list() |> MapSet.union(acc)
      end)
      |> MapSet.to_list()
    y = Variable.new(y_domain, name: Keyword.get(opts, :name, make_ref()))
    result(y, ElementVar.new(array, x, y))
  end

  def element2d(array2d, x, y, opts \\ []) do
    domain = array2d |> List.flatten()
    z = Variable.new(domain, name: Keyword.get(opts, :name, make_ref()))
    result(z, Element2D.new([array2d, x, y, z]))
  end

  def element2d_var(array2d, x, y, opts \\ []) do
    num_rows = length(array2d)
    num_cols = length(hd(array2d))
    Interface.removeBelow(x, 0)
    Interface.removeAbove(x, num_rows - 1)
    Interface.removeBelow(y, 0)
    Interface.removeAbove(y, num_cols - 1)

    {flat_idx_var, sum_constraint} = add(ViewFactory.mul(x, num_cols), y, domain: 0..num_rows * num_cols - 1)
    {z, element_constraint} = element(List.flatten(array2d), flat_idx_var, opts)
    {z, [sum_constraint, element_constraint]}
  end

  def sum(vars, opts \\ []) do
    domain =
      case opts[:domain] do
        nil ->
          {domain_min, domain_max} =
            Enum.reduce(vars, {0, 0}, fn var, {min_acc, max_acc} ->
              domain = Interface.domain(var) |> Domain.to_list()
              {min_acc + Enum.min(domain), max_acc + Enum.max(domain)}
            end)

          domain_min..domain_max

        d ->
          d
      end

    sum_var = Variable.new(domain, name: Keyword.get(opts, :name, make_ref()))
    result(sum_var, Sum.new(sum_var, vars))
  end

  def count(array, y, c) do
    {b_vars, reif_propagators} = for a <- array, reduce: {[], []} do
      {vars_acc, propagators_acc} ->
      b = BooleanVariable.new()
      equal_p = Reified.new([Equal.new(a, y), b])
      {[b | vars_acc], [equal_p | propagators_acc]}
    end
    Interface.removeBelow(c, 0)
    Interface.removeAbove(c, length(array))
    [Sum.new(c, b_vars) | reif_propagators]
  end

  def add(var1, var2, opts \\ []) do
    sum([var1, var2], opts)
  end

  def subtract(var1, var2, opts \\ []) do
    add(var1, ViewFactory.linear(var2, -1, 0), opts)
  end

  def mod(x, y, opts \\ []) do
    domain =
      Keyword.get(opts, :domain) ||
        (
          {lb, ub} = ModuloPropagator.mod_bounds(x, y)
          lb..ub
        )

    mod_var = Variable.new(domain, name: Keyword.get(opts, :name, make_ref()))
    result(mod_var, Modulo.new(mod_var, x, y))
  end

  def absolute(x, opts \\ []) do
    domain =
      Keyword.get(opts, :domain) ||
        (
          abs_min = abs(Interface.min(x))
          abs_max = abs(Interface.max(x))
          0..max(abs_min, abs_max)
        )

    abs_var = Variable.new(domain, name: Keyword.get(opts, :name, make_ref()))
    result(abs_var, Absolute.new(x, abs_var))
  end

  defp compose(constraint1, constraint2, relation) do
    b1 = BooleanVariable.new()
    b2 = BooleanVariable.new()
    reif_c1 = Reified.new([constraint1, b1])
    reif_c2 = Reified.new([constraint2, b2])
    %{constraints: [reif_c1, reif_c2, relation.new([b1, b2])], derived_variables: [b1, b2]}
  end

  ## Implication, equivalence, inverse implication.
  ## These function produce the list of constraints:
  ## - 2 reified constraints for constraint1 and constraint2
  ## - relational constraint (LessOrEqual for implications, Equal for equivalence)
  ## over control variables induced by reified constraints.
  ##
  def impl(constraint1, constraint2) do
    compose(constraint1, constraint2, LessOrEqual)
  end

  def equiv(constraint1, constraint2) do
    compose(constraint1, constraint2, Equal)
  end

  def inverse_impl(constraint1, constraint2) do
    impl(constraint2, constraint1)
  end

  defp result(derived_variable, constraint) do
    {derived_variable, constraint}
  end
end
