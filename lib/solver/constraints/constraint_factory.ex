defmodule CPSolver.Constraint.Factory do
  alias CPSolver.Constraint.{
    Sum,
    ElementVar,
    Element2D,
    Maximum,
    Minimum,
    Modulo,
    Absolute,
    LessOrEqual,
    Equal,
    Reified,
    AllDifferent
  }

  alias CPSolver.Propagator.Modulo, as: ModuloPropagator
  alias CPSolver.IntVariable, as: Variable
  alias CPSolver.BooleanVariable
  alias CPSolver.Variable.Interface
  import CPSolver.Variable.View.Factory
  import CPSolver.Utils

  def element(array, x, y) do
    ElementVar.new(array, x, y)
  end

  def element(array, x) do
    y_domain =
      Enum.reduce(array, MapSet.new(), fn el, acc ->
        domain_values(el) |> MapSet.union(acc)
      end)
      |> MapSet.to_list()

    y = Variable.new(y_domain)
    result(y, element(array, x, y))
  end

  def element2d(array2d, x, y) do
    domain = array2d |> List.flatten()
    z = Variable.new(domain)
    result(z, element2d(array2d, x, y, z))
  end

  def element2d(array2d, x, y, z) do
    Element2D.new([array2d, x, y, z])
  end

  def element2d_var(array2d, x, y, z) do
    num_rows = length(array2d)
    num_cols = length(hd(array2d))
    Interface.removeBelow(x, 0)
    Interface.removeAbove(x, num_rows - 1)
    Interface.removeBelow(y, 0)
    Interface.removeAbove(y, num_cols - 1)

    {flat_idx_var, sum_constraint} = add(mul(x, num_cols), y)
    Interface.removeBelow(flat_idx_var, 0)
    Interface.removeAbove(flat_idx_var, num_rows * num_cols - 1)
    element_constraint = element(List.flatten(array2d), flat_idx_var, z)
    [sum_constraint, element_constraint]
  end

  def element2d_var(array2d, x, y) do
    domain =
      Enum.reduce(array2d |> List.flatten(), MapSet.new(), fn el, acc ->
        domain_values(el)
        |> MapSet.union(acc)
      end)
      |> MapSet.to_list()

    z = Variable.new(domain)
    result(z, element2d_var(array2d, x, y, z))
  end

  def equal(x, y) do
    Equal.new(x, y)
  end

  def maximum(vars, max_var) do
    Maximum.new(max_var, vars)
  end

  def maximum(vars) do
    domain = Enum.reduce(vars, MapSet.new(), fn var, acc ->
      MapSet.union(acc, domain_values(var))
    end)

    max_var = Variable.new(domain)
    result(max_var, Maximum.new(max_var, vars))
  end

  def minimum(vars, min_var) do
    Minimum.new(min_var, vars)
  end

  def minimum(vars) do
    domain = Enum.reduce(vars, MapSet.new(), fn var, acc ->
      MapSet.union(acc, domain_values(var))
    end)

    min_var = Variable.new(domain)
    result(min_var, Minimum.new(min_var, vars))
  end


  def sum(vars, sum_var) do
    Sum.new(sum_var, vars)
  end

  def sum(vars) do
    {domain_min, domain_max} =
      Enum.reduce(vars, {0, 0}, fn var, {min_acc, max_acc} ->
        domain = domain_values(var)
        {min_acc + Enum.min(domain), max_acc + Enum.max(domain)}
      end)

    domain = domain_min..domain_max

    sum_var = Variable.new(domain)
    result(sum_var, Sum.new(sum_var, vars))
  end

  def count(array, y, c) do
    {b_vars, reif_constraints} =
      for a <- array, reduce: {[], []} do
        {vars_acc, constraints_acc} ->
          b = BooleanVariable.new()
          equal_p = Reified.new([Equal.new(a, y), b])
          {[b | vars_acc], [equal_p | constraints_acc]}
      end

    Interface.removeBelow(c, 0)
    Interface.removeAbove(c, length(array))
    [Sum.new(c, b_vars) | reif_constraints]
  end

  def inverse(f, inv_f) do
    length(f) == length(inv_f) ||
      throw("Inverse constraint has to have sizes of arguments match")

    index_set = MapSet.new(0..(length(f) - 1))

    for i <- index_set do
      f_i = Enum.at(f, i)
      inv_f_i = Enum.at(inv_f, i)

      (MapSet.subset?(domain_values(f_i), index_set) &&
         MapSet.subset?(domain_values(inv_f_i), index_set)) ||
        throw("Inverse constraint has to have all variable domains within index_set")

      [
        element(f, inv_f_i, i),
        element(inv_f, f_i, i)
      ]
    end
    |> List.flatten()
    |> Enum.concat([AllDifferent.DC.new(f), AllDifferent.DC.new(inv_f)])
  end

  def add(var1, var2) do
    sum([var1, var2])
  end

  def subtract(var1, var2) do
    add(var1, linear(var2, -1, 0))
  end

  def mod(x, y) do
    {lb, ub} = ModuloPropagator.mod_bounds(x, y)

    domain =
      lb..ub

    mod_var = Variable.new(domain)
    result(mod_var, Modulo.new(mod_var, x, y))
  end

  def mod(mod_var, x, y) do
    Modulo.new(mod_var, x, y)
  end

  def absolute(x) do
    abs_min = abs(Interface.min(x))
    abs_max = abs(Interface.max(x))
    domain = 0..max(abs_min, abs_max)

    abs_var = Variable.new(domain)
    result(abs_var, Absolute.new(x, abs_var))
  end

  def absolute(x, abs_var) do
    Absolute.new(x, abs_var)
  end

  def alldifferent(vars) do
    AllDifferent.new(vars)
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
