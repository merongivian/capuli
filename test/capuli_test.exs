defmodule CapuliTest do
  use ExUnit.Case

  setup_all do
    defmodule Parser do
      use Capuli

      element :title
      element :link, as: :url
      element :description
      element :"tag:withnamespace", as: :with_namespace
      element :"tag:with_namespace_and_dashes", as: :with_namespace_and_dashes
      element :withattributevalue, as: :with_attribute_value, value: :val
      element :withmatchedattributes, as: :with_matched_attributes, value: :val, with: [rel: "alternate", type: "text/html"]

      element :differenttagone, as: :repeated_element
      element :differenttagtwo, as: :repeated_element
      element :differenttagthree, as: :repeated_element
      element :image, module: CapuliTest.Parser.Image
      elements :item, as: :entries, module: CapuliTest.Parser.Entry

      defmodule Image do
        use Capuli

        element :title
      end

      defmodule Entry do
        use Capuli

        element :title
        element :link
        element :description
      end
    end

    xml = File.read! "test/fixtures/rss.xml"

    {:ok, rss: Parser.parse(xml)}
  end

  test "simple tags", %{rss: rss} do
    assert rss.title       == "W3Schools Home Page"
    assert rss.url         == "https://www.w3schools.com"
    assert rss.description == "Free web building tutorials"
  end

  test "tag with namespace", %{rss: rss} do
    assert rss.with_namespace == "with namespace"
  end

  test "replace _ with - when searching a tag with namespace", %{rss: rss} do
    assert rss.with_namespace_and_dashes == "with namespace and dashes"
  end

  test "selecting the tag that matches all the attributes search", %{rss: rss} do
    assert rss.with_matched_attributes == "with matched attributes"
  end

  test "tag with matched attributes", %{rss: rss} do
    assert rss.with_attribute_value  == "with attribute value"
  end

  test "picking the first declared element value when its defined multiple times", %{rss: rss} do
    assert rss.repeated_element == "first tag"
  end

  test "element with module", %{rss: rss} do
    assert rss.image.title == "image title"
  end

  test "multiple elements with module", %{rss: rss} do
    assert Enum.count(rss.entries) == 2
    assert List.first(rss.entries).title == "RSS Tutorial"
    assert List.last(rss.entries).description == "New XML tutorial on W3Schools"
  end
end
