defmodule CPSolver.Constraint.Factory do
  alias CPSolver.Constraint.{Sum, Element, Element2D, Modulo, Absolute, LessOrEqual, Equal, Reified}
  alias CPSolver.Propagator.Modulo, as: ModuloPropagator
  alias CPSolver.IntVariable, as: Variable
  alias CPSolver.BooleanVariable
  alias CPSolver.Variable.Interface
  alias CPSolver.DefaultDomain, as: Domain
  import CPSolver.Variable.View.Factory

  def element(array, x, opts \\ []) do
    domain = array
    y = Variable.new(domain, name: Keyword.get(opts, :name, make_ref()))
    result(y, Element.new(array, x, y))
  end

  def element2d(array2d, x, y, opts \\ []) do
    domain = array2d |> List.flatten()
    z = Variable.new(domain, name: Keyword.get(opts, :name, make_ref()))
    result(z, Element2D.new([array2d, x, y, z]))
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

  def add(var1, var2, opts \\ []) do
    sum([var1, var2], opts)
  end

  def subtract(var1, var2, opts \\ []) do
    add(var1, linear(var2, -1, 0), opts)
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
    [reif_c1, reif_c2, relation.new([b1, b2])]
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
