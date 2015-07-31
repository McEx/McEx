defmodule McEx.UUID do

  def hyphenize_string(uuid) do
    String.to_char_list(uuid)
    |> List.insert_at(20, "-") |> List.insert_at(16, "-") |> List.insert_at(12, "-") |> List.insert_at(8, "-")
    |> List.to_string
  end
end
