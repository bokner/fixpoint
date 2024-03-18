defmodule CPSolver.BitVectorDomain.V2 do
  import Bitwise

  def new([]) do
    throw(:empty_domain)
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

    set_min(bv, 0)
    set_max(bv, Enum.max(domain) + offset)

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
      :fail
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
        (min(domain) == value && :fail) || :no_change

      true ->
        ## Value is there, and it's safe to remove      
        domain_change =
          cond do
            min(domain) == value ->
              if tighten_min(bit_vector) == :fail do
                :fail
              else
                (fixed?(domain) && :fixed) || :min_change
              end

            max(domain) == value ->
              if tighten_max(bit_vector) == :fail do
                :fail
              else
                (fixed?(domain) && :fixed) || :max_change
              end

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
        :fail

      true ->
        ## The value is strictly less than max  

        domain_change =
          cond do
            tighten_max(bit_vector, value + offset + 1) == :fail -> :fail
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
        :fail

      true ->
        ## The value is strictly greater than min
        domain_change =
          cond do
            tighten_min(bit_vector, value + offset - 1) == :fail -> :fail
            fixed?(domain) -> :fixed
            true -> :min_change
          end

        {domain_change, domain}
    end
  end

  ## Last 2 bytes of bit_vector are min and max
  def last_index({:bit_vector, _zero_based_max, ref} = _bit_vector) do
    :atomics.info(ref).size - 2
  end

  defp get_min({:bit_vector, _zero_based_max, ref} = bit_vector) do
    :atomics.get(ref, last_index(bit_vector) + 1)
  end

  defp set_min({:bit_vector, _zero_based_max, ref} = bit_vector, value) do
    min_idx = last_index(bit_vector) + 1
    # :atomics.put(ref, min_idx, value)
    case :atomics.exchange(ref, min_idx, value) do
      prev_value when prev_value > value ->
        ## Do not update if current min is greater than the proposed min value
        set_min(bit_vector, prev_value)

      prev_value ->
        (prev_value == value && :no_change) || :min_change
    end
  end

  defp update_min(bit_vector, new_min_value) do
    cond do
      new_min_value > get_max(bit_vector) ->
        :fail

      get_min(bit_vector) >= new_min_value ->
        :no_change

      true ->
        set_min(bit_vector, new_min_value)
        :min_change
    end
  end

  defp get_max({:bit_vector, _zero_based_max, ref} = bit_vector) do
    :atomics.get(ref, last_index(bit_vector) + 2)
  end

  defp set_max({:bit_vector, _zero_based_max, ref} = bit_vector, value) do
    max_idx = last_index(bit_vector) + 2
    # :atomics.put(ref, last_index(bit_vector) + 2, value)
    case :atomics.exchange(ref, max_idx, value) do
      prev_value when prev_value < value ->
        ## Do not update if current max is lesser than the proposed max value
        set_max(bit_vector, prev_value)

      prev_value ->
        (prev_value == value && :no_change) || :max_change
    end

    # :atomics.put(ref, last_index(bit_vector) + 2, value)
  end

  defp update_max(bit_vector, new_max_value) do
    cond do
      new_max_value < get_min(bit_vector) ->
        :fail

      get_max(bit_vector) <= new_max_value ->
        :no_change

      true ->
        set_max(bit_vector, new_max_value)
        :max_change
    end

    # :atomics.put(ref, last_index(bit_vector) + 2, new_max_value)
  end

  ## Update (cached) min, if necessary
  def tighten_min({:bit_vector, _zero_based_max, atomics_ref} = bit_vector, starting_at \\ nil) do
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

  def get_bound_addrs(bit_vector) do
    current_min = get_min(bit_vector)
    current_max = get_max(bit_vector)
    {current_min_block, current_min_offset} = vector_address(current_min)
    {current_max_block, current_max_offset} = vector_address(current_max)

    %{
      min_addr: %{block: current_min_block, offset: current_min_offset},
      max_addr: %{block: current_max_block, offset: current_max_offset}
    }
  end

  ## Find the index of atomics where the n-value resides
  def block_index(n) do
    div(n, 64) + 1
  end

  def vector_address(n) do
    {block_index(n), rem(n, 64)}
  end

  ## Find least significant bit
  def lsb(0) do
    0
  end

  def lsb(n) do
    lsb(n, 0)
  end

  defp lsb(1, idx) do
    idx
  end

  defp lsb(n, idx) do
    ((n &&& 1) == 1 && idx) ||
      lsb(n >>> 1, idx + 1)
  end

  def msb(0) do
    0
  end

  def msb(n) do
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
