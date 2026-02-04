defmodule Realms.Messaging.Banner do
  @moduledoc """
  Module for generating MUD-style banners.
  """

  import Realms.Messaging.Markup

  alias Realms.Messaging.Message

  def banner do
    Message.new([
      pre("""
      #{center_within("<bright-yellow:b>Welcome to...</>", 81)}

                <violet>@@@@@@@ </> <purple> @@@@@@@@</>  <indigo> @@@@@@ </> <blue> @@@     </>  <cyan>@@@@@@@@@@ </> <teal>  @@@@@@ </>
                <violet>@@@@@@@@</> <purple> @@@@@@@@</>  <indigo>@@@@@@@@</> <blue> @@@     </>  <cyan>@@@@@@@@@@@</> <teal> @@@@@@@ </>
                <violet>@@!  @@@</> <purple> @@!     </>  <indigo>@@!  @@@</> <blue> @@!     </>  <cyan>@@! @@! @@!</> <teal> !@@     </>
                <violet>!@!  @!@</> <purple> !@!     </>  <indigo>!@!  @!@</> <blue> !@!     </>  <cyan>!@! !@! !@!</> <teal> !@!     </>
                <violet>@!@!!@! </> <purple> @!!!:!  </>  <indigo>@!@!@!@!</> <blue> @!!     </>  <cyan>@!! !!@ @!@</> <teal> !!@@!!  </>
                <violet>!!@!@!  </> <purple> !!!!!:  </>  <indigo>!!!@!!!!</> <blue> !!!     </>  <cyan>!@!   ! !@!</> <teal>  !!@!!! </>
                <violet>!!: :!! </> <purple> !!:     </>  <indigo>!!:  !!!</> <blue> !!:     </>  <cyan>!!:     !!:</> <teal>      !:!</>
                <violet>:!:  !:!</> <purple> :!:     </>  <indigo>:!:  !:!</> <blue>  :!:    </>  <cyan>:!:     :!:</> <teal>     !:! </>
                <violet>::   :::</> <purple>  :: ::::</>  <indigo>::   :::</> <blue>  :: ::::</>  <cyan>:::     :: </> <teal> :::: :: </>
                <violet>:   : : </> <purple>: :: ::  </>  <indigo>:   : : </> <blue>: :: : : </>  <cyan>:      :   </> <teal>:: : :   </>

      #{subtitle() |> center_within(81)}


      """)
    ])
  end

  # Private helpers

  defp subtitle do
    "<b>REALMS</>: #{random_r_word()} #{random_e_word()} #{random_a_word()} #{random_l_word()} #{random_m_word()} #{random_s_word()}"
  end

  # This describes the engine's capabilities.
  # Stick to performance-based adjectives.
  defp random_r_word do
    Enum.random([
      "Radiant",
      "Reactive",
      "Real-time",
      "Remote",
      "Robust"
    ])
    |> bold_first_letter()
  end

  # Proper noun. This is your anchor. It acts as the subject of the description.
  defp random_e_word do
    Enum.random([
      "Elixir"
    ])
    |> bold_first_letter()
  end

  # Noun-as-Adjective. It describes the type of Elixir system you are building.
  defp random_a_word do
    Enum.random([
      "Actor",
      "Alchemical",
      "Application",
      "Archive"
    ])
    |> bold_first_letter()
  end

  # Adjective or Participle. This describes the state or the "feel" of the
  # world.
  defp random_l_word do
    Enum.random([
      "Latent",
      "Layered",
      "Linked",
      "Live",
      "Logic",
      "Lucid"
    ])
    |> bold_first_letter()
  end

  # Noun. This defines the genre.
  defp random_m_word do
    Enum.random([
      "MUD"
    ])
    |> bold_first_letter()
  end

  # Noun. This is the "Base Class." It must be a structural noun.
  defp random_s_word do
    Enum.random([
      "Server",
      "Simulation",
      "Simulator",
      "Socket",
      "Software",
      "Suite",
      "System"
    ])
    |> bold_first_letter()
  end

  defp bold_first_letter(<<first::utf8, rest::binary>>) do
    "<b>#{<<first::utf8>>}</>#{rest}"
  end

  defp center_within(text, width) do
    text_length = String.length(strip_markup(text))

    if text_length >= width do
      text
    else
      total_padding = width - text_length
      left_padding = div(total_padding, 2)

      String.duplicate(" ", left_padding) <> text
    end
  end

  defp strip_markup(text) do
    Regex.replace(~r/<[^>]+>/, text, "")
  end
end
