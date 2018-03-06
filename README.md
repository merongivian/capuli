# Capuli

Declarative XML parsing library inspired by Ruby's [Sax Machine](https://github.com/pauldix/sax-machine), backed by Floki

This is used by [Feedraptor](https://github.com/merongivian/feedraptor) for parsing feeds (RSS, Atom, etc.)

## Examples

Add `use Capuli` in any module and define properties to parse:

```elixir
defmodule AtomEntry do
  use Capuli
  element :title
  # The :as argument makes this available through entry.author instead of entry.name
  element :name, as: :author
  # Element name is case insensitive, so it's not necessary to add the element name as feedburner:origLink
  element :"feedburner:origlink", as: :url
  element :published
end

defmodule Atom do
  use Capuli
  # The :with argument means that you only match a link tag
  # that has an attribute of type: "text/html"
  element :link, value: :href, as: :url, with: [
    type: "text/html"
  ]
  # The :value argument means that instead of setting the value
  # to the text between the tag, it sets it to the attribute value of :href
  element :link, value: :href, as: :feed_url, with: [
    type: "application/atom+xml"
  ]
  elements :entry, as: :entries, module: AtomEntry
end
```

Then parse any XML with your module:

```elixir
feed = Atom.parse(xml_text)

feed.title # Whatever the title of the blog is
feed.url # The main URL of the blog
feed.feed_url # The URL of the blog feed

List.first(feed.entries).title # Title of the first entry
List.first(feed.entries).author # The author of the first entry
List.first(feed.entries).url # Permalink on the blog for this entry
```

Multiple elements can be mapped to the same alias:

```elixir
defmodule RSSEntry do
  use Capuli
  # ...
  element :pubdate, as: :published
  element :"dc:date", as: :published
  element :"dcterms:created", as: :published
end
```

If more than one of these elements exists in the source, the value from the *first one* is used. The order of
the `element` declarations in the code is unimportant. The order they are encountered while parsing the
document determines the value assigned to the alias.

If an element is defined in the source but is blank (e.g., `<pubDate></pubDate>`), it is ignored, and non-empty one is picked.

## Installation

The package can be installed
by adding `capuli` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:capuli, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/capuli](https://hexdocs.pm/capuli).
