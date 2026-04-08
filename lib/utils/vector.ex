defmodule CPSolver.Utils.Vector do
  require Aja.Vector

  def new(list) when is_list(list) do
    Aja.Vector.new(list)
  end

  def size(vector) when is_struct(vector, Aja.Vector) do
    Aja.Vector.size(vector)
  end

  def at(vector, pos) when is_struct(vector, Aja.Vector) do
    Aja.Vector.at(vector, pos)
  end

  def map(vector, mapper) when is_struct(vector, Aja.Vector) and is_function(mapper, 1) do
    Aja.Vector.map(vector, mapper)
  end

  def append(vector, el) when is_struct(vector, Aja.Vector) do
    Aja.Vector.append(vector, el)
  end

  def to_list(vector) when is_struct(vector, Aja.Vector) do
    Aja.Vector.to_list(vector)
  end

end
