defprotocol CPSolver.Variable.Interface do
  alias CPSolver.Variable
  alias CPSolver.Variable.View
  alias CPSolver.Common

  @spec id(Variable.t() | View.t()) :: reference()
  def id(variable)

  @spec variable(Variable.t() | View.t() | any()) :: Variable.t() | nil
  @fallback_to_any true
  def variable(arg)

  @spec bind(Variable.t() | View.t(), any()) :: Variable.t() | View.t()
  def bind(variable, store)

  @spec map(Variable.t() | View.t(), integer()) :: integer()
  def map(variable, value)

  @spec domain(Variable.t() | View.t()) :: any()
  def domain(variable)

  @spec size(Variable.t() | View.t()) :: non_neg_integer()
  def size(variable)

  @spec min(Variable.t() | View.t()) :: integer()
  def min(variable)

  @spec max(Variable.t() | View.t()) :: integer()
  def max(variable)

  @spec contains?(Variable.t() | View.t(), integer()) :: boolean()
  def contains?(variable, value)

  @spec fixed?(Variable.t() | View.t()) :: boolean()
  def fixed?(variable)

  @spec remove(Variable.t() | View.t(), integer()) :: Common.domain_change() | :no_change
  def remove(variable, value)

  @spec removeAbove(Variable.t() | View.t(), integer()) :: Common.domain_change() | :no_change
  def removeAbove(variable, value)

  @spec removeBelow(Variable.t() | View.t(), integer()) :: Common.domain_change() | :no_change
  def removeBelow(variable, value)

  @spec fix(Variable.t() | View.t(), integer()) :: :fixed | :fail
  def fix(variable, value)
end
