defmodule Realms.Messaging.Markup.Parser do
  @moduledoc """
  NimbleParsec-based markup parser.

  Compiles markup grammar into optimized binary-matching code at compile time.
  """

  import NimbleParsec

  alias Realms.Messaging.Message

  @valid_colors Message.valid_colors()

  escaped_lt = string("\\<") |> replace("<")
  escaped_gt = string("\\>") |> replace(">")
  escaped_backslash = string("\\\\") |> replace("\\")
  lone_backslash = string("\\") |> replace("\\")

  escaped_char = choice([escaped_lt, escaped_gt, escaped_backslash, lone_backslash])

  # < must either start a valid tag or be escaped
  plain_text = utf8_string([{:not, ?<}, {:not, ?\\}], min: 1)

  text_node =
    times(choice([escaped_char, plain_text]), min: 1)
    |> reduce({Enum, :join, []})

  color_name =
    ascii_string([?a..?z, ?A..?Z, ?-], min: 1)
    |> post_traverse({:validate_and_convert_color, []})

  # Fallback captures invalid modifiers for better error messages
  modifier =
    choice([
      string("b") |> replace(:bold),
      string("i") |> replace(:italic),
      ascii_char([?a..?z, ?A..?Z]) |> post_traverse({:invalid_modifier_error, []})
    ])

  tag_spec =
    choice([
      # Lookahead prevents matching 'b' in 'blue' or 'i' in 'indigo'
      string("b") |> lookahead(string(">")) |> replace({nil, [:bold]}),
      string("i") |> lookahead(string(">")) |> replace({nil, [:italic]}),
      # Don't use full modifier combinator (has error fallback)
      choice([string("b") |> replace(:bold), string("i") |> replace(:italic)])
      |> times(ignore(string(":")) |> concat(modifier), min: 1)
      |> post_traverse({:build_modifier_only_spec, []}),
      color_name
      |> repeat(ignore(string(":")) |> concat(modifier))
      |> post_traverse({:build_tag_spec, []})
    ])

  open_tag = ignore(string("<")) |> concat(tag_spec) |> ignore(string(">"))
  close_tag = string("</>")

  defcombinatorp(
    :tag,
    open_tag
    |> repeat(lookahead_not(close_tag) |> parsec(:content_item))
    |> concat(ignore(close_tag))
    |> post_traverse({:build_tag_node, []})
  )

  defcombinatorp(:content_item, choice([parsec(:tag), text_node]))

  defparsec(:markup, repeat(parsec(:content_item)), inline: true)

  @doc false
  def validate_and_convert_color(rest, [name], context, _line, _offset) do
    atom = String.replace(name, "-", "_") |> String.to_atom()

    if atom in @valid_colors do
      {rest, [atom], context}
    else
      raise ArgumentError, "Unknown color: #{inspect(atom)}"
    end
  end

  @doc false
  def invalid_modifier_error(_rest, [char_code], _context, _line, _offset) do
    char = <<char_code::utf8>>
    raise ArgumentError, "Unknown modifier: #{char}"
  end

  @doc false
  def build_modifier_only_spec(rest, args, context, _line, _offset) do
    {rest, [{nil, Enum.reverse(args)}], context}
  end

  @doc false
  def build_tag_spec(rest, args, context, _line, _offset) do
    case Enum.reverse(args) do
      [color | modifiers] -> {rest, [{color, modifiers}], context}
      [] -> {:error, "Invalid tag specification"}
    end
  end

  @doc false
  def build_tag_node(rest, args, context, _line, _offset) do
    case Enum.reverse(args) do
      [tag_spec | content] ->
        {rest, [build_ast_node(tag_spec, content)], context}

      [] ->
        {:error, "Invalid tag node"}
    end
  end

  defp build_ast_node({nil, [:bold]}, content), do: {:bold, content}
  defp build_ast_node({nil, [:italic]}, content), do: {:italic, content}

  # First modifier in list is applied innermost
  defp build_ast_node({nil, modifiers}, content) when is_list(modifiers) do
    Enum.reduce(modifiers, content, fn
      :bold, inner when is_list(inner) -> {:bold, inner}
      :bold, inner -> {:bold, [inner]}
      :italic, inner when is_list(inner) -> {:italic, inner}
      :italic, inner -> {:italic, [inner]}
    end)
  end

  defp build_ast_node({color, []}, content) when is_atom(color) do
    {:color, color, content}
  end

  # Color innermost, modifiers wrap outside
  defp build_ast_node({color, modifiers}, content) when is_atom(color) do
    Enum.reduce(modifiers, {:color, color, content}, fn
      :bold, inner -> {:bold, [inner]}
      :italic, inner -> {:italic, [inner]}
    end)
  end

  @doc """
  Parse markup text into AST content.

  Returns `{:ok, content}` on success or `{:error, reason}` on failure.
  """
  def parse(text) when is_binary(text) do
    case markup(text) do
      {:ok, content, "", _context, _line, _offset} ->
        {:ok, content}

      {:ok, _content, rest, _context, {line, _col}, offset} ->
        {:error, "Unexpected content at line #{line}, offset #{offset}: #{inspect(rest)}"}

      {:error, reason, _rest, _context, {line, _col}, offset} ->
        {:error, "Parse error at line #{line}, offset #{offset}: #{reason}"}
    end
  end
end
