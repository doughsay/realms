defmodule Realms.Messaging.MarkupParser do
  @moduledoc """
  Parses markup language into Message segments.

  ## Syntax

  - `{color}text{/}` - Colored text
  - `{b}text{/}` - Bold text
  - `{i}text{/}` - Italic text
  - `{color:b:i}text{/}` - Combined attributes
  - `{{` - Literal `{` character

  ## Examples

      iex> parse("{red}Hello{/} world")
      {:ok, %Message{segments: [
        %{text: "Hello", color: :red, modifiers: []},
        %{text: " world", color: :white, modifiers: []}
      ]}}

  ## Color Names

  Use kebab-case matching atom names:
  - `red`, `bright-red`, `gray-light`, etc.
  - Maps to atoms: `:red`, `:bright_red`, `:gray_light`

  ## Nesting

  Inner tags inherit outer color if not specified.
  Modifiers accumulate from outer to inner tags.
  """

  alias Realms.Messaging.Message

  @type parse_result :: {:ok, Message.t()} | {:error, String.t()}

  @doc "Parse markup string into a Message"
  @spec parse(String.t()) :: parse_result()
  def parse(text) when is_binary(text) do
    case parse_segments(text) do
      {:ok, segments} -> {:ok, Message.new(segments)}
      {:error, _} = error -> error
    end
  end

  @doc "Parse markup string into segments (without Message wrapper)"
  @spec parse_segments(String.t()) :: {:ok, [Message.segment()]} | {:error, String.t()}
  def parse_segments(text) when is_binary(text) do
    with {:ok, tokens} <- tokenize(text) do
      build_segments(tokens)
    end
  end

  # Tokenization
  # Converts raw text into a list of tokens: {:text, str}, {:open, spec}, {:close}

  defp tokenize(text), do: tokenize(text, [], "")

  defp tokenize("", acc, ""), do: {:ok, acc}

  defp tokenize("", acc, current) do
    {:ok, acc ++ [{:text, current}]}
  end

  # Escape sequence: {{ becomes literal {
  defp tokenize("{{" <> rest, acc, current) do
    tokenize(rest, acc, current <> "{")
  end

  # Start of tag
  defp tokenize("{" <> rest, acc, current) do
    acc = if current == "", do: acc, else: acc ++ [{:text, current}]
    parse_tag(rest, acc)
  end

  # Regular character
  defp tokenize(<<char::utf8, rest::binary>>, acc, current) do
    tokenize(rest, acc, current <> <<char::utf8>>)
  end

  defp parse_tag("/" <> rest, acc) do
    # Closing tag
    case extract_until(rest, "}") do
      {:ok, "", after_brace} ->
        tokenize(after_brace, acc ++ [{:close}], "")

      {:ok, _, _} ->
        {:error, "Closing tag should be {/}, not {/...}"}

      :error ->
        {:error, "Unclosed tag: expected } after {/"}
    end
  end

  defp parse_tag(text, acc) do
    # Opening tag: extract spec until '}'
    case extract_until(text, "}") do
      {:ok, spec, rest} when spec != "" ->
        tokenize(rest, acc ++ [{:open, spec}], "")

      {:ok, "", _} ->
        {:error, "Empty tag: {} is not valid"}

      :error ->
        {:error, "Unclosed tag: expected }"}
    end
  end

  # Extract characters until delimiter, return {content, rest_after_delimiter}
  defp extract_until(text, delimiter), do: extract_until(text, delimiter, "")

  defp extract_until("", _delim, _acc), do: :error

  defp extract_until(text, delim, acc) do
    if String.starts_with?(text, delim) do
      rest = String.slice(text, String.length(delim)..-1//1)
      {:ok, acc, rest}
    else
      <<char::utf8, rest::binary>> = text
      extract_until(rest, delim, acc <> <<char::utf8>>)
    end
  end

  # Segment Building
  # Converts tokens into segments with color/modifier context

  defp build_segments(tokens) do
    # Start with default context (white, no modifiers)
    default_context = %{color: :white, modifiers: []}
    build_segments(tokens, [default_context], [])
  end

  defp build_segments([], [_default], acc), do: {:ok, acc}

  defp build_segments([], [_ | _], _acc) do
    {:error, "Unclosed tag: missing {/}"}
  end

  # Text token: create segment with current context
  defp build_segments([{:text, text} | rest], [ctx | _] = stack, acc) do
    segment = %{
      text: text,
      color: ctx.color,
      modifiers: ctx.modifiers
    }

    build_segments(rest, stack, acc ++ [segment])
  end

  # Open tag: parse spec and push new context
  defp build_segments([{:open, spec} | rest], [parent | _] = stack, acc) do
    case parse_spec(spec, parent) do
      {:ok, new_ctx} ->
        build_segments(rest, [new_ctx | stack], acc)

      {:error, _} = err ->
        err
    end
  end

  # Close tag: pop context
  defp build_segments([{:close} | rest], [_current, parent | rest_stack], acc) do
    build_segments(rest, [parent | rest_stack], acc)
  end

  defp build_segments([{:close} | _rest], [_only_default], _acc) do
    {:error, "Unexpected closing tag: no matching opening tag"}
  end

  # Parse tag specification into color and modifiers
  # Spec format: "color", "b", "i", "b:i", "color:b", "color:i", "color:b:i", etc.
  defp parse_spec(spec, parent_ctx) do
    parts = String.split(spec, ":")

    {color_part, modifier_parts} =
      case parts do
        [single] ->
          # Could be color or modifier
          case single do
            "b" -> {nil, ["b"]}
            "i" -> {nil, ["i"]}
            color -> {color, []}
          end

        [first | rest] ->
          # Check if first part is a modifier
          case first do
            "b" -> {nil, [first | rest]}
            "i" -> {nil, [first | rest]}
            color -> {color, rest}
          end
      end

    # Parse color (or inherit from parent)
    color =
      case color_part do
        nil ->
          parent_ctx.color

        color_str ->
          # Convert kebab-case to snake_case atom
          color_atom = color_str |> String.replace("-", "_") |> String.to_atom()

          # Validate it's a real color
          if valid_color?(color_atom) do
            color_atom
          else
            # Return error for invalid color
            throw({:invalid_color, color_str})
          end
      end

    # Parse modifiers and combine with parent modifiers
    new_modifiers =
      case parse_modifiers(modifier_parts) do
        {:ok, mods} -> Enum.uniq(parent_ctx.modifiers ++ mods)
        {:error, _} = err -> throw(err)
      end

    {:ok, %{color: color, modifiers: new_modifiers}}
  catch
    {:invalid_color, color_str} ->
      {:error, "Invalid color: #{color_str}"}

    {:error, _} = err ->
      err
  end

  defp parse_modifiers(modifier_parts) do
    modifiers =
      Enum.map(modifier_parts, fn
        "b" -> :bold
        "i" -> :italic
        other -> throw({:error, "Invalid modifier: #{other}"})
      end)

    {:ok, modifiers}
  catch
    {:error, _} = err -> err
  end

  # Validate color against known colors from assets/css/app.css
  defp valid_color?(color) do
    color in Message.valid_colors()
  end
end
