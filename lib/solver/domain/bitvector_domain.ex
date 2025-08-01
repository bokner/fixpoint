defmodule CPSolver.BitVectorDomain do
  import Bitwise

  @failure_value (1 <<< 64) - 1

  def new([]) do
    fail()
  end

  def new(domain) when is_integer(domain) do
    new([domain])
  end

  def new(domain) when is_list(domain) or is_struct(domain, Range) or is_struct(domain, MapSet) do
    offset = -Enum.min(domain)
    domain_size = Enum.max(domain) + offset + 1
    bv = :bit_vector.new(domain_size)
    Enum.each(domain, fn idx -> :bit_vector.set(bv, idx + offset) end)

    PackedMinMax.set_min(0, 0)
    |> PackedMinMax.set_max(Enum.max(domain) + offset)
    |> then(fn min_max -> set_min_max(bv, min_max) end)

    {bv, offset}
  end

  def copy({{:bit_vector, ref} = bit_vector, offset} = _domain) do
    %{
      min_addr: %{block: current_min_block},
      max_addr: %{block: current_max_block}
    } = get_bound_addrs(bit_vector)

    new_atomics_size = current_max_block + 1
    new_atomics_ref = :atomics.new(new_atomics_size, [{:signed, false}])

    Enum.each(
      current_min_block..current_max_block,
      fn block_idx ->
        block_val = :atomics.get(ref, block_idx)
        :atomics.put(new_atomics_ref, block_idx, block_val)
      end
    )

    new_bit_vector = {:bit_vector, new_atomics_ref}
    set_min_max(new_bit_vector, get_min_max_impl(bit_vector) |> elem(1))
    {new_bit_vector, offset}
  end

  def map(domain, mapper_fun) when is_function(mapper_fun) do
    to_list(domain, mapper_fun)
  end

  ## Reduce over domain values
  def reduce(
        {{:bit_vector, ref} = bit_vector, offset} = domain,
        value_mapper_fun,
        acc_init \\ MapSet.new(),
        reduce_fun \\ &MapSet.union/2
      ) do
    %{
      min_addr: %{block: current_min_block, offset: _min_offset},
      max_addr: %{block: current_max_block, offset: _max_offset}
    } = get_bound_addrs(bit_vector)

    mapped_lb = value_mapper_fun.(min(domain))
    mapped_ub = value_mapper_fun.(max(domain))

    {lb, ub} = (mapped_lb <= mapped_ub && {mapped_lb, mapped_ub}) || {mapped_ub, mapped_lb}

    Enum.reduce(current_min_block..current_max_block, acc_init, fn block_idx, acc ->
      block = :atomics.get(ref, block_idx)

      if block == 0 do
        acc
      else
        reduce_fun.(
          acc,
          bit_positions(block, fn val ->
            case value_mapper_fun.(val + 64 * (block_idx - 1) - offset) do
              value when value >= lb and value <= ub ->
                value

              _out_of_bounds ->
                nil
            end
          end)
        )
      end
    end)
  end

  def to_list(
        domain,
        value_mapper_fun \\ &Function.identity/1
      ) do
    (fixed?(domain) && MapSet.new([value_mapper_fun.(min(domain))])) ||
      reduce(domain, value_mapper_fun, MapSet.new(), &MapSet.union/2)
  end

  def fixed?({bit_vector, _offset} = _domain) do
    {current_min_max, _min_max_idx, current_min, current_max} = get_min_max(bit_vector)
    current_max == current_min && current_min_max != @failure_value
  end

  def failed?({:bit_vector, _ref} = bit_vector) do
    failed?(elem(get_min_max_impl(bit_vector), 1))
  end

  def failed?({bit_vector, _offset} = _domain) do
    failed?(bit_vector)
  end

  def failed?(min_max_value) when is_integer(min_max_value) do
    min_max_value == @failure_value
  end

  def min({bit_vector, offset} = _domain) do
    get_min(bit_vector) - offset
  end

  def max({bit_vector, offset} = _domain) do
    get_max(bit_vector) - offset
  end

  def size({{:bit_vector, ref} = bit_vector, _offset}) do
    %{
      min_addr: %{block: current_min_block, offset: min_offset},
      max_addr: %{block: current_max_block, offset: max_offset}
    } = get_bound_addrs(bit_vector)

    Enum.reduce(current_min_block..current_max_block, 0, fn idx, acc ->
      n = :atomics.get(ref, idx)

      if n == 0 do
        acc
      else
        n1 = (idx == current_min_block && n >>> min_offset) || n
        n2 = (idx == current_max_block && ((1 <<< (max_offset + 1)) - 1 &&& n1)) || n1
        acc + bit_count(n2)
      end
    end)
  end

  def contains?({{:bit_vector, _ref} = bit_vector, offset}, value) do
    {_current_min_max, _min_max_idx, min_value, max_value} = get_min_max(bit_vector)
    vector_value = value + offset
    contains?(bit_vector, vector_value, min_value, max_value)
  end

  def contains?(bit_vector, vector_value, min_value, max_value) do
    vector_value >= min_value && vector_value <= max_value &&
      :bit_vector.get(bit_vector, vector_value) == 1
  end

  def fix({bit_vector, offset} = _domain, value) do
    min_max_info =
      {_current_min_max, _min_max_idx, min_value, max_value} = get_min_max(bit_vector)

    vector_value = value + offset

    if contains?(bit_vector, vector_value, min_value, max_value) do
      set_fixed(bit_vector, value + offset, min_max_info)
    else
      fail(bit_vector)
    end
  end

  def remove({bit_vector, offset} = domain, value) do
    {_current_min_max, _min_max_idx, min_value, max_value} = get_min_max(bit_vector)
    vector_value = value + offset

    cond do
      ## No value in the domain, do nothing
      contains?(bit_vector, vector_value, min_value, max_value) ->
        domain_change =
          cond do
            min_value == max_value && vector_value == min_value ->
              ## Fixed value: fail on removing attempt
              fail(bit_vector)

            min_value == vector_value ->
              tighten_min(bit_vector, min_value, max_value)

            max_value == vector_value ->
              tighten_max(bit_vector, max_value, min_value)

            true ->
              :domain_change
          end

        {domain_change, domain}
        |> tap(fn _ -> :bit_vector.clear(bit_vector, vector_value) end)

      true ->
        :no_change
    end
  end

  def removeAbove({bit_vector, offset} = domain, value) do
    {_current_min_max, _min_max_idx, min_value, max_value} = get_min_max(bit_vector)
    vector_value = value + offset

    cond do
      vector_value >= max_value ->
        :no_change

      vector_value < min_value ->
        fail(bit_vector)

      true ->
        ## The value is strictly less than max
        domain_change = tighten_max(bit_vector, vector_value + 1, min_value)

        {domain_change, domain}
    end
  end

  def removeBelow({bit_vector, offset} = domain, value) do
    {_current_min_max, _min_max_idx, min_value, max_value} = get_min_max(bit_vector)
    vector_value = value + offset

    cond do
      vector_value <= min_value ->
        :no_change

      vector_value > max_value ->
        fail(bit_vector)

      true ->
        ## The value is strictly greater than min
        domain_change = tighten_min(bit_vector, vector_value - 1, max_value)

        {domain_change, domain}
    end
  end

  def raw({{:bit_vector, ref} = _bit_vector, offset} = _domain) do
    %{
      offset: offset,
      content: Enum.map(1..:atomics.info(ref).size, fn i -> :atomics.get(ref, i) end)
    }
  end

  ## Last byte of bit_vector contains (packed) min and max
  def last_index({:bit_vector, ref} = _bit_vector) do
    :atomics.info(ref).size - 1
  end

  defp set_min_max({:bit_vector, ref} = bit_vector, min_max) do
    bit_vector
    |> min_max_index()
    |> tap(fn idx ->
      :atomics.put(ref, idx, min_max)
    end)
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

  def get_min_max(bit_vector) do
    get_min_max_impl(bit_vector)
    |> then(fn {min_max_index, min_max} ->
      min_max == @failure_value && fail(bit_vector)
      {min_max, min_max_index, PackedMinMax.get_min(min_max), PackedMinMax.get_max(min_max)}
    end)
  end

  defp get_min_max_impl({:bit_vector, ref} = bit_vector) do
    min_max_index = min_max_index(bit_vector)
    {min_max_index, :atomics.get(ref, min_max_index)}
  end

  def set_min(bit_vector, new_min) do
    set_min(bit_vector, new_min, get_min_max(bit_vector))
  end

  def set_min({:bit_vector, ref} = bit_vector, new_min, min_max_info) do
    {current_min_max, min_max_idx, current_min, current_max} = min_max_info

    cond do
      new_min > current_max ->
        ## Inconsistency
        fail(bit_vector)

      new_min != current_min && current_min == current_max ->
        ## Attempt to re-fix
        fail(bit_vector)

      true ->
        ## Min change
        min_max_value = PackedMinMax.set_min(current_min_max, new_min)

        case :atomics.compare_exchange(ref, min_max_idx, current_min_max, min_max_value) do
          :ok ->
            cond do
              new_min == current_max -> :fixed
              new_min <= current_min -> :no_change
              true -> :min_change
            end

          changed_by_other_thread ->
            min2 = PackedMinMax.get_min(changed_by_other_thread)
            max2 = PackedMinMax.get_max(changed_by_other_thread)
            set_min(bit_vector, new_min, {changed_by_other_thread, min_max_idx, min2, max2})
        end
    end
  end

  def set_max(bit_vector, new_max) do
    set_max(bit_vector, new_max, get_min_max(bit_vector))
  end

  def set_max({:bit_vector, ref} = bit_vector, new_max, min_max_info) do
    {current_min_max, min_max_idx, current_min, current_max} = min_max_info

    cond do
      new_max < current_min ->
        ## Inconsistency
        fail(bit_vector)

      new_max != current_max && current_min == current_max ->
        ## Attempt to re-fix
        fail(bit_vector)

      true ->
        ## Max change
        min_max_value = PackedMinMax.set_max(current_min_max, new_max)

        case :atomics.compare_exchange(ref, min_max_idx, current_min_max, min_max_value) do
          :ok ->
            cond do
              new_max == current_min -> :fixed
              new_max >= current_max -> :no_change
              true -> :max_change
            end

          changed_by_other_thread ->
            min2 = PackedMinMax.get_min(changed_by_other_thread)
            max2 = PackedMinMax.get_max(changed_by_other_thread)
            set_max(bit_vector, new_max, {changed_by_other_thread, min_max_idx, min2, max2})
        end
    end
  end

  def set_fixed({:bit_vector, ref} = bit_vector, fixed_value, min_max_info) do
    {current_min_max, min_max_idx, current_min, current_max} = min_max_info

    if fixed_value != current_max && current_min == current_max do
      ## Attempt to re-fix
      fail(bit_vector)
    else
      min_max_value = PackedMinMax.set_min(0, fixed_value) |> PackedMinMax.set_max(fixed_value)

      case :atomics.compare_exchange(ref, min_max_idx, current_min_max, min_max_value) do
        :ok ->
          :fixed

        changed_by_other_thread ->
          min2 = PackedMinMax.get_min(changed_by_other_thread)
          max2 = PackedMinMax.get_max(changed_by_other_thread)
          set_fixed(bit_vector, fixed_value, {changed_by_other_thread, min_max_idx, min2, max2})
      end
    end
  end

  ## Update (cached) min, if necessary
  defp tighten_min(
         {:bit_vector, atomics_ref} = bit_vector,
         starting_at,
         max_value
       ) do
    {current_max_block, _} = vector_address(max_value)
    {rightmost_block, position_in_block} = vector_address(starting_at + 1)
    ## Find a new min (on the right of the current one)
    min_value =
      Enum.reduce_while(rightmost_block..current_max_block, false, fn idx, min_block_empty? ->
        case :atomics.get(atomics_ref, idx) do
          0 ->
            {:cont, min_block_empty?}

          non_zero_block ->
            block_lsb =
              if min_block_empty? do
                lsb(non_zero_block)
              else
                ## Reset all bits in the block to the left of the position
                shift = position_in_block
                lsb(non_zero_block >>> shift <<< shift)
              end

            (block_lsb &&
               {:halt, (idx - 1) * 64 + block_lsb}) || {:cont, true}
        end
      end)

    (is_integer(min_value) && set_min(bit_vector, min_value)) || fail(bit_vector)
  end

  ## Update (cached) max
  defp tighten_max(
         {:bit_vector, atomics_ref} = bit_vector,
         starting_at,
         min_value
       ) do
    {current_min_block_idx, _} = vector_address(min_value)
    {leftmost_block_idx, position_in_block} = vector_address(starting_at - 1)
    ## Find a new max (on the left of the current one)
    ##

    max_value =
      Enum.reduce_while(
        leftmost_block_idx..current_min_block_idx,
        false,
        fn idx, max_block_empty? ->
          case :atomics.get(atomics_ref, idx) do
            0 ->
              {:cont, max_block_empty?}

            non_zero_block ->
              block_msb =
                if max_block_empty? do
                  msb(non_zero_block)
                else
                  ## Reset all bits in the block to the right of the position
                  mask = (1 <<< (position_in_block + 1)) - 1
                  msb(non_zero_block &&& mask)
                end

              (block_msb &&
                 {:halt, (idx - 1) * 64 + block_msb}) || {:cont, true}
          end
        end
      )

    (is_integer(max_value) && set_max(bit_vector, max_value)) || fail(bit_vector)
  end

  defp fail(bit_vector \\ nil) do
    bit_vector && set_min_max(bit_vector, @failure_value)
    throw(:fail)
  end

  def get_bound_addrs(bit_vector) do
    {_, _, current_min, current_max} = get_min_max(bit_vector)
    {current_min_block, current_min_offset} = vector_address(current_min)
    {current_max_block, current_max_offset} = vector_address(current_max)

    %{
      min_addr: %{block: current_min_block, offset: current_min_offset},
      max_addr: %{block: current_max_block, offset: current_max_offset}
    }
  end

  ## Find the index of atomics where the n-value resides
  defp block_index(n) do
    div(n, 64) + 1
  end

  defp vector_address(n) do
    {block_index(n), rem(n, 64)}
  end

  ## Find least significant bit for given number
  def lsb(n, method \\ :debruijn)

  def lsb(0, _method) do
    nil
  end

  def lsb(n, :shift) do
    lsb_impl(n, 0)
  end

  def lsb(n, :debruijn) do
    deBruijnSequence = 0x022FDD63CC95386D
    ## Complement, multiply and normalize to 64-bit
    normalized = (n &&& -n) * deBruijnSequence &&& ((1 <<< 64) - 1)
    ## Use first 6 bits to locate in index table
    normalized >>> 58
    ## || lsb(n, :shift)
    |> deBruijnTable()
  end

  defp lsb_impl(1, idx) do
    idx
  end

  defp lsb_impl(n, idx) do
    ((n &&& 1) == 1 && idx) ||
      lsb_impl(n >>> 1, idx + 1)
  end

  def msb_(n) do
    if n > 0 do
      msb_impl(n, -1)
    end
  end

  defp msb_impl(0, acc) do
    acc
  end

  defp msb_impl(n, acc) do
    msb_impl(n >>> 1, acc + 1)
  end

  def msb(n) do
    if n > 0 do
      n = n ||| n >>> 1
      n = n ||| n >>> 2
      n = n ||| n >>> 4
      n = n ||| n >>> 8
      n = n ||| n >>> 16
      n = n ||| n >>> 32

      log2(n - (n >>> 1))
    end
  end

  def bit_count(0) do
    0
  end

  def bit_count(n) do
    n = (n &&& 0x5555555555555555) + (n >>> 1 &&& 0x5555555555555555)
    n = (n &&& 0x3333333333333333) + (n >>> 2 &&& 0x3333333333333333)
    n = (n &&& 0x0F0F0F0F0F0F0F0F) + (n >>> 4 &&& 0x0F0F0F0F0F0F0F0F)
    n = (n &&& 0x00FF00FF00FF00FF) + (n >>> 8 &&& 0x00FF00FF00FF00FF)
    n = (n &&& 0x0000FFFF0000FFFF) + (n >>> 16 &&& 0x0000FFFF0000FFFF)
    (n &&& 0x00000000FFFFFFFF) + (n >>> 32 &&& 0x00000000FFFFFFFF)
  end

  def bit_positions(0, _mapper) do
    MapSet.new()
  end

  def bit_positions(n, mapper) do
    lsb = lsb(n)
    msb = msb(n)

    initial_set =
      Enum.reduce([lsb, msb], MapSet.new(), fn value, acc ->
        case mapper.(value) do
          nil ->
            acc

          new_value ->
            MapSet.put(acc, new_value)
        end
      end)

    bit_positions(n >>> lsb, 1, lsb, msb, mapper, initial_set)
  end

  def bit_positions(_n, _shift, iteration, msb, _mapper, positions) when iteration == msb do
    positions
  end

  def bit_positions(n, shift, iteration, msb, mapper, positions) do
    acc =
      ((n &&& shift) > 0 &&
         case mapper.(iteration) do
           nil -> positions
           new_value -> MapSet.put(positions, new_value)
         end) ||
        positions

    bit_positions(n, shift <<< 1, iteration + 1, msb, mapper, acc)
  end

  ## Precompiled log2 values for powers of 2
  defp log2(1), do: 0
  defp log2(2), do: 1
  defp log2(4), do: 2
  defp log2(8), do: 3
  defp log2(16), do: 4
  defp log2(32), do: 5
  defp log2(64), do: 6
  defp log2(128), do: 7
  defp log2(256), do: 8
  defp log2(512), do: 9
  defp log2(1024), do: 10
  defp log2(2048), do: 11
  defp log2(4096), do: 12
  defp log2(8192), do: 13
  defp log2(16384), do: 14
  defp log2(32768), do: 15
  defp log2(65536), do: 16
  defp log2(131_072), do: 17
  defp log2(262_144), do: 18
  defp log2(524_288), do: 19
  defp log2(1_048_576), do: 20
  defp log2(2_097_152), do: 21
  defp log2(4_194_304), do: 22
  defp log2(8_388_608), do: 23
  defp log2(16_777_216), do: 24
  defp log2(33_554_432), do: 25
  defp log2(67_108_864), do: 26
  defp log2(134_217_728), do: 27
  defp log2(268_435_456), do: 28
  defp log2(536_870_912), do: 29
  defp log2(1_073_741_824), do: 30
  defp log2(2_147_483_648), do: 31
  defp log2(4_294_967_296), do: 32
  defp log2(8_589_934_592), do: 33
  defp log2(17_179_869_184), do: 34
  defp log2(34_359_738_368), do: 35
  defp log2(68_719_476_736), do: 36
  defp log2(137_438_953_472), do: 37
  defp log2(274_877_906_944), do: 38
  defp log2(549_755_813_888), do: 39
  defp log2(1_099_511_627_776), do: 40
  defp log2(2_199_023_255_552), do: 41
  defp log2(4_398_046_511_104), do: 42
  defp log2(8_796_093_022_208), do: 43
  defp log2(17_592_186_044_416), do: 44
  defp log2(35_184_372_088_832), do: 45
  defp log2(70_368_744_177_664), do: 46
  defp log2(140_737_488_355_328), do: 47
  defp log2(281_474_976_710_656), do: 48
  defp log2(562_949_953_421_312), do: 49
  defp log2(1_125_899_906_842_624), do: 50
  defp log2(2_251_799_813_685_248), do: 51
  defp log2(4_503_599_627_370_496), do: 52
  defp log2(9_007_199_254_740_992), do: 53
  defp log2(18_014_398_509_481_984), do: 54
  defp log2(36_028_797_018_963_968), do: 55
  defp log2(72_057_594_037_927_936), do: 56
  defp log2(144_115_188_075_855_872), do: 57
  defp log2(288_230_376_151_711_744), do: 58
  defp log2(576_460_752_303_423_488), do: 59
  defp log2(1_152_921_504_606_846_976), do: 60
  defp log2(2_305_843_009_213_693_952), do: 61
  defp log2(4_611_686_018_427_387_904), do: 62
  defp log2(9_223_372_036_854_775_808), do: 63

  ## De Bruijn table for sequence 0x022FDD63CC95386D
  defp deBruijnTable(0), do: 0
  defp deBruijnTable(1), do: 1
  defp deBruijnTable(2), do: 2
  defp deBruijnTable(3), do: 53
  defp deBruijnTable(4), do: 3
  defp deBruijnTable(5), do: 7
  defp deBruijnTable(6), do: 54
  defp deBruijnTable(7), do: 27
  defp deBruijnTable(8), do: 4
  defp deBruijnTable(9), do: 38
  defp deBruijnTable(10), do: 41
  defp deBruijnTable(11), do: 8
  defp deBruijnTable(12), do: 34
  defp deBruijnTable(13), do: 55
  defp deBruijnTable(14), do: 48
  defp deBruijnTable(15), do: 28
  defp deBruijnTable(16), do: 62
  defp deBruijnTable(17), do: 5
  defp deBruijnTable(18), do: 39
  defp deBruijnTable(19), do: 46
  defp deBruijnTable(20), do: 44
  defp deBruijnTable(21), do: 42
  defp deBruijnTable(22), do: 22
  defp deBruijnTable(23), do: 9
  defp deBruijnTable(24), do: 24
  defp deBruijnTable(25), do: 35
  defp deBruijnTable(26), do: 59
  defp deBruijnTable(27), do: 56
  defp deBruijnTable(28), do: 49
  defp deBruijnTable(29), do: 18
  defp deBruijnTable(30), do: 29
  defp deBruijnTable(31), do: 11
  defp deBruijnTable(32), do: 63
  defp deBruijnTable(33), do: 52
  defp deBruijnTable(34), do: 6
  defp deBruijnTable(35), do: 26
  defp deBruijnTable(36), do: 37
  defp deBruijnTable(37), do: 40
  defp deBruijnTable(38), do: 33
  defp deBruijnTable(39), do: 47
  defp deBruijnTable(40), do: 61
  defp deBruijnTable(41), do: 45
  defp deBruijnTable(42), do: 43
  defp deBruijnTable(43), do: 21
  defp deBruijnTable(44), do: 23
  defp deBruijnTable(45), do: 58
  defp deBruijnTable(46), do: 17
  defp deBruijnTable(47), do: 10
  defp deBruijnTable(48), do: 51
  defp deBruijnTable(49), do: 25
  defp deBruijnTable(50), do: 36
  defp deBruijnTable(51), do: 32
  defp deBruijnTable(52), do: 60
  defp deBruijnTable(53), do: 20
  defp deBruijnTable(54), do: 57
  defp deBruijnTable(55), do: 16
  defp deBruijnTable(56), do: 50
  defp deBruijnTable(57), do: 31
  defp deBruijnTable(58), do: 19
  defp deBruijnTable(59), do: 15
  defp deBruijnTable(60), do: 30
  defp deBruijnTable(61), do: 14
  defp deBruijnTable(62), do: 13
  defp deBruijnTable(63), do: 12
end
