defmodule CPSolver.BitVectorDomainV2 do
  import Bitwise
  import InPlace.BitUtils
  alias InPlace.{Array, SparseSet}
  alias InPlace.Utils.BitVector

  def new([]) do
    fail()
  end

  def new(domain) when is_integer(domain) do
    new([domain])
  end

  def new(domain) when is_list(domain) or is_struct(domain, Range) or is_struct(domain, MapSet) do
    offset = -Enum.min(domain)
    domain_size = Enum.max(domain) + offset
    {:bit_vector, atomics_ref} = bv = BitVector.new(domain_size + 1)
    blocks_count = :atomics.info(atomics_ref).size
    Enum.each(domain, fn idx -> BitVector.set(bv, idx + offset) end)
    min_block = Array.new(1)
    Array.put(min_block, 1, 1)
    max_block = Array.new(1)
    Array.put(max_block, 1, blocks_count)

    block_tracker = SparseSet.new(blocks_count)

    %{
      bit_vector: bv,
      offset: offset,
      min_block: min_block,
      max_block: max_block,
      block_tracker: block_tracker
    }
    |> tap(fn domain ->
      ## Remove empty blocks
      Enum.each(1..blocks_count, fn b_idx ->
        if :atomics.get(atomics_ref, b_idx) == 0 do
          delete_block(domain, b_idx)
        end
      end)
    end)
  end

  def copy(%{bit_vector: {:bit_vector, ref} = _bit_vector, block_tracker: block_tracker} = domain) do
    atomics_copy_size = SparseSet.size(block_tracker)
    atomics_copy_ref = :atomics.new(atomics_copy_size, [{:signed, false}])
    block_tracker_copy = SparseSet.new(atomics_copy_size)

    SparseSet.each(
      block_tracker,
      fn block_idx ->
        block_val = :atomics.get(ref, block_idx)
        :atomics.put(atomics_copy_ref, block_idx, block_val)
      end
    )

    bit_vector_copy = {:bit_vector, atomics_copy_ref}
    min_block = Array.new(1)
    Array.put(min_block, 1, 1)
    max_block = Array.new(1)
    Array.put(max_block, 1, atomics_copy_size)

    domain
    |> Map.put(:bit_vector, bit_vector_copy)
    |> Map.put(:block_tracker, block_tracker_copy)
    |> Map.put(:min_block, min_block)
    |> Map.put(:max_block, max_block)
  end

  def size(%{bit_vector: {:bit_vector, ref} = _bit_vector, block_tracker: block_tracker} = domain) do
    SparseSet.reduce(block_tracker, 0, fn idx, acc ->
      n = :atomics.get(ref, idx)

      if n == 0 do
        delete_block(domain, idx)
        acc
      else
        acc + bit_count(n)
      end
    end)
  end

  defp delete_block(
         %{
           block_tracker: tracker,
           min_block: min_block,
           max_block: max_block
         } = _domain,
         idx
       ) do
    SparseSet.delete(tracker, idx)
    |> tap(fn delete_res ->
      if SparseSet.empty?(tracker), do: fail()

      cond do
        Array.get(min_block, 1) == idx ->
          ## Find non-empty block with higher index
          SparseSet.reduce(
            tracker, nil,
            fn b_idx, _acc ->
              if b_idx > idx do
                {:halt, Array.put(min_block, 1, b_idx)}
              else
                {:cont, nil}
              end
            end
          )

        Array.get(max_block, 1) == idx ->
          ## Find non-empty block with lower index
          SparseSet.reduce(
            tracker, nil,
            fn b_idx, _acc ->
              if b_idx < idx do
              {:halt, Array.put(max_block, 1, b_idx)}
              else
                {:cont, nil}
              end
            end
          )

        true ->
          delete_res
      end
    end)
  end

  ## 'next' value in the domain
  def next(%{bit_vector: {:bit_vector, ref}, offset: offset, max_block: max_block} = domain, value) do
    cond do
      value  < min(domain) ->
        nil

      value  >= max(domain) ->
        nil

      true ->
        {block_index, position} = vector_address(value + offset)

        case next(block_index, position, ref, Array.get(max_block, 1)) do
          nil -> nil
          positional_value -> positional_value - offset
        end
    end
  end

  defp next(block_index, _position, _atomics_ref, last_index) when block_index > last_index do
    nil
  end

  defp next(block_index, position, atomics_ref, last_index) do
    block = :atomics.get(atomics_ref, block_index)
    ## Check if the block has bits on the right of the position of initial value.
    shift = position + 1
    shifted_left = block >>> shift

    case lsb(shifted_left) do
      ## nothing in this block, try next one
      nil ->
        next(block_index + 1, -1, atomics_ref, last_index)

      next_lsb ->
        positional_value(block_index, next_lsb + shift)
    end
  end

  def map(domain, mapper_fun) when is_function(mapper_fun) do
    to_list(domain, mapper_fun)
  end

  ## Reduce over domain values
  def reduce(
        %{bit_vector: {:bit_vector, ref} = _bit_vector, offset: offset, block_tracker: tracker} =
          domain,
        value_mapper_fun,
        acc_init \\ MapSet.new(),
        reduce_fun \\ &MapSet.union/2
      ) do
    lb = min(domain)
    ub = max(domain)

    SparseSet.reduce(tracker, acc_init, fn block_idx, acc ->
      case :atomics.get(ref, block_idx) do
        0 ->
          delete_block(tracker, block_idx)
          acc

        block ->
          reduce_fun.(
            acc,
            bit_positions(block, fn val ->
              case val + 64 * (block_idx - 1) - offset do
                value when value >= lb and value <= ub ->
                  value_mapper_fun.(value)

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

  def fixed?(domain) do
    min(domain) == max(domain)
  end

  def failed?(%{block_tracker: tracker} = _domain) do
    SparseSet.size(tracker) == 0
  end

  def min(
        %{bit_vector: {:bit_vector, atomics_ref}, min_block: min_block, offset: offset} = _domain
      ) do
    min_block_idx = Array.get(min_block, 1)

    case lsb(:atomics.get(atomics_ref, min_block_idx)) do
      nil ->
        nil

      lsb ->
        lsb - offset
    end
  end

  def max(
        %{bit_vector: {:bit_vector, atomics_ref}, max_block: max_block, offset: offset} = _domain
      ) do
    max_block_idx = Array.get(max_block, 1)

    case msb(:atomics.get(atomics_ref, max_block_idx)) do
      nil ->
        nil

      msb ->
        msb + (max_block_idx - 1) * 64 - offset
    end
  end

  def contains?(
        %{bit_vector: bit_vector, offset: offset, block_tracker: tracker} = _domain,
        value
      ) do
    case vector_value(value, offset) do
      vector_value when vector_value < 0 ->
        false
        vector_value ->
    block_idx = block_index(vector_value)

    SparseSet.member?(tracker, block_idx) &&
      BitVector.get(bit_vector, vector_value) == 1
    end
  end

  def fix(
        %{bit_vector: {:bit_vector, ref}, offset: offset, block_tracker: tracker} = domain,
        value
      ) do
    case vector_value(value, offset) do
      vector_value when vector_value < 0 -> fail()
      vector_value ->
    {fixed_block_index, block_offset} = vector_address(vector_value)

    if contains?(domain, value) do
      if fixed?(domain) do
        :no_change
      else
        ## In the block, reset all bits except the one at the "fixed" position
        :atomics.put(ref, fixed_block_index, 1 <<< block_offset)
        ## Remove all blocks that do not have fixed value
        SparseSet.each(tracker, fn block_idx ->
          if block_idx != fixed_block_index do
            ## We do not use delete_block/1
            ## to avoid unnecessary checks
            delete_block(domain, block_idx)
          end
        end)

        :fixed
      end
    else
      fail()
    end
  end
  end

  def remove(
        %{bit_vector: {:bit_vector, ref} = bit_vector, offset: offset} =
          domain,
        value
      ) do
    if contains?(domain, value) do
      domain_change =
        cond do
          value == min(domain) -> :min_change
          value == max(domain) -> :max_change
          true -> :domain_change
        end

      case vector_value(value, offset) do
        vector_value when vector_value < 0 -> :no_change
        vector_value ->
      block_index = block_index(vector_value)
      BitVector.clear(bit_vector, vector_value)

      if :atomics.get(ref, block_index) == 0 do
        delete_block(domain, block_index)
      end

      ## Adjust domain_change, if fixed
      {(fixed?(domain) && :fixed) || domain_change, domain}
      |> tap(fn _ -> BitVector.clear(bit_vector, vector_value) end)
    end
    else
      ## No value in the domain, do nothing
      :no_change
    end
  end

  def removeAbove(
        %{bit_vector: {:bit_vector, ref}, offset: offset, block_tracker: tracker} = domain,
        value
      ) do
    case vector_value(value, offset) do
      vector_value when vector_value < 0 ->
        fail()
        vector_value ->
    {value_block_idx, value_block_offset} = vector_address(vector_value)

    SparseSet.reduce(
      tracker,
      :no_change,
      fn b_idx, domain_change_acc ->
        cond do
          b_idx > value_block_idx ->
            delete_block(domain, b_idx)
            {:cont, :max_change}

          b_idx < value_block_idx ->
            {:cont, domain_change_acc}

          b_idx == value_block_idx ->
            ## This is the last block (we don't want to remove anything below it)
            last_block_value = :atomics.get(ref, b_idx)

            if msb(last_block_value) <= value_block_offset do
              ## The value is already above or equal to the "last block" value
              {:cont, domain_change_acc}
            else
              ## Shift msb
              last_block_value = unset_right(last_block_value, value_block_offset)
              if last_block_value == 0 do
                delete_block(domain, b_idx)
              else
                :atomics.put(ref, value_block_idx, last_block_value)
              end

              {:cont, :max_change}
            end
        end
      end
    )
    |> then(fn domain_change ->
      cond do
        domain_change == :no_change -> :no_change
        fixed?(domain) -> {:fixed, domain}
        domain_change -> {domain_change, domain}
      end
    end)
  end
  end

  def removeBelow(
        %{bit_vector: {:bit_vector, ref}, offset: offset, block_tracker: tracker} = domain,
        value
      ) do
    vector_value = vector_value(value, offset)
    {value_block_idx, value_block_offset} = vector_address(vector_value)

    SparseSet.reduce(
      tracker,
      :no_change,
      fn b_idx, domain_change_acc ->
        cond do
          b_idx < value_block_idx ->
            delete_block(domain, b_idx)
            {:cont, :min_change}

          b_idx > value_block_idx ->
            {:cont, domain_change_acc}

          b_idx == value_block_idx ->
            ## This is the last block (we don't want to remove anything above it)
            last_block_value = :atomics.get(ref, b_idx)

            if lsb(last_block_value) >= value_block_offset do
              ## The value is already below or equal to the "last block" value
              {:cont, domain_change_acc}
            else
              ## Shift lsb
              last_block_value = unset_left(last_block_value, value_block_offset) #(last_block_value >>> value_block_offset) <<< value_block_offset

              if last_block_value == 0 do
                delete_block(domain, b_idx)
              else
                :atomics.put(ref, value_block_idx, last_block_value)
              end

              {:cont, :min_change}
            end
        end
      end
    )
    |> then(fn domain_change ->
      cond do
        domain_change == :no_change -> :no_change
        fixed?(domain) -> {:fixed, domain}
        domain_change -> {domain_change, domain}
      end
    end)

  end

  def raw(%{bit_vector: {:domain_bit_vector, ref} = _bit_vector, offset: offset} = _domain) do
    %{
      offset: offset,
      content: Enum.map(1..:atomics.info(ref).size, fn i -> :atomics.get(ref, i) end)
    }
  end

  defp fail() do
    throw(:fail)
  end

  ## Find the index of atomics where the n-value resides
  defp block_index(n) do
    div(n, 64) + 1
  end

  def vector_address(n) do
    {block_index(n), rem(n, 64)}
  end

  defp vector_value(value, offset) do
    value + offset
  end

  ## Domain value, computed off the block index and position within the block
  def positional_value(block_index, position) do
    (block_index - 1) * 64 + position
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
end
