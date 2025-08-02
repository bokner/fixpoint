defmodule CPSolver.BitUtils do
  import Bitwise

  @all_ones_mask (1 <<< 64) - 1
  ## Find least significant bit for given number
  def lsb(n, method \\ :debruijn)

  def lsb(0, _method) do
    nil
  end

  def lsb(n, :shift) do
    lsb_impl(n, 0)
  end

  def lsb(n, :debruijn) do
    sequence = 0x022FDD63CC95386D
    ## Complement, multiply and normalize to 64-bit
    normalized = (n &&& -n) * sequence &&& @all_ones_mask
    ## Use first 6 bits to locate in index table
    ## || lsb(n, :shift)
    deBruijnTable(sequence, normalized >>> 58)
  end

  defp lsb_impl(1, idx) do
    idx
  end

  defp lsb_impl(n, idx) do
    ((n &&& 1) == 1 && idx) ||
      lsb_impl(n >>> 1, idx + 1)
  end

  ## Find most significant bit for given number
  def msb(n, method \\ :debruijn)

  def msb(0, _method), do: nil

  def msb(n, :debruijn) do
    sequence = 0x03F79D71B4CB0A89

    if n > 0 do
      n = n ||| n >>> 1
      n = n ||| n >>> 2
      n = n ||| n >>> 4
      n = n ||| n >>> 8
      n = n ||| n >>> 16
      n = n ||| n >>> 32

      normalized = n * sequence &&& @all_ones_mask

      deBruijnTable(sequence, normalized >>> 58)
    end
  end

  def msb(n, :log2) do
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
  ## Used for LSB
  defp deBruijnTable(0x022FDD63CC95386D, 0), do: 0
  defp deBruijnTable(0x022FDD63CC95386D, 1), do: 1
  defp deBruijnTable(0x022FDD63CC95386D, 2), do: 2
  defp deBruijnTable(0x022FDD63CC95386D, 3), do: 53
  defp deBruijnTable(0x022FDD63CC95386D, 4), do: 3
  defp deBruijnTable(0x022FDD63CC95386D, 5), do: 7
  defp deBruijnTable(0x022FDD63CC95386D, 6), do: 54
  defp deBruijnTable(0x022FDD63CC95386D, 7), do: 27
  defp deBruijnTable(0x022FDD63CC95386D, 8), do: 4
  defp deBruijnTable(0x022FDD63CC95386D, 9), do: 38
  defp deBruijnTable(0x022FDD63CC95386D, 10), do: 41
  defp deBruijnTable(0x022FDD63CC95386D, 11), do: 8
  defp deBruijnTable(0x022FDD63CC95386D, 12), do: 34
  defp deBruijnTable(0x022FDD63CC95386D, 13), do: 55
  defp deBruijnTable(0x022FDD63CC95386D, 14), do: 48
  defp deBruijnTable(0x022FDD63CC95386D, 15), do: 28
  defp deBruijnTable(0x022FDD63CC95386D, 16), do: 62
  defp deBruijnTable(0x022FDD63CC95386D, 17), do: 5
  defp deBruijnTable(0x022FDD63CC95386D, 18), do: 39
  defp deBruijnTable(0x022FDD63CC95386D, 19), do: 46
  defp deBruijnTable(0x022FDD63CC95386D, 20), do: 44
  defp deBruijnTable(0x022FDD63CC95386D, 21), do: 42
  defp deBruijnTable(0x022FDD63CC95386D, 22), do: 22
  defp deBruijnTable(0x022FDD63CC95386D, 23), do: 9
  defp deBruijnTable(0x022FDD63CC95386D, 24), do: 24
  defp deBruijnTable(0x022FDD63CC95386D, 25), do: 35
  defp deBruijnTable(0x022FDD63CC95386D, 26), do: 59
  defp deBruijnTable(0x022FDD63CC95386D, 27), do: 56
  defp deBruijnTable(0x022FDD63CC95386D, 28), do: 49
  defp deBruijnTable(0x022FDD63CC95386D, 29), do: 18
  defp deBruijnTable(0x022FDD63CC95386D, 30), do: 29
  defp deBruijnTable(0x022FDD63CC95386D, 31), do: 11
  defp deBruijnTable(0x022FDD63CC95386D, 32), do: 63
  defp deBruijnTable(0x022FDD63CC95386D, 33), do: 52
  defp deBruijnTable(0x022FDD63CC95386D, 34), do: 6
  defp deBruijnTable(0x022FDD63CC95386D, 35), do: 26
  defp deBruijnTable(0x022FDD63CC95386D, 36), do: 37
  defp deBruijnTable(0x022FDD63CC95386D, 37), do: 40
  defp deBruijnTable(0x022FDD63CC95386D, 38), do: 33
  defp deBruijnTable(0x022FDD63CC95386D, 39), do: 47
  defp deBruijnTable(0x022FDD63CC95386D, 40), do: 61
  defp deBruijnTable(0x022FDD63CC95386D, 41), do: 45
  defp deBruijnTable(0x022FDD63CC95386D, 42), do: 43
  defp deBruijnTable(0x022FDD63CC95386D, 43), do: 21
  defp deBruijnTable(0x022FDD63CC95386D, 44), do: 23
  defp deBruijnTable(0x022FDD63CC95386D, 45), do: 58
  defp deBruijnTable(0x022FDD63CC95386D, 46), do: 17
  defp deBruijnTable(0x022FDD63CC95386D, 47), do: 10
  defp deBruijnTable(0x022FDD63CC95386D, 48), do: 51
  defp deBruijnTable(0x022FDD63CC95386D, 49), do: 25
  defp deBruijnTable(0x022FDD63CC95386D, 50), do: 36
  defp deBruijnTable(0x022FDD63CC95386D, 51), do: 32
  defp deBruijnTable(0x022FDD63CC95386D, 52), do: 60
  defp deBruijnTable(0x022FDD63CC95386D, 53), do: 20
  defp deBruijnTable(0x022FDD63CC95386D, 54), do: 57
  defp deBruijnTable(0x022FDD63CC95386D, 55), do: 16
  defp deBruijnTable(0x022FDD63CC95386D, 56), do: 50
  defp deBruijnTable(0x022FDD63CC95386D, 57), do: 31
  defp deBruijnTable(0x022FDD63CC95386D, 58), do: 19
  defp deBruijnTable(0x022FDD63CC95386D, 59), do: 15
  defp deBruijnTable(0x022FDD63CC95386D, 60), do: 30
  defp deBruijnTable(0x022FDD63CC95386D, 61), do: 14
  defp deBruijnTable(0x022FDD63CC95386D, 62), do: 13
  defp deBruijnTable(0x022FDD63CC95386D, 63), do: 12

  ## De Bruijn table for sequence 0x03F79D71B4CB0A89
  ## Used for MSB

  defp deBruijnTable(0x03F79D71B4CB0A89, 0), do: 0
  defp deBruijnTable(0x03F79D71B4CB0A89, 1), do: 47
  defp deBruijnTable(0x03F79D71B4CB0A89, 2), do: 1
  defp deBruijnTable(0x03F79D71B4CB0A89, 3), do: 56
  defp deBruijnTable(0x03F79D71B4CB0A89, 4), do: 48
  defp deBruijnTable(0x03F79D71B4CB0A89, 5), do: 27
  defp deBruijnTable(0x03F79D71B4CB0A89, 6), do: 2
  defp deBruijnTable(0x03F79D71B4CB0A89, 7), do: 60
  defp deBruijnTable(0x03F79D71B4CB0A89, 8), do: 57
  defp deBruijnTable(0x03F79D71B4CB0A89, 9), do: 49
  defp deBruijnTable(0x03F79D71B4CB0A89, 10), do: 41
  defp deBruijnTable(0x03F79D71B4CB0A89, 11), do: 37
  defp deBruijnTable(0x03F79D71B4CB0A89, 12), do: 28
  defp deBruijnTable(0x03F79D71B4CB0A89, 13), do: 16
  defp deBruijnTable(0x03F79D71B4CB0A89, 14), do: 3
  defp deBruijnTable(0x03F79D71B4CB0A89, 15), do: 61
  defp deBruijnTable(0x03F79D71B4CB0A89, 16), do: 54
  defp deBruijnTable(0x03F79D71B4CB0A89, 17), do: 58
  defp deBruijnTable(0x03F79D71B4CB0A89, 18), do: 35
  defp deBruijnTable(0x03F79D71B4CB0A89, 19), do: 52
  defp deBruijnTable(0x03F79D71B4CB0A89, 20), do: 50
  defp deBruijnTable(0x03F79D71B4CB0A89, 21), do: 42
  defp deBruijnTable(0x03F79D71B4CB0A89, 22), do: 21
  defp deBruijnTable(0x03F79D71B4CB0A89, 23), do: 44
  defp deBruijnTable(0x03F79D71B4CB0A89, 24), do: 38
  defp deBruijnTable(0x03F79D71B4CB0A89, 25), do: 32
  defp deBruijnTable(0x03F79D71B4CB0A89, 26), do: 29
  defp deBruijnTable(0x03F79D71B4CB0A89, 27), do: 23
  defp deBruijnTable(0x03F79D71B4CB0A89, 28), do: 17
  defp deBruijnTable(0x03F79D71B4CB0A89, 29), do: 11
  defp deBruijnTable(0x03F79D71B4CB0A89, 30), do: 4
  defp deBruijnTable(0x03F79D71B4CB0A89, 31), do: 62
  defp deBruijnTable(0x03F79D71B4CB0A89, 32), do: 46
  defp deBruijnTable(0x03F79D71B4CB0A89, 33), do: 55
  defp deBruijnTable(0x03F79D71B4CB0A89, 34), do: 26
  defp deBruijnTable(0x03F79D71B4CB0A89, 35), do: 59
  defp deBruijnTable(0x03F79D71B4CB0A89, 36), do: 40
  defp deBruijnTable(0x03F79D71B4CB0A89, 37), do: 36
  defp deBruijnTable(0x03F79D71B4CB0A89, 38), do: 15
  defp deBruijnTable(0x03F79D71B4CB0A89, 39), do: 53
  defp deBruijnTable(0x03F79D71B4CB0A89, 40), do: 34
  defp deBruijnTable(0x03F79D71B4CB0A89, 41), do: 51
  defp deBruijnTable(0x03F79D71B4CB0A89, 42), do: 20
  defp deBruijnTable(0x03F79D71B4CB0A89, 43), do: 43
  defp deBruijnTable(0x03F79D71B4CB0A89, 44), do: 31
  defp deBruijnTable(0x03F79D71B4CB0A89, 45), do: 22
  defp deBruijnTable(0x03F79D71B4CB0A89, 46), do: 10
  defp deBruijnTable(0x03F79D71B4CB0A89, 47), do: 45
  defp deBruijnTable(0x03F79D71B4CB0A89, 48), do: 25
  defp deBruijnTable(0x03F79D71B4CB0A89, 49), do: 39
  defp deBruijnTable(0x03F79D71B4CB0A89, 50), do: 14
  defp deBruijnTable(0x03F79D71B4CB0A89, 51), do: 33
  defp deBruijnTable(0x03F79D71B4CB0A89, 52), do: 19
  defp deBruijnTable(0x03F79D71B4CB0A89, 53), do: 30
  defp deBruijnTable(0x03F79D71B4CB0A89, 54), do: 9
  defp deBruijnTable(0x03F79D71B4CB0A89, 55), do: 24
  defp deBruijnTable(0x03F79D71B4CB0A89, 56), do: 13
  defp deBruijnTable(0x03F79D71B4CB0A89, 57), do: 18
  defp deBruijnTable(0x03F79D71B4CB0A89, 58), do: 8
  defp deBruijnTable(0x03F79D71B4CB0A89, 59), do: 12
  defp deBruijnTable(0x03F79D71B4CB0A89, 60), do: 7
  defp deBruijnTable(0x03F79D71B4CB0A89, 61), do: 6
  defp deBruijnTable(0x03F79D71B4CB0A89, 62), do: 5
  defp deBruijnTable(0x03F79D71B4CB0A89, 63), do: 63
end
