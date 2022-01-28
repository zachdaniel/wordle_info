defmodule WordleInfo do
  @moduledoc """
  Documentation for `WordleInfo`.
  """

  def most_common_letters do
    letters =
      WordleInfo.Words.words()
      |> Enum.filter(&(String.length(&1) == 5))
      |> Enum.reduce(%{all: 0}, fn word, acc ->
        word
        |> String.graphemes()
        |> Enum.reduce(acc, fn letter, acc ->
          acc
          |> Map.update(letter, 1, &(&1 + 1))
          |> Map.update!(:all, &(&1 + 1))
        end)
      end)

    letters
    |> Map.delete(:all)
    |> Enum.map(fn {letter, count} ->
      {letter, count / letters[:all] * 100}
    end)
    |> Enum.sort_by(&elem(&1, 1))
    |> Enum.reverse()
    |> Enum.map_join("\n", fn {letter, percent} ->
      "#{letter}: #{Float.round(percent, 2)}"
    end)
    |> IO.puts()

    nil
  end

  def bisect() do
    all_words =
      WordleInfo.Words.words()
      |> Enum.filter(&(String.length(&1) == 5))
      |> Enum.map(&String.graphemes/1)

    words_have =
      all_words
      |> Map.new(fn word ->
        {word, Map.new(word, &{&1, true})}
      end)

    word = String.graphemes(String.trim(IO.gets("choose a starting word")))

    continue_bisect(words_have, word)
  end

  defp continue_bisect(words_have, word, rules \\ %{guesses: 5}) do
    {words_that_have, words_that_dont_have} =
      words_have
      |> Enum.reduce({%{}, %{}}, fn {key, other_word}, {have, dont} ->
        if Enum.any?(word, &Map.has_key?(other_word, &1)) do
          {Map.put(have, key, other_word), dont}
        else
          {have, Map.put(dont, key, other_word)}
        end
      end)

    if_has_length = Enum.count(words_that_have)
    if_doesnt_have_length = Enum.count(words_that_dont_have)

    IO.puts(
      "try #{Enum.join(word)}, which cuts the word list into #{if_has_length} and #{if_doesnt_have_length} size piles."
    )

    if rules[:guesses] == 0 ||
         (rules.guesses != 5 and String.trim(IO.gets("did you win? (y/n)")) == "y") do
      IO.puts("Final answer: #{word}")
    else
      answer =
        if rules[:ever_not_all_gray?] do
          "n"
        else
          IO.gets("was it all gray? (y/n)")
        end

      if String.trim(answer) == "y" do
        {if_doesnt_have_word, _diff, _} =
          do_bisect(Map.keys(words_that_dont_have), words_have, if_doesnt_have_length, rules)

        rules = add_doesnt_have(rules, word)

        continue_bisect(
          words_that_dont_have,
          if_doesnt_have_word,
          rules |> Map.update!(:guesses, &(&1 + 1))
        )
      else
        rules =
          %{
            guesses: rules.guesses + 1,
            ever_not_all_gray?: true,
            letters_in_any_position: get_graphemes("what letters does it have in any position?"),
            letters_in_first:
              rules[:letters_in_first] ||
                get_or_nil("what is locked into the first position? (leave blank for none)"),
            letters_in_second:
              rules[:letters_in_second] ||
                get_or_nil("what is locked into the second position? (leave blank for none)"),
            letters_in_third:
              rules[:letters_in_third] ||
                get_or_nil("what is locked into the third position? (leave blank for none)"),
            letters_in_fourth:
              rules[:letters_in_fourth] ||
                get_or_nil("what is locked into the fourth position? (leave blank for none)"),
            letters_in_fifth:
              rules[:letters_in_fifth] ||
                get_or_nil("what is locked into the fifth position? (leave blank for none)"),
            doesnt_have: rules[:doesnt_have] || [],
            not_in_position: Map.get(rules, :not_in_position, %{})
          }
          |> add_doesnt_have(word)

        {if_has_word, _diff, _} =
          do_bisect(Map.keys(words_that_have), words_have, if_has_length, rules)

        continue_bisect(words_that_have, if_has_word, rules)
      end
    end
  end

  defp add_doesnt_have(rules, word) do
    doesnt_have =
      word
      |> Enum.reject(fn char ->
        char in (rules[:letters_in_any_position] || [])
      end)

    rules
    |> Map.update(:doesnt_have, doesnt_have, &(&1 ++ doesnt_have))
    |> add_not_in_position(0, :letters_in_first, word)
    |> add_not_in_position(1, :letters_in_second, word)
    |> add_not_in_position(2, :letters_in_third, word)
    |> add_not_in_position(3, :letters_in_fourth, word)
    |> add_not_in_position(4, :letters_in_fifth, word)
  end

  defp add_not_in_position(rules, index, key, word) do
    not_in_position = Map.get(rules, :not_in_position, %{})

    letter_in_word = Enum.at(word, index)

    new_not_in_position =
      if rules[key] != letter_in_word && letter_in_word in (rules[:letters_in_any_position] || []) do
        Map.update(not_in_position, index, [letter_in_word], &[letter_in_word | &1])
      else
        not_in_position
      end

    Map.put(rules, :not_in_position, new_not_in_position)
  end

  defp get_or_nil(message) do
    case String.trim(IO.gets(message)) do
      "" ->
        nil

      result ->
        result
    end
  end

  defp get_graphemes(message) do
    case String.trim(IO.gets(message)) do
      "" ->
        []

      result ->
        String.graphemes(result)
    end
  end

  defp do_bisect(all_words, words_have, length, rules \\ %{}) do
    words =
      all_words
      |> Stream.with_index()
      |> Stream.filter(fn {word, _} ->
        matches_rules?(word, rules)
      end)
      |> Stream.map(fn {word, i} ->
        if rem(i, 1000) == 0 do
          IO.puts("#{length - i} left to process")
        end

        count =
          Enum.count(words_have, fn {_, keys} ->
            Enum.any?(word, &Map.has_key?(keys, &1))
          end)

        {word, abs(length - count - count), count}
      end)
      |> Enum.to_list()

    words
    |> Enum.min_by(&elem(&1, 1))
  end

  defp matches_rules?(word, rules) do
    Enum.all?(rules[:letters_in_any_position] || [], &(&1 in word)) &&
      (is_nil(rules[:letters_in_first]) || Enum.at(word, 0) == rules[:letters_in_first]) &&
      (is_nil(rules[:letters_in_second]) || Enum.at(word, 1) == rules[:letters_in_second]) &&
      (is_nil(rules[:letters_in_third]) || Enum.at(word, 2) == rules[:letters_in_third]) &&
      (is_nil(rules[:letters_in_fourth]) || Enum.at(word, 3) == rules[:letters_in_fourth]) &&
      (is_nil(rules[:letters_in_fifth]) || Enum.at(word, 4) == rules[:letters_in_fifth]) &&
      Enum.all?(rules[:doesnt_have] || [], &(&1 not in word)) &&
      Enum.all?(rules[:not_in_position] || %{}, fn {index, letters} ->
        word_letter = Enum.at(word, index)

        Enum.all?(letters, fn letter ->
          letter != word_letter
        end)
      end)
  end
end
