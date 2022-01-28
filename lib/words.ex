defmodule WordleInfo.Words do
  @word_file "words.txt"
  @external_resource @word_file

  @words @word_file
         |> File.stream!()
         |> Enum.map(fn str ->
           str
           |> String.trim()
           |> String.downcase()
         end)
         |> Enum.filter(&String.match?(&1, ~r/^[[:alpha:]]+$/))

  def words(), do: @words
end
