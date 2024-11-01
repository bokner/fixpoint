defmodule CPSolver.Constraint.Inverse do
  @moduledoc """
  Constraints two arrays of variables `f` and `inv_f`
  to represent an inverse function.
  That is, for all i = 1..n, where n is a size of x:
     inv_f[f[i]] == i
  and:
     f[inv_f[i]] == i

  MiniZinc definition (fzn_inverse.mzn):

  forall(i in index_set(f)) (
          f[i] in index_set(invf) /\
          (invf[f[i]] == i)
      ) /\
  forall(j in index_set(invf)) (
      invf[j] in index_set(f) /\
      (f[invf[j]] == j)
  );

  Note: the current implementation assumes the index set for both `f` and `inv_f` is always 0-based
  """
  alias CPSolver.Constraint.Factory

  def new(f, inv_f) do
    new([f, inv_f])
  end

  def new([f, inv_f]) do
    Factory.inverse(f, inv_f)
  end
end
