defmodule SmsPartCounter do
  @moduledoc """
  Module for detecting which encoding is being used and the character count of SMS text.
  """
  smart_encodable_chars = "\u00AB\u00BB\u201C\u201D\u02BA\u02EE\u201F\u275D\u275E\u301D\u301E\uFF02\u2018\u2019\u02BB\u02C8\u02BC\u02BD\u02B9\u201B\uFF07\u00B4\u02CA\u0060\u02CB\u275B\u275C\u0313\u0314\uFE10\uFE11\u00F7\u00BC\u00BD\u00BE\u29F8\u0337\u0338\u2044\u2215\uFF0F\u29F9\u29F5\u20E5\uFE68\uFF3C\u0332\uFF3F\u20D2\u20D3\u2223\uFF5C\u23B8\u23B9\u23D0\u239C\u239F\u23BC\u23BD\u2015\uFE63\uFF0D\u2010\u2022\u2043\uFE6B\uFF20\uFE69\uFF04\u01C3\uFE15\uFE57\uFF01\uFE5F\uFF03\uFE6A\uFF05\uFE60\uFF06\u201A\u0326\uFE50\u3001\uFE51\uFF0C\uFF64\u2768\u276A\uFE59\uFF08\u27EE\u2985\u2769\u276B\uFE5A\uFF09\u27EF\u2986\u204E\u2217\u229B\u2722\u2723\u2724\u2725\u2731\u2732\u2733\u273A\u273B\u273C\u273D\u2743\u2749\u274A\u274B\u29C6\uFE61\uFF0A\u02D6\uFE62\uFF0B\u3002\uFE52\uFF0E\uFF61\uFF10\uFF11\uFF12\uFF13\uFF14\uFF15\uFF16\uFF17\uFF18\uFF19\u02D0\u02F8\u2982\uA789\uFE13\uFF1A\u204F\uFE14\uFE54\uFF1B\uFE64\uFF1C\u0347\uA78A\uFE66\uFF1D\uFE65\uFF1E\uFE16\uFE56\uFF1F\uFF21\u1D00\uFF22\u0299\uFF23\u1D04\uFF24\u1D05\uFF25\u1D07\uFF26\uA730\uFF27\u0262\uFF28\u029C\uFF29\u026A\uFF2A\u1D0A\uFF2B\u1D0B\uFF2C\u029F\uFF2D\u1D0D\uFF2E\u0274\uFF2F\u1D0F\uFF30\u1D18\uFF31\uFF32\u0280\uFF33\uA731\uFF34\u1D1B\uFF35\u1D1C\uFF36\u1D20\uFF37\u1D21\uFF38\uFF39\u028F\uFF3A\u1D22\u02C6\u0302\uFF3E\u1DCD\u2774\uFE5B\uFF5B\u2775\uFE5C\uFF5D\uFF3B\uFF3D\u02DC\u02F7\u0303\u0330\u0334\u223C\uFF5E\u00A0\u2000\u2001\u2002\u2003\u2004\u2005\u2006\u2007\u2008\u2009\u200A\u200B\u202F\u205F\u3000\uFEFF\u008D\u009F\u0080\u0090\u0009\u009B\u0003\u0004\u0000\u0017\u0010\u0019\u0011\u0012\u0013\u0014\u2017\u2014\u2013\u2039\u203A\u203C\u201E\u2026\u2028\u2029\u2060"

  gsm_7bit_ext_chars =
    "@£$¥èéùìòÇ\nØø\rÅåΔ_ΦΓΛΩΠΨΣΘΞÆæßÉ !\"#¤%&'()*+,-./0123456789:;<=>?¡ABCDEFGHIJKLMNOPQRSTUVWXYZÄÖÑÜ§¿abcdefghijklmnopqrstuvwxyzäöñüà" <>
      "^{}\\[~]|€"

  @gsm_7bit_char_set MapSet.new(String.codepoints(gsm_7bit_ext_chars))
  @gsm_7bit_char_set_with_smart_encoding MapSet.new(String.codepoints(smart_encodable_chars <> gsm_7bit_ext_chars))
  @gsm_single_length 160
  @gsm_multi_length 153
  @unicode_single_length 70
  @unicode_multi_length 67

  @doc """
  Counts the characters in a string.

  ## Examples

      iex> SmsPartCounter.count("Hello")
      5
      iex> SmsPartCounter.count("আম")
      2

  """
  @spec count(binary) :: integer()
  def count(str) when is_binary(str) do
    str
    |> String.codepoints()
    |> Enum.count()
  end

  @doc """
  Counts the part of a message that's encoded with GSM 7 Bit encoding.
  The GSM 7 Bit Encoded messages have following length requirement:
  Signle SMS Part Length: 160 Chars
  Multi SMS Part Length: 153 Chars

  ## Examples

      iex> SmsPartCounter.gsm_part_count("asdf")
      1

  """
  @spec gsm_part_count(binary) :: integer()
  def gsm_part_count(sms) when is_binary(sms) do
    sms_char_count = count(sms)
    part_count(sms_char_count, @gsm_single_length, @gsm_multi_length)
  end

  @doc """
  Counts the part of a message that's encoded with Unicode encoding.
  The Unicode Encoded messages have following length requirement:
  Signle SMS Part Length: 70 Chars
  Multi SMS Part Length: 67 Chars

  ## Examples

      iex> SmsPartCounter.unicode_part_count("আমি")
      1

  """
  @spec unicode_part_count(binary) :: integer()
  def unicode_part_count(sms, opts \\ %{}) when is_binary(sms) do
    smart_encoding_enabled = Map.get(opts, :smart_encoding, true)
    comparison_charset = get_comparison_charset(smart_encoding_enabled)
    sms_char_count = unicode_character_count(sms, comparison_charset)
    part_count(sms_char_count, @unicode_single_length, @unicode_multi_length)
  end

  defp part_count(sms_char_count, single_count, multi_count) do
    cond do
      sms_char_count < single_count + 1 ->
        1

      sms_char_count > single_count ->
        div(sms_char_count, multi_count) +
          if rem(sms_char_count, multi_count) == 0, do: 0, else: 1
    end
  end

  # UTF-2 characters outside of the "comparison_charset" argument count as 2 characters
  # when calculating segments
  defp unicode_character_count(sms_char_set, comparison_charset) do
    sms_char_set
    |> String.split("")
    |> Enum.slice(1..-1)
    |> Enum.reduce(0, fn substr, acc ->
      count = substr |> String.codepoints() |> Enum.count()
      substr_mapset = MapSet.new(String.codepoints(substr))
      (empty_map_set?(MapSet.difference(substr_mapset, comparison_charset)) || count > 1)
      |> case do
        true ->
          acc + count

        false ->
          acc + 2
        end
    end)
  end

  @doc """
  Detects the encoding of the SMS message based on the charset of GSM 7 bit Encoding.
  It does a set difference between the characters in the sms and the gsm 7 bit encoding char set.

  ## Examples

      iex> SmsPartCounter.detect_encoding("adb abc")
      {:ok, "gsm_7bit"}
      iex> SmsPartCounter.detect_encoding("আমি")
      {:ok, "unicode"}

  """
  @spec detect_encoding(binary) :: {:ok | :error, Sting.t()}
  def detect_encoding(sms, opts \\ %{}) when is_binary(sms) do
    sms_char_set = MapSet.new(String.codepoints(sms))
    smart_encoding_enabled = Map.get(opts, :smart_encoding, true)

    comparison_charset = if smart_encoding_enabled, do: @gsm_7bit_char_set_with_smart_encoding, else: @gsm_7bit_char_set

    diff = MapSet.difference(sms_char_set, comparison_charset)

    empty_map_set?(diff)
    |> case do
      true ->
        {:ok, "gsm_7bit"}

      false ->
        {:ok, "unicode"}

    end
  end

  defp empty_map_set?(map_set = %MapSet{}) do
    empty_map_set = MapSet.new

    map_set
    |> case do
    ^empty_map_set ->true
    _ -> false
    end
  end

  @doc """
  Detects the encoding of the SMS then counts the part, returns all information
  as a map of the following format:

      %{
        "encoding" => encoding,
        "parts" => part count
      }

  ## Examples

      iex> SmsPartCounter.count_parts("abc")
      %{
        "encoding" => "gsm_7bit",
        "parts" => 1
      }

  """
  @spec count_parts(binary) :: %{String.t() => String.t(), String.t() => integer()}
  def count_parts(sms, opts \\ %{}) when is_binary(sms) do
    {:ok, encoding} = detect_encoding(sms, opts)

    smart_encoding_enabled = Map.get(opts, :smart_encoding, true)
    comparison_charset = get_comparison_charset(smart_encoding_enabled)

    case encoding do
      "gsm_7bit" ->
        parts = gsm_part_count(sms)

        %{
          "encoding" => encoding,
          "parts" => parts
        }

      "unicode" ->
        parts = unicode_part_count(sms, opts)

        %{
          "encoding" => encoding,
          "parts" => parts
        }
    end
  end

  defp get_comparison_charset(smart_encoding_enabled) do
    if smart_encoding_enabled, do: @gsm_7bit_char_set_with_smart_encoding, else: @gsm_7bit_char_set
  end
end
