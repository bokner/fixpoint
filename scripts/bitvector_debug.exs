defmodule DebugBitVector do
  alias CPSolver.BitVectorDomain, as: Domain

  def build_domain(data) do
    ref = :atomics.new(length(data.raw.content), [{:signed, false}])

    Enum.each(Enum.with_index(data.raw.content, 1), fn {val, idx} ->
      :atomics.put(ref, idx, val)
    end)

    bit_vector = {:bit_vector, data.raw.offset, ref}
    domain = {bit_vector, data.raw.offset}
  end
end

data = %{
  max: 76,
  min: 14,
  raw: %{offset: -11, content: [4_503_599_644_147_720, 2, 279_172_874_243]},
  size: 4,
  remove: 76,
  values: [76, 63, 35, 14],
  failed?: false,
  fixed?: false
}
