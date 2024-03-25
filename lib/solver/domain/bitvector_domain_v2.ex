defmodule CPSolver.BitVectorDomain.V2 do
  import Bitwise

  @max_value (1 <<< 64) - 1

  def new([]) do
    fail()
  end

  def new(value) when is_integer(value) do
    new([value])
  end

  def new(domain) when is_integer(domain) do
    new([domain])
  end

  def new({{:bit_vector, _size, _ref} = _bitmap, _offset} = domain) do
    domain
  end

  def new(domain) do
    offset = -Enum.min(domain)
    domain_size = Enum.max(domain) + offset + 1
    bv = :bit_vector.new(domain_size)
    Enum.each(domain, fn idx -> :bit_vector.set(bv, idx + offset) end)

    PackedMinMax.set_min(0, 0)
    |> PackedMinMax.set_max(Enum.max(domain) + offset)
    |> then(fn min_max -> init_min_max(bv, min_max) end)

    {bv, offset}
  end

  def map(domain, mapper_fun) when is_function(mapper_fun) do
    to_list(domain, mapper_fun)
  end

  def to_list(domain, mapper_fun \\ &Function.identity/1) do
    Enum.reduce(min(domain)..max(domain), [], fn i, acc ->
      (contains?(domain, i) && [mapper_fun.(i) | acc]) || acc
    end)
  end

  def fixed?(domain) do
    min(domain) == max(domain)
  end

  def failed?({bit_vector, _offset} = _domain) do
    failed?(bit_vector)
  end

  def failed?(bit_vector) do
    get_min(bit_vector) > get_max(bit_vector)
  end

  def min({bit_vector, offset} = _domain) do
    get_min(bit_vector) - offset
  end

  def max({bit_vector, offset} = _domain) do
    get_max(bit_vector) - offset
  end

  def size({{:bit_vector, _size, ref} = bit_vector, _offset}) do
    %{
      min_addr: %{block: current_min_block},
      max_addr: %{block: current_max_block}
    } = get_bound_addrs(bit_vector)

    Enum.reduce(current_min_block..current_max_block, 0, fn idx, acc ->
      n = :atomics.get(ref, idx)

      (n == 0 && acc) ||
        acc + (for(<<bit::1 <- :binary.encode_unsigned(n)>>, do: bit) |> Enum.sum())
    end)
  end

  def contains?({{:bit_vector, _zero_based_max, _ref} = bit_vector, offset}, value) do
    vector_value = value + offset

    vector_value >= get_min(bit_vector) && vector_value <= get_max(bit_vector) &&
      :bit_vector.get(bit_vector, vector_value) == 1
  end

  def fix({bit_vector, offset} = domain, value) do
    if contains?(domain, value) do
      update_min(bit_vector, value + offset)
      update_max(bit_vector, value + offset)
      ## TODO: do we need it?
      {:fixed, domain}
    else
      fail(bit_vector)
    end
  end

  def remove({bit_vector, offset} = domain, value) do
    cond do
      ## No value in the domain, do nothing
      !contains?(domain, value) ->
        :no_change

      ## The domain is fixed
      fixed?(domain) ->
        ## Fail on attempt to remove fixed value, otherwise do nothing
        (min(domain) == value && fail(bit_vector)) || :no_change

      true ->
        ## Value is there, and it's safe to remove
        domain_change =
          cond do
            min(domain) == value ->
              tighten_min(bit_vector)
              (fixed?(domain) && :fixed) || :min_change

            max(domain) == value ->
              tighten_max(bit_vector)
              (fixed?(domain) && :fixed) || :max_change

            true ->
              vector_value = value + offset
              :bit_vector.clear(bit_vector, vector_value)
              :domain_change
          end

        {domain_change, domain}
    end
  end

  def removeAbove({bit_vector, offset} = domain, value) do
    cond do
      value >= max(domain) ->
        :no_change

      value < min(domain) ->
        fail(bit_vector)

      true ->
        ## The value is strictly less than max
        tighten_max(bit_vector, value + offset + 1)

        domain_change =
          cond do
            fixed?(domain) -> :fixed
            true -> :max_change
          end

        {domain_change, domain}
    end
  end

  def removeBelow({bit_vector, offset} = domain, value) do
    cond do
      value <= min(domain) ->
        :no_change

      value > max(domain) ->
        fail(bit_vector)

      true ->
        ## The value is strictly greater than min
        tighten_min(bit_vector, value + offset - 1)

        domain_change =
          (fixed?(domain) && :fixed) || :min_change

        {domain_change, domain}
    end
  end

  ## Last 2 bytes of bit_vector are min and max
  def last_index({:bit_vector, _zero_based_max, ref} = _bit_vector) do
    :atomics.info(ref).size - 2
  end

  defp init_min_max({:bit_vector, _, ref} = bit_vector, min_max) do
    bit_vector
    |> min_max_index()
    |> then(fn idx -> :atomics.put(ref, idx, min_max) end)
  end

  def get_min(bit_vector) do
    get_min_max(bit_vector) |> elem(2)
  end

  def get_max(bit_vector) do
    get_min_max(bit_vector) |> elem(3)
  end

  defp min_max_index(bit_vector) do
    last_index(bit_vector) + 1
  end

  def get_min_max({:bit_vector, _zero_based_max, ref} = bit_vector) do
    min_max_index = min_max_index(bit_vector)

    :atomics.get(ref, min_max_index)
    |> then(fn min_max ->
      {min_max, min_max_index, PackedMinMax.get_min(min_max), PackedMinMax.get_max(min_max)}
    end)
  end

  def set_min({:bit_vector, _zero_based_max, ref} = bit_vector, value) do
    {current_min_max, min_max_idx, current_min, current_max} = get_min_max(bit_vector)

    cond do
      value > current_max ->
        fail(bit_vector)

      value == current_max ->
        :fixed

      value > current_min ->
        :min_change

      value == current_min ->
        :no_change
    end
    |> tap(fn _ ->
      min_max_value = PackedMinMax.set_min(current_min_max, value)

      case :atomics.compare_exchange(ref, min_max_idx, current_min_max, min_max_value) do
        :ok ->
          :ok

        _concurrently_changed ->
          set_min(bit_vector, value)
      end
    end)
  end

  def set_max({:bit_vector, _zero_based_max, ref} = bit_vector, value) do
    {current_min_max, min_max_idx, current_min, current_max} = get_min_max(bit_vector)

    cond do
      value < current_min ->
        fail(bit_vector)

      value == current_min ->
        :fixed

      value < current_max ->
        :max_change

      value == current_max ->
        :no_change
    end
    |> tap(fn _ ->
      min_max_value = PackedMinMax.set_max(current_min_max, value)

      case :atomics.compare_exchange(ref, min_max_idx, current_min_max, min_max_value) do
        :ok ->
          :ok

        _concurrently_changed ->
          set_max(bit_vector, value)
      end
    end)
  end

  defp update_min(bit_vector, new_min_value) do
    cond do
      new_min_value > get_max(bit_vector) ->
        fail(bit_vector)

      get_min(bit_vector) >= new_min_value ->
        :no_change

      true ->
        set_min(bit_vector, new_min_value)
        :min_change
    end
  end

  defp update_max(bit_vector, new_max_value) do
    cond do
      new_max_value < get_min(bit_vector) ->
        fail(bit_vector)

      get_max(bit_vector) <= new_max_value ->
        :no_change

      true ->
        set_max(bit_vector, new_max_value)
        :max_change
    end
  end

  ## Update (cached) min, if necessary
  defp tighten_min({:bit_vector, _zero_based_max, atomics_ref} = bit_vector, starting_at \\ nil) do
    starting_position = (starting_at && starting_at) || get_min(bit_vector)

    %{
      max_addr: %{block: current_max_block}
    } = get_bound_addrs(bit_vector)

    {rightmost_block, position_in_block} = vector_address(starting_position + 1)
    ## Find a new min (on the right of the current one)
    min_value =
      Enum.reduce_while(rightmost_block..current_max_block, nil, fn idx, _acc ->
        case :atomics.get(atomics_ref, idx) do
          0 ->
            {:cont, nil}

          non_zero_block ->
            ## Because the position in the block is 0-based
            shift = position_in_block
            {:halt, (idx - 1) * 64 + lsb(non_zero_block >>> shift <<< shift)}
        end
      end)

    (min_value && update_min(bit_vector, min_value)) || :fail
  end

  ## Update (cached) max
  defp tighten_max({:bit_vector, _zero_based_max, atomics_ref} = bit_vector, starting_at \\ nil) do
    starting_position = (starting_at && starting_at) || get_max(bit_vector)

    %{
      min_addr: %{block: current_min_block}
    } = get_bound_addrs(bit_vector)

    {leftmost_block, position_in_block} = vector_address(starting_position - 1)
    ## Find a new max (on the left of the current one)
    max_value =
      Enum.reduce_while(current_min_block..leftmost_block |> Enum.reverse(), nil, fn idx, _acc ->
        case :atomics.get(atomics_ref, idx) do
          0 ->
            {:cont, nil}

          non_zero_block ->
            ## Reset all bits above the position
            mask = (1 <<< (position_in_block + 1)) - 1
            {:halt, (idx - 1) * 64 + msb(non_zero_block &&& mask)}
        end
      end)

    (max_value && update_max(bit_vector, max_value)) || :fail
  end

  defp fail(_bit_vector \\ nil) do
    throw(:fail)
  end

  defp get_bound_addrs(bit_vector) do
    (failed?(bit_vector) && fail(bit_vector)) ||
      (
        current_min = get_min(bit_vector)
        current_max = get_max(bit_vector)
        {current_min_block, current_min_offset} = vector_address(current_min)
        {current_max_block, current_max_offset} = vector_address(current_max)

        %{
          min_addr: %{block: current_min_block, offset: current_min_offset},
          max_addr: %{block: current_max_block, offset: current_max_offset}
        }
      )
  end

  ## Find the index of atomics where the n-value resides
  defp block_index(n) do
    div(n, 64) + 1
  end

  defp vector_address(n) do
    {block_index(n), rem(n, 64)}
  end

  ## Find least significant bit
  defp lsb(0) do
    0
  end

  defp lsb(n) do
    lsb(n, 0)
  end

  defp lsb(1, idx) do
    idx
  end

  defp lsb(n, idx) do
    ((n &&& 1) == 1 && idx) ||
      lsb(n >>> 1, idx + 1)
  end

  defp msb(0) do
    0
  end

  defp msb(n) do
    msb = floor(:math.log2(n))
    ## Check if there is no precision loss.
    ## We really want to throw away the fraction part even if it may
    ## get very close to 1.
    if floor(:math.pow(2, msb)) > n do
      msb - 1
    else
      msb
    end
  end
end
