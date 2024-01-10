defmodule CPSolver.BitmapDomain do
  @spec new(Enum.t()) :: {SimpleBitmap.t(), non_neg_integer()}
  def new([]) do
    throw(:empty_domain)
  end

  def new(domain) when is_integer(domain) do
    new([domain])
  end

  def new({%SimpleBitmap{} = _bitmap, _offset} = domain) do
    domain
  end

  def new(domain) do
    offset =
      case Enum.min(domain) do
        ## shift values so the minimum is 1
        m when m < 0 -> -m + 1
        _m -> 0
      end

    {Enum.reduce(domain, SimpleBitmap.new(), fn value, acc ->
       SimpleBitmap.set(acc, value + offset)
     end), offset}
  end

  def map(domain, mapper_fun) when is_function(mapper_fun) do
    to_list(domain, mapper_fun)
  end

  def to_list({bitmap, offset} = _domain, mapper_fun \\ &Function.identity/1) do
    initial_value = SimpleBitmap.lsb(bitmap)

    Enum.reduce(initial_value..SimpleBitmap.msb(bitmap), [], fn i, acc ->
      (SimpleBitmap.set?(bitmap, i) && [mapper_fun.(i - offset) | acc]) || acc
    end)
  end

  def size({bitmap, _offset}) do
    SimpleBitmap.popcount(bitmap)
  end

  def fixed?(domain) do
    size(domain) == 1
  end

  def min({bitmap, offset}) do
    SimpleBitmap.lsb(bitmap) - offset
  end

  def max({bitmap, offset}) do
    SimpleBitmap.msb(bitmap) - offset
  end

  def contains?({bitmap, offset}, value) do
    shifted = value + offset
    shifted >= 0 && SimpleBitmap.set?(bitmap, shifted)
  end

  def remove({bitmap, offset} = domain, value) do
    shifted = value + offset

    if shifted < 0 do
      :no_change
    else
      {SimpleBitmap.unset(bitmap, shifted), offset}
      |> post_remove(domain, :domain_change)
    end
  end

  def removeAbove({bitmap, offset} = domain, value) do
    cond do
      value >= max(domain) ->
        :no_change

      value < min(domain) ->
        :fail

      true ->
        new_bitmap =
          Enum.reduce((value + 1)..max(domain), bitmap, fn val, acc ->
            SimpleBitmap.unset(acc, val + offset)
          end)

        {new_bitmap, offset}
        |> post_remove(domain, :max_change)
    end
  end

  def removeBelow({bitmap, offset} = domain, value) do
    cond do
      value <= min(domain) ->
        :no_change

      value > max(domain) ->
        :fail

      true ->
        new_bitmap =
          Enum.reduce((value - 1)..min(domain), bitmap, fn val, acc ->
            SimpleBitmap.unset(acc, val + offset)
          end)

        {new_bitmap, offset}
        |> post_remove(domain, :min_change)
    end
  end

  def fix(domain, value) do
    if contains?(domain, value) do
      {:fixed, new(value)}
    else
      :fail
    end
  end

  defp post_remove(new_domain, domain, change_kind) do
    case size(new_domain) do
      0 ->
        :fail

      new_size ->
        case size(domain) do
          old_size when old_size == new_size ->
            :no_change

          old_size when old_size > new_size ->
            {(new_size == 1 && :fixed) || maybe_bound_change(change_kind, new_domain, domain),
             new_domain}
        end
    end
  end

  defp maybe_bound_change(change_kind, new_domain, domain) do
    (min(new_domain) > min(domain) && :min_change) ||
      (max(new_domain) < max(domain) && :max_change) ||
      change_kind
  end
end
