defmodule CPSolver.Constraint.Factory do
  alias CPSolver.Constraint.{Sum, Element, Element2D, Modulo}
  alias CPSolver.Propagator.Modulo, as: ModuloPropagator
  alias CPSolver.IntVariable, as: Variable
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
    {lb, ub} = ModuloPropagator.mod_bounds(x, y)
    mod_var = Variable.new(lb..ub, name: Keyword.get(opts, :name, make_ref()))
    result(mod_var, Modulo.new(mod_var, x, y))
  end

  defp result(derived_variable, constraint) do
    {derived_variable, constraint}
  end
end
