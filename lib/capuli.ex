defmodule Capuli do
  @moduledoc """
  Capuli parses xml files through a DSL defined in a module, this module will
  be the parser. Use `element` if you want to fetch one tag and `elements` for
  multiple tags.

  Here is a parser for an Atom entry:

      defmodule AtomEntry do
        use Capuli

        element :title
        element :description
        element :link, as: :url, value: :href, with: [
          type: "text/html"
        ]
        elements :images
      end

  You can use the `AtomEntry` inside other parsers as well:

      defmodule Atom do
        use Capuli

        element :link
        elements :entry, as: :entries, module: AtomEntry
      end

  ## Element(s) Options

    * `:as` - the key used for setting the name of the element

    * `:value` - retrieves the value from an specific attribute, it
      takes the value from the tag by default

    * `:with` - search tags with specific attributes, the tag
      must have all attributes

    * `:module` - used for parsing the extracted value

  Capuli sets a `parse` method that is used for processing the xml:

      xml = "<rss>.....<rss>"
      Atom.parse(xml)
  """

  @doc false
  defmacro __using__(_) do
    quote do
      import Capuli, only: [element: 2, element: 1, elements: 2, elements: 1]
      @before_compile Capuli

      Module.register_attribute(__MODULE__, :element_definitions, accumulate: true)
      Module.register_attribute(__MODULE__, :elements_definitions, accumulate: true)
    end
  end

  @doc false
  defmacro __before_compile__(_env) do
    quote do
      @doc false
      def parse(source) do
        parsed_element_definitions =
         Capuli.execute_definitions(
            source,
            @element_definitions,
            :get_element
          )

        parsed_elements_definitions =
          Capuli.execute_definitions(
            source,
            @elements_definitions,
            :get_elements
          )

        Map.merge(
          parsed_element_definitions,
          parsed_elements_definitions
        )
      end
    end
  end

  @doc """
  Defines the element that will be extracted

  ## Options

  `:as`, `:value`, `:with`, `module`

  See the "Element(s) options" section at the module documentation for more info.
  """
  defmacro element(name, opts \\ []) do
    quote bind_quoted: [name: name, opts: opts] do
      Module.put_attribute(__MODULE__, :element_definitions, [name, opts])
    end
  end

  @doc """
  Defines the element that will be extracted

  ## Options

  `:as`, `:value`, `:with`, `module`

  See the "Element(s) options" section at the module documentation for more info.
  """
  defmacro elements(name, opts \\ []) do
    quote bind_quoted: [name: name, opts: opts] do
      Module.put_attribute(__MODULE__, :elements_definitions, [name, opts])
    end
  end

  @doc false
  def execute_definitions(source, definitions, extractor) do
    Enum.reduce definitions, %{}, fn(extractor_attributes, parsed_source) ->
      extracted_element = apply(
        __MODULE__,
        extractor,
        [source | extractor_attributes]
      )

      key = extracted_element
            |> Map.keys
            |> List.first

      case extracted_element do
        %{^key => nil} -> parsed_source
        %{^key => ""}  -> parsed_source
        %{^key => []}  -> parsed_source
        _              -> Map.merge(parsed_source, extracted_element)
      end
    end
  end

  @doc false
  def get_element(source, name, opts \\ []) do
    value = get_element_value(source, name, Keyword.drop(opts, [:as]))
    %{opts[:as] || name => value}
  end

  @doc false
  def get_elements(source, name, opts \\ []) do
    get_values = fn(parsed_elements, opts) ->
      if opts[:module] do
        Enum.map(parsed_elements, &opts[:module].parse/1)
      else
        Enum.map(parsed_elements, & value_extractor(&1, opts))
      end
    end

    name = Atom.to_string(name)
    values = source
             |> Floki.find(create_selector(name, opts[:with]))
             |> get_values.(opts)

    %{opts[:as] => values}
  end

  defp get_element_value(source, name, opts) do
    name = Atom.to_string(name)

    try_exact_find = fn(source, name) ->
      if is_list(source) and Enum.count(source) > 1 do
        Enum.find(source, &(elem(&1, 0) == name))
      else
        source
      end
    end

    value = source
            |> Floki.find(create_selector(name, opts[:with]))
            # NOTE: floki.find sometimes returns more than one value
            # for example when theres another node with the same name
            # but with a namespace
            |> try_exact_find.(name)
            |> value_extractor(opts)

    if opts[:module], do: opts[:module].parse(value), else: value
  end

  defp value_extractor(value, opts) do
    if opts[:value] do
      value
      |> Floki.attribute(Atom.to_string opts[:value])
      |> List.first()
    else
      value_matcher(value)
    end
  end

  defp value_matcher([{_, _, [value]}]), do: value
  defp value_matcher({_, _, [value]}), do: value
  defp value_matcher({_, _, value}) when is_list(value), do: value
  defp value_matcher(value), do: value

  defp create_selector(name, attributes) do
    name = name
           |> String.replace(":", "|")
           |> String.replace("_", "-")

    name <> create_attributes_selector(attributes)
  end

  defp create_attributes_selector(attributes)
  defp create_attributes_selector(nil), do: ""
  defp create_attributes_selector(attributes) do
    Enum.reduce attributes, "", fn({name, value}, selector) ->
      selector <> ~s([#{name}="#{value}"])
    end
  end
end
