defmodule CPSolver.BitVectorDomain do
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

  def size({{:bit_vector, _size, ref} = bit_vector, _offset}) do
    Enum.reduce(1..last_index(bit_vector), 0, fn idx, acc ->
      n = :atomics.get(ref, idx)

      (n == 0 && acc) ||
        acc + (for(<<bit::1 <- :binary.encode_unsigned(n)>>, do: bit) |> Enum.sum())
    end)
  end

  def fixed?(domain) do
    min(domain) == max(domain)
  end

  def fail?(domain) do
    size(domain) == 0
  end

  def min({{:bit_vector, _zero_based_max, atomics_ref} = bit_vector, offset}) do
    ## Skip to a first non-zero element of atomics

    min_value =
      Enum.reduce_while(1..last_index(bit_vector), nil, fn idx, _acc ->
        case :atomics.get(atomics_ref, idx) do
          0 -> {:cont, nil}
          non_zero_block -> {:halt, (idx - 1) * 64 + lsb(non_zero_block) - offset}
        end
      end)

    (min_value && min_value) || :fail
  end

  def max({{:bit_vector, _zero_based_max, atomics_ref} = bit_vector, offset}) do
    ## Skip to a last non-zero element of atomics
    max_value =
      Enum.reduce_while(1..last_index(bit_vector) |> Enum.reverse(), nil, fn idx, _acc ->
        case :atomics.get(atomics_ref, idx) do
          0 -> {:cont, nil}
          non_zero_block -> {:halt, (idx - 1) * 64 + msb(non_zero_block) - offset}
        end
      end)

    (max_value && max_value) || :fail
  end

  def contains?({{:bit_vector, zero_based_max, _ref} = bit_vector, offset}, value) do
    vector_value = value + offset

    vector_value >= 0 && vector_value < zero_based_max &&
      :bit_vector.get(bit_vector, vector_value) == 1
  end

  def remove({bitmap, offset} = domain, value) do
    cond do
      !contains?(domain, value) ->
        :no_change

      true ->
        min? = min(domain) == value
        max? = max(domain) == value

        cond do
          ## Attempt to remove fixed value
          min? && max? ->
            :fail

          true ->
            vector_value = value + offset
            {:bit_vector.clear(bitmap, vector_value), offset}
            ## What kind of domain change happened?
            domain_change =
              cond do
                fixed?(domain) -> :fixed
                min? -> :min_change
                max? -> :max_change
                true -> :domain_change
              end

            {domain_change, domain}
        end
    end
  end

  def removeAbove({{:bit_vector, _zero_based_max, ref} = bit_vector, offset} = domain, value) do
    cond do
      value >= max(domain) ->
        :no_change

      value < min(domain) ->
        :fail

      true ->
        vector_value = value + offset
        block_index = block_index(vector_value)
        last_index = last_index(bit_vector)
        ## Clear up all blocks that follow the block the value is in
        last_index > block_index &&
          Enum.each((block_index + 1)..last_index, fn idx -> :atomics.put(ref, idx, 0) end)

        block_value = :atomics.get(ref, block_index)
        ## Find position for the value within the block
        pos = rem(vector_value, 64)
        mask = (:math.pow(2, pos + 1) - 1) |> floor()
        ## Remove all significant bits in the block above the value position
        # msb = msb(block_value)
        # shift = msb - pos
        new_value = block_value &&& mask
        :atomics.put(ref, block_index, new_value)

        domain_change =
          cond do
            fail?(domain) -> :fail
            fixed?(domain) -> :fixed
            true -> :max_change
          end

        {domain_change, domain}
    end
  end

  def removeBelow({{:bit_vector, _zero_based_max, ref} = _bit_vector, offset} = domain, value) do
    cond do
      value <= min(domain) ->
        :no_change

      value > max(domain) ->
        :fail

      true ->
        vector_value = value + offset
        block_index = block_index(vector_value)
        ## Clear up all blocks on the left of the block the value is in
        block_index > 1 &&
          Enum.each(1..(block_index - 1), fn idx -> :atomics.put(ref, idx, 0) end)

        block_value = :atomics.get(ref, block_index)
        ## Find position for the value within the block
        pos = rem(vector_value, 64)
        msb = msb(block_value)
        mask = (:math.pow(2, msb - pos + 1) - 1) |> floor() <<< pos
        ## Remove all significant bits in the block below the value position
        new_value = block_value &&& mask
        :atomics.put(ref, block_index, new_value)

        domain_change =
          cond do
            fail?(domain) -> :fail
            fixed?(domain) -> :fixed
            true -> :min_change
          end

        {domain_change, domain}
    end
  end

  def fix(domain, value) do
    if contains?(domain, value) do
      {:fixed, new(value)}
    else
      :fail
    end
  end

  ## Find the index of atomics where the n-value resides
  def block_index(n) do
    div(n, 64) + 1
  end

  def last_index({:bit_vector, _zero_based_max, ref} = _bit_vector) do
    :atomics.info(ref).size
  end

  ## Find least significant bit
  def lsb(0) do
    nil
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
    nil
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
