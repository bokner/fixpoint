defmodule PackedMinMax do
  import Bitwise

  def get_min(packed, size \\ 32) do
    packed &&& all_bits_mask(size)
  end

  def get_max(packed, size \\ 32) do
    packed >>> size
  end

  def set_min(packed, min_value, size \\ 32) do
    get_max(packed, size) <<< size ||| min_value
  end

  def set_max(packed, max_value, size \\ 32) do
    max_value <<< size ||| get_min(packed, size)
  end

  defp all_bits_mask(size) do
    (1 <<< size) - 1
  end
end
