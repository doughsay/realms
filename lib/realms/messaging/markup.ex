defmodule Realms.Messaging.Markup do
  @moduledoc """
  Parses HTML-style markup into message AST.

  ## Syntax

  - `<color>text</>` - Colored text
  - `<b>text</>` - Bold text
  - `<i>text</>` - Italic text
  - `<color:b:i>text</>` - Combined modifiers

  ## Colors

  Use hyphenated names: red, blue, bright-yellow, gray-dark, etc.

  All 37 colors from the MUD palette are supported:
  - Grayscale: black, gray-dark, gray, gray-light, white
  - Base: red, green, yellow, blue, magenta, cyan, orange, purple
  - Bright: bright-red, bright-green, bright-yellow, etc.
  - Extended: teal, pink, lime, amber, indigo, violet, rose, emerald, sky, slate, brown

  ## Literal Characters

  The parser uses smart detection for `<` and `>` characters:
  - `<` followed by a letter or `/>` is treated as a tag
  - `<` followed by anything else is literal (e.g., `< 5`, `<3`, `<<`)
  - Use backslash escaping for edge cases: `\\<red>` → `<red>`

  ## Usage

      import Realms.Messaging.Markup

      Message.new([wrap("Hello <red>world</>")])

      Message.new([
        wrap("Description text"),
        pre("ASCII art")
      ])

  ## Examples

      # Simple colors
      wrap("Hello <red>world</>")

      # Bold and italic
      wrap("<b>Warning:</> Please <i>read carefully</>")

      # Combined modifiers
      wrap("<cyan:b>Important:</> <red:i>Danger!</>")

      # Nested tags
      wrap("<red>Red text with <b>bold red</> parts</>")

      # With string interpolation
      wrap("Welcome <cyan>\#{player.name}</>")

      # ASCII art
      pre(\"\"\"
           N
           |
       W---@---E
           |
           S
      \"\"\")
  """

  alias Realms.Messaging.Message

  # Token types used during parsing
  @typep token ::
           {:text, String.t()}
           | {:open_tag, color :: String.t() | nil, modifiers :: [atom()]}
           | {:close_tag}

  # Public API

  @doc """
  Parse markup for a word-wrapping section.

  Returns a section tuple that can be passed to Message.new/1.

  ## Examples

      wrap("Hello <red>world</>")
      # → {:pre_wrap, ["Hello ", {:color, :red, ["world"]}]}

      wrap(\"\"\"
      <bright-yellow:b>Title</>
      Some text
      \"\"\")
      # → {:pre_wrap, [
      #      {:color, :bright_yellow, [{:bold, ["Title"]}]},
      #      "\\nSome text"
      #    ]}
  """
  @spec wrap(String.t()) :: Message.section()
  def wrap(text) when is_binary(text) do
    {:pre_wrap, parse(text)}
  end

  @doc """
  Parse markup for a non-wrapping section (ASCII art, tables, etc).

  Returns a section tuple that can be passed to Message.new/1.

  ## Examples

      pre(\"\"\"
           N
           |
       W---@---E
           |
           S
      \"\"\")
      # → {:pre, ["     N\\n     |\\n W---@---E\\n     |\\n     S"]}
  """
  @spec pre(String.t()) :: Message.section()
  def pre(text) when is_binary(text) do
    {:pre, parse(text)}
  end

  # Parsing pipeline

  @spec parse(String.t()) :: Message.content()
  defp parse(text) do
    text
    |> trim_trailing_newline()
    |> tokenize()
    |> build_ast()
  end

  @spec trim_trailing_newline(String.t()) :: String.t()
  defp trim_trailing_newline(text) do
    # Only trim a single trailing newline (not all of them)
    if String.ends_with?(text, "\n") do
      String.slice(text, 0..-2//1)
    else
      text
    end
  end

  # Tokenizer

  @spec tokenize(String.t()) :: [token()]
  defp tokenize(text) do
    text
    |> scan_tokens(0, [])
    |> merge_adjacent_text()
  end

  # Merge adjacent {:text, _} tokens into single tokens
  @spec merge_adjacent_text([token()]) :: [token()]
  defp merge_adjacent_text([]), do: []

  defp merge_adjacent_text([{:text, text1}, {:text, text2} | rest]) do
    merge_adjacent_text([{:text, text1 <> text2} | rest])
  end

  defp merge_adjacent_text([token | rest]) do
    [token | merge_adjacent_text(rest)]
  end

  @spec scan_tokens(String.t(), non_neg_integer(), [token()]) :: [token()]
  defp scan_tokens(text, pos, acc) do
    # Check if we've reached the end
    if String.at(text, pos) == nil do
      Enum.reverse(acc)
    else
      scan_tokens_impl(text, pos, acc)
    end
  end

  defp scan_tokens_impl(text, pos, acc) do
    char = String.at(text, pos)

    cond do
      char == "<" ->
        # Check if it's a tag
        if tag_start?(text, pos) do
          {tag_token, new_pos} = scan_tag(text, pos)
          scan_tokens(text, new_pos, [tag_token | acc])
        else
          # Not a tag, include it as literal text and continue
          {text_token, new_pos} = scan_text_with_literal(text, pos)
          scan_tokens(text, new_pos, [text_token | acc])
        end

      char == "\\" ->
        # Backslash escape
        {text_token, new_pos} = scan_escape(text, pos)
        scan_tokens(text, new_pos, [text_token | acc])

      true ->
        {text_token, new_pos} = scan_text(text, pos)
        scan_tokens(text, new_pos, [text_token | acc])
    end
  end

  @spec tag_start?(String.t(), non_neg_integer()) :: boolean()
  defp tag_start?(text, pos) do
    # Smart detection: is this actually a tag?
    # Tag must be: <letter...> or </>
    next_char = String.at(text, pos + 1)

    cond do
      next_char == "/" ->
        # Could be closing tag </>
        String.at(text, pos + 2) == ">"

      next_char != nil and next_char =~ ~r/[a-z]/i ->
        # Starts with letter, looks like tag
        # Verify it has a closing > and valid syntax
        has_valid_tag_syntax?(text, pos)

      true ->
        # Anything else is literal
        false
    end
  end

  @spec has_valid_tag_syntax?(String.t(), non_neg_integer()) :: boolean()
  defp has_valid_tag_syntax?(text, pos) do
    # Extract potential tag content between < and >
    # Valid tag: <[a-z][a-z0-9-:]*>
    rest = String.slice(text, (pos + 1)..-1//1)

    case Regex.run(~r/^([a-z][a-z0-9-:]*?)>/, rest, return: :index) do
      [{0, _length} | _] -> true
      _ -> false
    end
  end

  @spec scan_tag(String.t(), non_neg_integer()) :: {token(), non_neg_integer()}
  defp scan_tag(text, pos) do
    # Extract tag from <...>
    rest = String.slice(text, (pos + 1)..-1//1)

    # Closing tag </>
    if String.starts_with?(rest, "/>") do
      {{:close_tag}, pos + 3}
    else
      # Opening tag
      case Regex.run(~r/^([a-z][a-z0-9-:]*?)>/, rest) do
        [full_match, tag_content] ->
          {color, modifiers} = parse_tag(tag_content)
          new_pos = pos + 1 + String.length(full_match)
          {{:open_tag, color, modifiers}, new_pos}

        nil ->
          raise "Malformed tag at position #{pos}"
      end
    end
  end

  @spec scan_text(String.t(), non_neg_integer()) :: {token(), non_neg_integer()}
  defp scan_text(text, pos) do
    # Extract text until next < or \ or end
    rest = String.slice(text, pos..-1//1)

    # Find the next occurrence of < or \
    next_special = find_next_special_grapheme(rest, 0)
    text_content = String.slice(rest, 0, next_special)
    {{:text, text_content}, pos + String.length(text_content)}
  end

  @spec scan_text_with_literal(String.t(), non_neg_integer()) :: {token(), non_neg_integer()}
  defp scan_text_with_literal(text, pos) do
    # When we know we're starting at a literal < (not a tag),
    # include it and scan until the next special character
    rest = String.slice(text, pos..-1//1)

    # Start from position 1 to skip the < we know is at position 0
    next_special = 1 + find_next_special_grapheme(String.slice(rest, 1..-1//1), 0)
    text_content = String.slice(rest, 0, next_special)
    {{:text, text_content}, pos + String.length(text_content)}
  end

  # Find the grapheme position of the next < or \ character
  @spec find_next_special_grapheme(String.t(), non_neg_integer()) :: non_neg_integer()
  defp find_next_special_grapheme(text, grapheme_pos) do
    # Safeguard against infinite loops - if we've scanned beyond reasonable length
    max_length = String.length(text)

    if grapheme_pos > max_length do
      raise "Parser error: infinite loop detected in find_next_special_grapheme (pos: #{grapheme_pos}, text length: #{max_length})"
    end

    case String.at(text, grapheme_pos) do
      nil -> grapheme_pos
      "<" -> grapheme_pos
      "\\" -> grapheme_pos
      _ -> find_next_special_grapheme(text, grapheme_pos + 1)
    end
  end

  @spec scan_escape(String.t(), non_neg_integer()) :: {token(), non_neg_integer()}
  defp scan_escape(text, pos) do
    # Handle backslash escapes: \<, \>, \\
    next_char = String.at(text, pos + 1)

    case next_char do
      "<" -> {{:text, "<"}, pos + 2}
      ">" -> {{:text, ">"}, pos + 2}
      "\\" -> {{:text, "\\"}, pos + 2}
      nil -> {{:text, "\\"}, pos + 1}
      _ -> {{:text, "\\"}, pos + 1}
    end
  end

  # AST builder

  @spec build_ast([token()]) :: Message.content()
  defp build_ast(tokens) do
    case build_content(tokens, []) do
      {content, []} ->
        content

      {_content, stack} ->
        raise "Unclosed tags: #{inspect(stack)}"
    end
  end

  @spec build_content([token()], list()) :: {Message.content(), [token()]}
  defp build_content([], _stack) do
    {[], []}
  end

  defp build_content([{:text, text} | rest], stack) do
    {content, remaining} = build_content(rest, stack)
    {[text | content], remaining}
  end

  defp build_content([{:open_tag, color_name, modifiers} | rest], stack) do
    # Build content until we find the closing tag
    {inner_content, remaining_tokens} = build_until_close(rest, stack)

    # Build the AST node
    node = build_node(color_name, modifiers, inner_content)

    # Continue with remaining tokens
    {content, final_remaining} = build_content(remaining_tokens, stack)
    {[node | content], final_remaining}
  end

  defp build_content([{:close_tag} | _rest], _stack) do
    raise "Unexpected closing tag </> with no matching opening tag"
  end

  @spec build_until_close([token()], list()) :: {Message.content(), [token()]}
  defp build_until_close([], _stack) do
    raise "Unclosed tag: missing </>"
  end

  defp build_until_close([{:close_tag} | rest], _stack) do
    # Found the closing tag, return accumulated content and remaining tokens
    {[], rest}
  end

  defp build_until_close([{:text, text} | rest], stack) do
    {content, remaining} = build_until_close(rest, stack)
    {[text | content], remaining}
  end

  defp build_until_close([{:open_tag, color_name, modifiers} | rest], stack) do
    # Nested tag - recursively build it
    {inner_content, after_close} = build_until_close(rest, stack)
    node = build_node(color_name, modifiers, inner_content)

    # Continue building until our close tag
    {content, remaining} = build_until_close(after_close, stack)
    {[node | content], remaining}
  end

  @spec build_node(String.t() | nil, [atom()], Message.content()) :: Message.content_node()
  defp build_node(nil, [:bold], content) do
    {:bold, content}
  end

  defp build_node(nil, [:italic], content) do
    {:italic, content}
  end

  defp build_node(color_name, [], content) when is_binary(color_name) do
    color_atom = color_name_to_atom(color_name)
    validate_color!(color_atom)
    {:color, color_atom, content}
  end

  defp build_node(color_name, modifiers, content) when is_binary(color_name) do
    # Wrap in color, then apply modifiers
    color_atom = color_name_to_atom(color_name)
    validate_color!(color_atom)

    node = {:color, color_atom, content}

    Enum.reduce(modifiers, node, fn
      :bold, inner -> {:bold, [inner]}
      :italic, inner -> {:italic, [inner]}
    end)
  end

  defp build_node(nil, modifiers, _content) when length(modifiers) > 1 do
    # Multiple modifiers without color (e.g., <b:i> - not valid in our syntax)
    raise ArgumentError, "Cannot combine modifiers without a color"
  end

  # Helper functions

  @spec parse_tag(String.t()) :: {String.t() | nil, [atom()]}
  defp parse_tag(tag_string) do
    # Parse tags like: "red", "b", "i", "red:b", "cyan:b:i"
    parts = String.split(tag_string, ":")

    case parts do
      ["b"] ->
        {nil, [:bold]}

      ["i"] ->
        {nil, [:italic]}

      [color_name | modifier_parts] when modifier_parts != [] ->
        modifiers = Enum.map(modifier_parts, &parse_modifier/1)
        {color_name, modifiers}

      [color_name] ->
        {color_name, []}
    end
  end

  @spec parse_modifier(String.t()) :: atom()
  defp parse_modifier("b"), do: :bold
  defp parse_modifier("i"), do: :italic

  defp parse_modifier(other) do
    raise ArgumentError, "Unknown modifier: #{other}"
  end

  @spec color_name_to_atom(String.t()) :: atom()
  defp color_name_to_atom(name) do
    name
    |> String.replace("-", "_")
    |> String.to_atom()
  end

  @spec validate_color!(atom()) :: :ok
  defp validate_color!(atom) do
    if atom not in valid_colors() do
      raise ArgumentError, "Unknown color: #{inspect(atom)}"
    end

    :ok
  end

  @spec valid_colors() :: [atom()]
  defp valid_colors do
    Message.valid_colors()
  end
end
