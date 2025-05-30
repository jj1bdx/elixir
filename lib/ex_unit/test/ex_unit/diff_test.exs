# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2021 The Elixir Team
# SPDX-FileCopyrightText: 2012 Plataformatec

Code.require_file("../test_helper.exs", __DIR__)

defmodule ExUnit.DiffTest do
  use ExUnit.Case, async: true

  alias Inspect.Algebra
  alias ExUnit.{Assertions, Diff}

  defmodule User do
    defstruct [:name, :age]
  end

  defmodule Customer do
    defstruct [:address, :age, :first_name, :language, :last_name, :notifications]
  end

  defmodule Person do
    defstruct [:age]
  end

  defmodule Opaque do
    defstruct [:data]

    defimpl Inspect do
      def inspect(%{data: data}, _) when is_tuple(data) or is_map(data),
        do: "#Opaque<data: #{inspect(data)}>"

      def inspect(_, _),
        do: "#Opaque<???>"
    end
  end

  defmodule HTML do
    defstruct [:string]

    defimpl Inspect do
      def inspect(%{string: string}, _) do
        "~HTML[#{string}]"
      end
    end
  end

  defmacro sigil_HTML({:<<>>, _, [string]}, []) do
    Macro.escape(%HTML{string: string})
  end

  defmacrop one, do: 1

  defmacrop tuple(a, b) do
    quote do
      {unquote(a), unquote(b)}
    end
  end

  defmacrop pin_x do
    x = Macro.var(:x, nil)
    quote(do: ^unquote(x))
  end

  defmacrop block_head({:__block__, _, [head | _]}) do
    head
  end

  defmacrop assert_diff(expr, expected_binding, pins \\ [])

  defmacrop assert_diff({:=, _, [left, right]}, expected_binding, pins) do
    left = Assertions.__expand_pattern__(left, __CALLER__) |> Macro.escape()

    quote do
      assert_diff(
        unquote(left),
        unquote(right),
        unquote(expected_binding),
        {:match, unquote(pins)}
      )
    end
  end

  defmacrop assert_diff({op, _, [left, right]}, [], []) when op in [:==, :===] do
    quote do
      assert_diff(unquote(left), unquote(right), [], unquote(op))
    end
  end

  defmacrop refute_diff(expr, expected_left, expected_right, pins \\ [])

  defmacrop refute_diff({:=, _, [left, right]}, expected_left, expected_right, pins) do
    left = Assertions.__expand_pattern__(left, __CALLER__) |> Macro.escape()

    quote do
      refute_diff(
        unquote(left),
        unquote(right),
        unquote(expected_left),
        unquote(expected_right),
        {:match, unquote(pins)}
      )
    end
  end

  defmacrop refute_diff({op, _, [left, right]}, expected_left, expected_right, [])
            when op in [:==, :===] do
    quote do
      refute_diff(
        unquote(left),
        unquote(right),
        unquote(expected_left),
        unquote(expected_right),
        unquote(op)
      )
    end
  end

  defp refute_diff(left, right, expected_left, expected_right, context) do
    {diff, _env} = Diff.compute(left, right, context)
    assert diff.equivalent? == false

    diff_left = to_diff(diff.left, "-")
    assert diff_left =~ expected_left

    diff_right = to_diff(diff.right, "+")
    assert diff_right =~ expected_right
  end

  defp assert_diff(left, right, expected_binding, context) do
    {diff, env} = Diff.compute(left, right, context)
    env_binding = for {{name, _}, value} <- env.current_vars, do: {name, value}

    assert diff.equivalent? == true
    assert env_binding == expected_binding
  end

  @terminal_width 80
  defp to_diff(side, sign) do
    side
    |> Diff.to_algebra(&diff_wrapper(&1, sign))
    |> Algebra.format(@terminal_width)
    |> IO.iodata_to_binary()
  end

  defp diff_wrapper(doc, side) do
    Algebra.concat([side, doc, side])
  end

  test "atoms" do
    assert_diff(:a = :a, [])
    assert_diff(:a = :a, [])
    assert_diff(:"$a" = :"$a", [])

    refute_diff(:a = :b, "-:a-", "+:b+")
    refute_diff(:a = :aa, "-:a-", "+:aa+")

    refute_diff(:"$" = :"$a", ~s[-:"$"-], ~s[+:"$a"+])
    refute_diff(:"$a" = :"$b", ~s[-:"$a"-], ~s[+:"$b"+])

    refute_diff(:bar = 42, "-:bar-", "+42+")
    refute_diff(42 = :bar, "-42-", "+:bar+")

    pins = %{{:a, nil} => :a, {:b, nil} => :b}
    assert_diff(x = :a, [x: :a], pins)
    assert_diff(^a = :a, [], pins)
    assert_diff(^b = :b, [], pins)

    refute_diff(^a = :b, "-^a-", "+:b+", pins)
    refute_diff(^b = :a, "-^b-", "+:a+", pins)
  end

  test "pseudo vars" do
    assert_diff(__MODULE__ = ExUnit.DiffTest, [])
    refute_diff(__MODULE__ = SomethingElse, "-ExUnit.DiffTest-", "+SomethingElse+")
  end

  test "integers" do
    assert_diff(123 = 123, [])
    assert_diff(-123 = -123, [])
    assert_diff(123 = +123, [])
    assert_diff(+123 = 123, [])

    refute_diff(12 = 13, "1-2-", "1+3+")
    refute_diff(12345 = 123, "123-45-", "123")
    refute_diff(123 = 12345, "123", "123+45+")
    refute_diff(12345 = 345, "-12-345", "345")
    refute_diff(345 = 12345, "345", "+12+345")
    refute_diff(123 = -123, "123", "+-+123")
    refute_diff(-123 = 123, "---123", "123")
    refute_diff(491_512_235 = 490_512_035, "49-1-512-2-35", "49+0+512+0+35")

    assert_diff(0xF = 15, [])
    refute_diff(0xF = 16, "1-5-", "1+6+")
    refute_diff(123 = :a, "-123-", "+:a+")
  end

  test "floats" do
    assert_diff(123.0 = 123.0, [])
    assert_diff(-123.0 = -123.0, [])
    assert_diff(123.0 = +123.0, [])
    assert_diff(+123.0 = 123.0, [])

    refute_diff(1.2 = 1.3, "1.-2-", "1.+3+")
    refute_diff(12.345 = 12.3, "12.3-45-", "12.3")
    refute_diff(12.3 = 12.345, "12.3", "12.3+45+")
    refute_diff(123.45 = 3.45, "-12-3.45", "3.45")
    refute_diff(3.45 = 123.45, "3.45", "+12+3.45")
    refute_diff(1.23 = -1.23, "1.23", "+-+1.23")
    refute_diff(-1.23 = 1.23, "---1.23", "1.23")
    refute_diff(123.0 = :a, "-123.0-", "+:a+")
    refute_diff(123.0 = 123_512_235, "-123.0-", "+123512235+")
  end

  test "== / ===" do
    refute_diff(
      %{a: 1, b: 2} == %{a: 1.0, b: :two},
      "%{a: 1, b: -2-}",
      "%{a: 1.0, b: +:two+}"
    )

    refute_diff(
      %{a: 1, b: 2} === %{a: 1.0, b: :two},
      "%{a: -1-, b: -2-}",
      "%{a: +1.0+, b: +:two+}"
    )
  end

  test "lists" do
    assert_diff([] = [], [])

    assert_diff([:a] = [:a], [])
    assert_diff([:a, :b, :c] = [:a, :b, :c], [])

    refute_diff([] = [:a], "[]", "[+:a+]")
    refute_diff([:a] = [], "[-:a-]", "[]")
    refute_diff([:a] = [:b], "[-:a-]", "[+:b+]")
    refute_diff([:a, :b, :c] = [:a, :b, :x], "[:a, :b, -:c-]", "[:a, :b, +:x+]")
    refute_diff([:a, :x, :c] = [:a, :b, :c], "[:a, -:x-, :c]", "[:a, +:b+, :c]")
    refute_diff([:a, :d, :b, :c] = [:a, :b, :c, :d], "[:a, -:d-, :b, :c]", "[:a, :b, :c, +:d+]")
    refute_diff([:b, :c] = [:a, :b, :c], "[:b, :c]", "[+:a+, :b, :c]")

    refute_diff([:a, :b, :c] = [:a, :b, []], "[:a, :b, -:c-]", "[:a, :b, +[]+]")
    refute_diff([:a, :b, []] = [:a, :b, :c], "[:a, :b, -[]-]", "[:a, :b, +:c+]")
    refute_diff([:a, :b, :c] = [:a, :b], "[:a, :b, -:c-]", "[:a, :b]")
    refute_diff([:a, :b] = [:a, :b, :c], "[:a, :b]", "[:a, :b, +:c+]")
    refute_diff([:a, :b, :c, :d, :e] = [:a, :b], "[:a, :b, -:c-, -:d-, -:e-]", "[:a, :b]")
    refute_diff([:a, :b] = [:a, :b, :c, :d, :e], "[:a, :b]", "[:a, :b, +:c+, +:d+, +:e+]")

    refute_diff(
      [:a, [:d, :b, :c]] = [:a, [:b, :c, :d]],
      "[:a, [-:d-, :b, :c]]",
      "[:a, [:b, :c, +:d+]]"
    )

    refute_diff(
      [:e, :a, :b, :c, :d] = [:a, :b, :c, :d, :e],
      "[-:e-, :a, :b, :c, :d]",
      "[:a, :b, :c, :d, +:e+]"
    )

    refute_diff([:a, [:c, :b]] = [:a, [:b, :c]], "[:a, [-:c-, :b]]", "[:a, [:b, +:c+]]")
    refute_diff(:a = [:a, [:b, :c]], "-:a-", "+[:a, [:b, :c]]+")

    pins = %{
      {:a, nil} => :a,
      {:b, nil} => :b,
      {:list_ab, nil} => [:a, :b],
      {:list_tuple, nil} => [{:foo}]
    }

    assert_diff(x = [], [x: []], pins)
    assert_diff(x = [:a, :b], [x: [:a, :b]], pins)
    assert_diff([x] = [:a], [x: :a], pins)
    assert_diff([x, :b, :c] = [:a, :b, :c], [x: :a], pins)
    assert_diff([x, y, z] = [:a, :b, :c], [x: :a, y: :b, z: :c], pins)
    assert_diff([x, x, :c] = [:a, :a, :c], [x: :a], pins)

    refute_diff([x] = [], "[-x-]", "[]")
    refute_diff([x, :b, :c] = [:a, :b, :x], "[x, :b, -:c-]", "[:a, :b, +:x+]")
    refute_diff([x, x, :c] = [:a, :b, :c], "[x, -x-, :c]", "[:a, +:b+, :c]")

    assert_diff(^list_ab = [:a, :b], [], pins)
    assert_diff([^a, :b, :c] = [:a, :b, :c], [], pins)
    assert_diff([^a, ^b, :c] = [:a, :b, :c], [], pins)
    assert_diff([^a, a, :c] = [:a, :b, :c], [a: :b], pins)
    assert_diff([b, ^b, :c] = [:a, :b, :c], [b: :a], pins)

    refute_diff(^list_ab = [:x, :b], "-^list_ab-", "[+:x+, :b]", pins)
    refute_diff([^a, :b, :c] = [:a, :b, :x], "[^a, :b, -:c-]", "[:a, :b, +:x+]", pins)
    refute_diff([:a, ^a, :c] = [:a, :b, :c], "[:a, -^a-, :c]", "[:a, +:b+, :c]", pins)

    refute_diff(
      [x, :a, :b, :c, :d] = [:a, :b, :c, :d, :e],
      "[x, -:a-, :b, :c, :d]",
      "[:a, :b, :c, :d, +:e+]"
    )

    refute_diff([:a, :b] = :a, "-[:a, :b]-", "+:a+")
    refute_diff([:foo] = [:foo, {:a, :b, :c}], "[:foo]", "[:foo, +{:a, :b, :c}+]")

    refute_diff([{:foo}] = [{:bar}], "[{-:foo-}]", "[{+:bar+}]")
    refute_diff(^list_tuple = [{:bar}], "-^list_tuple-", "[{+:bar+}]", pins)
  end

  test "improper lists" do
    assert_diff([:a | :b] = [:a | :b], [])
    assert_diff([:a, :b | :c] = [:a, :b | :c], [])

    refute_diff([:a | :b] = [:b | :a], "[-:a- | -:b-]", "[+:b+ | +:a+]")
    refute_diff([:a | :b] = [:a | :x], "[:a | -:b-]", "[:a | +:x+]")
    refute_diff([:a, :b | :c] = [:a, :b | :x], "[:a, :b | -:c-]", "[:a, :b | +:x+]")
    refute_diff([:a, :x | :c] = [:a, :b | :c], "[:a, -:x- | :c]", "[:a, +:b+ | :c]")
    refute_diff([:x, :b | :c] = [:a, :b | :c], "[-:x-, :b | :c]", "[+:a+, :b | :c]")
    refute_diff([:c, :a | :b] = [:a, :b | :c], "[-:c-, :a | -:b-]", "[:a, +:b+ | +:c+]")

    refute_diff(
      [:a, :c, :x | :b] = [:a, :b, :c | :d],
      "[:a, :c, -:x- | -:b-]",
      "[:a, +:b+, :c | +:d+]"
    )

    refute_diff([:a | :d] = [:a, :b, :c | :d], "[:a | -:d-]", "[:a, +:b+, +:c+ | +:d+]")

    refute_diff(
      [[:a | :x], :x | :d] = [[:a | :b], :c | :d],
      "[[:a | -:x-], -:x- | :d]",
      "[[:a | +:b+], +:c+ | :d]"
    )

    assert_diff([:a | x] = [:a | :b], x: :b)

    refute_diff(
      [[[[], "Hello, "] | "world"] | "!"] ==
        [[[[], "Hello "] | "world"] | "!"],
      "[[[[], \"Hello-,- \"] | \"world\"] | \"!\"]",
      "[[[[], \"Hello \"] | \"world\"] | \"!\"]"
    )

    refute_diff(:foo = %{bar: [:a | :b]}, "", "")
  end

  test "proper lists" do
    assert_diff([:a | [:b]] = [:a, :b], [])
    assert_diff([:a | [:b, :c]] = [:a, :b, :c], [])

    refute_diff([:a | [:b]] = [:a, :x], "[:a | [-:b-]]", "[:a, +:x+]")

    refute_diff([:a, :b | [:c]] = [:a, :b, :x], "[:a, :b | [-:c-]]", "[:a, :b, +:x+]")
    refute_diff([:a, :x | [:c]] = [:a, :b, :c], "[:a, -:x- | [:c]]", "[:a, +:b+, :c]")
    refute_diff([:a | [:b, :c]] = [:a, :b, :x], "[:a | [:b, -:c-]]", "[:a, :b, +:x+]")
    refute_diff([:a | [:b, :c]] = [:x, :b, :c], "[-:a- | [:b, :c]]", "[+:x+, :b, :c]")

    refute_diff(
      [:a, :c, :x | [:b, :c]] = [:a, :b, :c, :d, :e],
      "[:a, -:c-, -:x- | [:b, :c]]",
      "[:a, :b, :c, +:d+, +:e+]"
    )

    refute_diff([:a, :b | [:c]] = [:a, :b], "[:a, :b | [-:c-]]", "[:a, :b]")
    refute_diff([:a, :b | []] = [:a, :b, :c], "[:a, :b | []]", "[:a, :b, +:c+]")
    refute_diff([:a, :b | [:c, :d]] = [:a, :b, :c], "[:a, :b | [:c, -:d-]]", "[:a, :b, :c]")
    refute_diff([:a, :b | [:c, :d]] = [:a], "[:a, -:b- | [-:c-, -:d-]]", "[:a]")

    refute_diff(
      [:a, [:b, :c] | [:d, :e]] = [:a, [:x, :y], :d, :e],
      "[:a, [-:b-, -:c-] | [:d, :e]]",
      "[:a, [+:x+, +:y+], :d, :e]"
    )

    refute_diff(
      [:a, [:b, :c] | [:d, :e]] = [:a, [:x, :c], :d, :e],
      "[:a, [-:b-, :c] | [:d, :e]]",
      "[:a, [+:x+, :c], :d, :e]"
    )

    assert_diff([:a | x] = [:a, :b], x: [:b])
    assert_diff([:a | x] = [:a, :b, :c], x: [:b, :c])
    assert_diff([:a | x] = [:a, :b | :c], x: [:b | :c])

    pins = %{{:list_bc, nil} => [:b, :c]}
    assert_diff([:a | ^list_bc] = [:a, :b, :c], [], pins)
    refute_diff([:a | ^list_bc] = [:x, :x, :c], "[-:a- | -^list_bc-]", "[+:x+, +:x+, :c]", pins)
    refute_diff([:a | ^list_bc] = [:a, :x, :c], "[:a | -^list_bc-]", "[:a, +:x+, :c]", pins)
  end

  test "concat lists" do
    assert_diff([:a] ++ [:b] = [:a, :b], [])
    assert_diff([:a, :b] ++ [] = [:a, :b], [])
    assert_diff([] ++ [:a, :b] = [:a, :b], [])

    refute_diff([:a, :b] ++ [:c] = [:a, :b], "[:a, :b] ++ [-:c-]", "[:a, :b]")
    refute_diff([:a, :c] ++ [:b] = [:a, :b], "[:a, -:c-] ++ [:b]", "[:a, :b]")
    refute_diff([:a] ++ [:b] ++ [:c] = [:a, :b], "[:a] ++ [:b] ++ [-:c-]", "[:a, :b]")

    assert_diff([:a] ++ :b = [:a | :b], [])
    assert_diff([:a] ++ x = [:a, :b], x: [:b])

    refute_diff([:a, :b] ++ :c = [:a, :b, :c], "[:a, :b] ++ -:c-", "[:a, :b, +:c+]")
    refute_diff([:a] ++ [:b] ++ :c = [:a, :b, :c], "[:a] ++ [:b] ++ -:c-", "[:a, :b, +:c+]")
    refute_diff([:a] ++ [:b] = :a, "-[:a] ++ [:b]-", "+:a+")
  end

  @a [:a]
  test "concat lists with module attributes" do
    assert_diff(@a ++ [:b] = [:a, :b], [])
    refute_diff(@a ++ [:b] = [:a], "[:a] ++ [-:b-]", "[:a]")
    refute_diff(@a ++ [:b] = [:b], "[-:a-] ++ [:b]", "[:b]")
  end

  test "mixed lists" do
    refute_diff([:a | :b] = [:a, :b], "[:a | -:b-]", "[:a, +:b+]")
    refute_diff([:a, :b] = [:a | :b], "[:a, -:b-]", "[:a | +:b+]")
    refute_diff([:a | [:b]] = [:a | :b], "[:a | -[:b]-]", "[:a | +:b+]")
    refute_diff([:a | [:b | [:c]]] = [:a | :c], "[:a | -[:b | [:c]]-]", "[:a | +:c+]")
    refute_diff([:a | :b] = [:a, :b, :c], "[:a | -:b-]", "[:a, +:b+, +:c+]")
    refute_diff([:a, :b, :c] = [:a | :b], "[:a, -:b-, -:c-]", "[:a | +:b+]")

    refute_diff([:a | [:b] ++ [:c]] = [:a, :b], "[:a | [:b] ++ [-:c-]]", "[:a, :b]")

    refute_diff(
      [:a | [:b] ++ [:c]] ++ [:d | :e] = [:a, :b | :e],
      "[:a | [:b] ++ [-:c-]] ++ [-:d- | :e]",
      "[:a, :b | :e]"
    )
  end

  test "lists outside of match context" do
    refute_diff(
      [%_{i_will: :fail}, %_{i_will: :fail_too}] = [],
      "[-%_{i_will: :fail}-, -%_{i_will: :fail_too}-]",
      "[]"
    )

    refute_diff(
      [:a, {:|, [], [:b, :c]}] == [:a, :b | :c],
      "[:a, -{:|, [], [:b, :c]}-]",
      "[:a, +:b+ | +:c+]"
    )

    refute_diff([:foo] == [:foo, {:a, :b, :c}], "[:foo]", "[:foo, +{:a, :b, :c}+]")
    refute_diff([:foo, {:a, :b, :c}] == [:foo], "[:foo, -{:a, :b, :c}-]", "[:foo]")

    refute_diff([:foo] == [:foo | {:a, :b, :c}], "[:foo]", "[:foo | +{:a, :b, :c}+]")
    refute_diff([:foo | {:a, :b, :c}] == [:foo], "[:foo | -{:a, :b, :c}-]", "[:foo]")
    refute_diff([:foo] == [{:a, :b, :c} | :foo], "[-:foo-]", "[+{:a, :b, :c}+ | +:foo+]")
    refute_diff([{:a, :b, :c} | :foo] == [:foo], "[-{:a, :b, :c}- | -:foo-]", "[+:foo+]")
  end

  test "keyword lists" do
    assert_diff([file: "nofile", line: 1] = [file: "nofile", line: 1], [])

    refute_diff(
      [file: "nofile", line: 1] = [file: nil, lime: 1],
      ~s/[file: -"nofile"-, -line:- 1]/,
      "[file: +nil+, +lime:+ 1]"
    )

    refute_diff(
      [file: nil, line: 1] = [file: "nofile"],
      "[file: -nil-, -line: 1-]",
      ~s/[file: +"nofile"+]/
    )

    refute_diff(
      ["foo-bar": 1] = [],
      ~s/[-"foo-bar": 1-]/,
      "[]"
    )

    refute_diff(
      [file: nil] = [{:line, 1}, {1, :foo}],
      "[-file:- -nil-]",
      "[{+:line+, +1+}, +{1, :foo}+]"
    )
  end

  test "tuples" do
    assert_diff({:a, :b} = {:a, :b}, [])

    refute_diff({:a, :b} = {:a, :x}, "{:a, -:b-}", "{:a, +:x+}")
    refute_diff({:a, :b} = {:x, :x}, "{-:a-, -:b-}", "{+:x+, +:x+}")
    refute_diff({:a, :b, :c} = {:a, :b, :x}, "{:a, :b, -:c-}", "{:a, :b, +:x+}")

    refute_diff({:a} = {:a, :b}, "{:a}", "{:a, +:b+}")
    refute_diff({:a, :b} = {:a}, "{:a, -:b-}", "{:a}")

    refute_diff({:ok, value} = {:error, :fatal}, "{-:ok-, value}", "{+:error+, :fatal}")
    refute_diff({:a, :b} = :a, "-{:a, :b}-", "+:a+")

    refute_diff({:foo} = {:foo, {:a, :b, :c}}, "{:foo}", "{:foo, +{:a, :b, :c}+}")
  end

  test "tuples outside of match context" do
    assert_diff({:a, :b} == {:a, :b}, [])

    refute_diff({:a} == {:a, :b}, "{:a}", "{:a, +:b+}")
    refute_diff({:a, :b} == {:a}, "{:a, -:b-}", "{:a}")

    refute_diff({:{}, [], [:a]} == {:a}, "{-:{}-, -[]-, -[:a]-}", "{+:a+}")
    refute_diff({:{}, [], [:a]} == :a, "-{:{}, [], [:a]}-", "+:a+")
    refute_diff({:a, :b, :c} == {:a, :b, :x}, "{:a, :b, -:c-}", "{:a, :b, +:x+}")

    refute_diff({:foo} == {:foo, {:a, :b, :c}}, "{:foo}", "{:foo, +{:a, :b, :c}+}")
    refute_diff({:foo, {:a, :b, :c}} == {:foo}, "{:foo, -{:a, :b, :c}-}", "{:foo}")
  end

  test "maps" do
    assert_diff(%{a: 1} = %{a: 1}, [])
    assert_diff(%{a: 1} = %{a: 1, b: 2}, [])
    assert_diff(%{a: 1, b: 2} = %{a: 1, b: 2}, [])
    assert_diff(%{b: 2, a: 1} = %{a: 1, b: 2}, [])
    assert_diff(%{a: 1, b: 2, c: 3} = %{a: 1, b: 2, c: 3}, [])
    assert_diff(%{c: 3, b: 2, a: 1} = %{a: 1, b: 2, c: 3}, [])

    refute_diff(%{a: 1, b: 2} = %{a: 1}, "%{a: 1, -b: 2-}", "%{a: 1}")
    refute_diff(%{a: 1, b: 2} = %{a: 1, b: 12}, "%{a: 1, b: 2}", "%{a: 1, b: +1+2}")
    refute_diff(%{a: 1, b: 2} = %{a: 1, c: 2}, "%{a: 1, -b: 2-}", "%{a: 1, c: 2}")
    refute_diff(%{a: 1, b: 2, c: 3} = %{a: 1, b: 12}, "%{a: 1, b: 2, -c: 3-}", "%{a: 1, b: +1+2}")
    refute_diff(%{a: 1, b: 2, c: 3} = %{a: 1, c: 2}, "%{a: 1, c: -3-, -b: 2-}", "%{a: 1, c: +2+}")
    refute_diff(%{a: 1} = %{a: 2, b: 2, c: 3}, "%{a: -1-}", "%{a: +2+, b: 2, c: 3}")

    refute_diff(
      %{1 => :a, 2 => :b} = %{1 => :a, 12 => :b},
      "%{1 => :a, -2 => :b-}",
      "%{1 => :a, 12 => :b}"
    )

    refute_diff(
      %{1 => :a, 2 => :b} = %{1 => :a, :b => 2},
      "%{1 => :a, -2 => :b-}",
      "%{1 => :a, :b => 2}"
    )

    pins = %{{:a, nil} => :a, {:b, nil} => :b}
    assert_diff(%{^a => 1} = %{a: 1}, [], pins)
    assert_diff(%{^a => x} = %{a: 1}, [x: 1], pins)

    refute_diff(%{^a => 1, :a => 2} = %{a: 1}, "%{^a => 1, -:a => 2-}", "%{a: 1}", pins)

    refute_diff(
      %{^a => x, ^b => x} = %{a: 1, b: 2},
      "%{^a => x, ^b => -x-}",
      "%{a: 1, b: +2+}",
      pins
    )

    refute_diff(%{a: 1} = :a, "-%{a: 1}-", "+:a+")
  end

  test "maps as pinned map value" do
    user = %{"id" => 13, "name" => "john"}

    notification = %{
      "user" => user,
      "subtitle" => "foo"
    }

    assert_diff(
      %{
        "user" => ^user,
        "subtitle" => "foo"
      } = notification,
      [],
      %{{:user, nil} => user}
    )

    refute_diff(
      %{
        "user" => ^user,
        "subtitle" => "bar"
      } = notification,
      ~s|%{"subtitle" => "-bar-", "user" => ^user}|,
      ~s|%{"subtitle" => "+foo+", "user" => %{"id" => 13, "name" => "john"}}|,
      %{{:user, nil} => user}
    )
  end

  test "maps outside match context" do
    assert_diff(%{a: 1} == %{a: 1}, [])
    assert_diff(%{a: 1, b: 2} == %{a: 1, b: 2}, [])
    assert_diff(%{b: 2, a: 1} == %{a: 1, b: 2}, [])
    assert_diff(%{a: 1, b: 2, c: 3} == %{a: 1, b: 2, c: 3}, [])
    assert_diff(%{c: 3, b: 2, a: 1} == %{a: 1, b: 2, c: 3}, [])

    refute_diff(%{a: 1} == %{a: 1, b: 2}, "%{a: 1}", "%{a: 1, +b: 2+}")
    refute_diff(%{a: 1, b: 2} == %{a: 1}, "%{a: 1, -b: 2-}", "%{a: 1}")
    refute_diff(%{a: 1, b: 12} == %{a: 1, b: 2}, "%{a: 1, b: -1-2}", "%{a: 1, b: 2}")
    refute_diff(%{a: 1, b: 2} == %{a: 1, b: 12}, "%{a: 1, b: 2}", "%{a: 1, b: +1+2}")
    refute_diff(%{a: 1, b: 2} == %{a: 1, c: 2}, "%{a: 1, -b: 2-}", "%{a: 1, +c: 2+}")

    refute_diff(
      %{name: {:a, :b, :c}} == :error,
      "-%{name: {:a, :b, :c}}",
      "+:error+"
    )
  end

  test "structs" do
    assert_diff(%User{age: 16} = %User{age: 16}, [])
    assert_diff(%{age: 16, __struct__: User} = %User{age: 16}, [])

    refute_diff(
      %User{age: 16} = %User{age: 21},
      "%ExUnit.DiffTest.User{age: 1-6-}",
      "%ExUnit.DiffTest.User{age: +2+1, name: nil}"
    )

    refute_diff(
      %User{age: 16} = %Person{age: 21},
      "%-ExUnit.DiffTest.User-{age: 1-6-}",
      "%+ExUnit.DiffTest.Person+{age: +2+1}"
    )

    refute_diff(
      %User{age: 16} = %Person{age: 21},
      "%-ExUnit.DiffTest.User-{age: 1-6-}",
      "%+ExUnit.DiffTest.Person+{age: +2+1}"
    )

    refute_diff(
      %User{age: 16} = %{age: 16},
      "%-ExUnit.DiffTest.User-{age: 16}",
      "%{age: 16}"
    )

    refute_diff(
      %User{age: 16} = %{age: 21},
      "%-ExUnit.DiffTest.User-{age: 1-6-}",
      "%{age: +2+1}"
    )

    refute_diff(
      %{age: 16, __struct__: Person} = %User{age: 16},
      "%-ExUnit.DiffTest.Person-{age: 16}",
      "%+ExUnit.DiffTest.User+{age: 16, name: nil}"
    )

    pins = %{{:twenty_one, nil} => 21}
    assert_diff(%User{age: ^twenty_one} = %User{age: 21}, [], pins)
    assert_diff(%User{age: age} = %User{age: 21}, [age: 21], pins)
    refute_diff(%User{age: 21} = :a, "-%ExUnit.DiffTest.User{age: 21}-", "+:a+", pins)
  end

  test "structs outside of match context" do
    assert_diff(%User{age: 16} == %User{age: 16}, [])
    assert_diff(%{age: 16, __struct__: User, name: nil} == %User{age: 16}, [])

    refute_diff(
      %User{age: 16} == %{age: 16},
      "%-ExUnit.DiffTest.User-{age: 16, -name: nil-}",
      "%{age: 16}"
    )

    refute_diff(
      %User{age: 16} == %User{age: 21},
      "%ExUnit.DiffTest.User{age: 1-6-, name: nil}",
      "%ExUnit.DiffTest.User{age: +2+1, name: nil}"
    )

    refute_diff(
      %User{age: 16} == %Person{age: 21},
      "%-ExUnit.DiffTest.User-{age: 1-6-, -name: nil-}",
      "%+ExUnit.DiffTest.Person+{age: +2+1}"
    )
  end

  test "structs with inspect" do
    refute_diff(
      ~D[2017-10-01] = ~D[2017-10-02],
      ~s/-~D[2017-10-01]-/,
      "~D[2017-10-0+2+]"
    )

    refute_diff(
      "2017-10-01" = ~D[2017-10-02],
      ~s/-"2017-10-01"-/,
      "+~D[2017-10-02]+"
    )

    refute_diff(
      ~D[2017-10-02] = "2017-10-01",
      ~s/-~D[2017-10-02]-/,
      ~s/+"2017-10-01"+/
    )

    refute_diff(
      ~HTML[hi] = ~HTML[bye],
      "-~HTML[hi]-",
      "~HTML[+bye+]"
    )
  end

  test "structs with missing keys on match" do
    struct = %User{
      age: ~U[2020-07-30 13:49:59.253158Z]
    }

    assert_diff(%User{age: %DateTime{}} = struct, [])

    refute_diff(
      %User{age: %Date{}} = struct,
      ~s/%ExUnit.DiffTest.User{age: %-Date-{}}/,
      """
      %ExUnit.DiffTest.User{
        age: %+DateTime+{
          calendar: Calendar.ISO,
          day: 30,
          hour: 13,
          microsecond: {253158, 6},
          minute: 49,
          month: 7,
          second: 59,
          std_offset: 0,
          time_zone: "Etc\/UTC",
          utc_offset: 0,
          year: 2020,
          zone_abbr: "UTC"
        },
        name: nil
      }\
      """
    )

    refute_diff(
      %{age: %Date{}} = struct,
      ~s/%{age: %-Date-{}}/,
      """
      %ExUnit.DiffTest.User{
        age: %+DateTime+{
          calendar: Calendar.ISO,
          day: 30,
          hour: 13,
          microsecond: {253158, 6},
          minute: 49,
          month: 7,
          second: 59,
          std_offset: 0,
          time_zone: \"Etc/UTC\",
          utc_offset: 0,
          year: 2020,
          zone_abbr: \"UTC\"
        },
        name: nil
      }\
      """
    )
  end

  test "structs with inspect outside match context" do
    refute_diff(
      ~D[2017-10-01] == ~D[2017-10-02],
      "~D[2017-10-0-1-]",
      "~D[2017-10-0+2+]"
    )

    refute_diff(
      "2017-10-01" == ~D[2017-10-02],
      ~s/-"2017-10-01"-/,
      "+~D[2017-10-02]+"
    )

    refute_diff(
      ~D[2017-10-02] == "2017-10-01",
      ~s/-~D[2017-10-02]-/,
      ~s/+"2017-10-01"+/
    )

    refute_diff(
      ~HTML[hi] == ~HTML[bye],
      "~HTML[-hi-]",
      "~HTML[+bye+]"
    )
  end

  test "structs with same inspect but different inside match" do
    refute_diff(
      %Opaque{data: 1} = %Opaque{data: 2},
      "%ExUnit.DiffTest.Opaque{data: -1-}",
      "%ExUnit.DiffTest.Opaque{data: +2+}"
    )

    refute_diff(
      %Opaque{data: %{hello: :world}} = %Opaque{data: %{hello: "world"}},
      "#Opaque<data: %{hello: -:-world}>",
      "#Opaque<data: %{hello: +\"+world+\"+}>"
    )
  end

  test "structs with same inspect but different outside match" do
    refute_diff(
      %Opaque{data: 1} == %Opaque{data: 2},
      "%ExUnit.DiffTest.Opaque{data: -1-}",
      "%ExUnit.DiffTest.Opaque{data: +2+}"
    )

    refute_diff(
      %Opaque{data: %{hello: :world}} == %Opaque{data: %{hello: "world"}},
      "#Opaque<data: %{hello: -:-world}>",
      "#Opaque<data: %{hello: +\"+world+\"+}>"
    )
  end

  test "structs with inspect in a list" do
    refute_diff(
      Enum.sort([~D[2019-03-31], ~D[2019-04-01]]) == [~D[2019-03-31], ~D[2019-04-01]],
      "[-~D[2019-04-01]-, ~D[2019-03-31]]",
      "[~D[2019-03-31], +~D[2019-04-01]+]"
    )
  end

  test "structs with matched type" do
    pins = %{{:type, nil} => User, {:age, nil} => 33}

    # pin on __struct__
    assert_diff(
      %{__struct__: ^type, age: ^age, name: "john"} = %User{name: "john", age: 33},
      [],
      pins
    )

    refute_diff(
      %{__struct__: ^type, age: ^age, name: "john"} = %User{name: "jane", age: 33},
      "%{__struct__: ^type, age: ^age, name: \"j-oh-n\"}",
      "%ExUnit.DiffTest.User{age: 33, name: \"j+a+n+e+\"}",
      pins
    )

    refute_diff(
      %{__struct__: ^type, age: ^age, name: "john"} = %User{name: "john", age: 35},
      "%{__struct__: ^type, age: -^age-, name: \"john\"}",
      "%ExUnit.DiffTest.User{age: 3+5+, name: \"john\"}",
      pins
    )

    refute_diff(
      %{__struct__: ^type, age: ^age, name: "john"} = ~D[2020-01-01],
      "%{__struct__: -^type-, -age: ^age-, -name: \"john\"-}",
      "%+Date+{calendar: Calendar.ISO, day: 1, month: 1, year: 2020}",
      pins
    )

    # pin on %
    assert_diff(
      %^type{age: ^age, name: "john"} = %User{name: "john", age: 33},
      [],
      pins
    )

    refute_diff(
      %^type{age: ^age, name: "john"} = %User{name: "jane", age: 33},
      "%{__struct__: ^type, age: ^age, name: \"j-oh-n\"}",
      "%ExUnit.DiffTest.User{age: 33, name: \"j+a+n+e+\"}",
      pins
    )

    refute_diff(
      %^type{age: ^age, name: "john"} = %User{name: "john", age: 35},
      "%{__struct__: ^type, age: -^age-, name: \"john\"}",
      "%ExUnit.DiffTest.User{age: 3+5+, name: \"john\"}",
      pins
    )

    refute_diff(
      %^type{age: ^age, name: "john"} = ~D[2020-01-01],
      "%{__struct__: -^type-, -age: ^age-, -name: \"john\"-}",
      "%+Date+{calendar: Calendar.ISO, day: 1, month: 1, year: 2020}",
      pins
    )

    # right side is not map-like
    refute_diff(
      %^type{age: ^age, name: "john"} = nil,
      "-%^type{age: ^age, name: \"john\"}-",
      "+nil+",
      pins
    )
  end

  test "invalid structs" do
    refute_diff(
      %{__struct__: Unknown} = %{},
      "%{-__struct__: Unknown-}",
      "%{}"
    )

    refute_diff(
      %{__struct__: Date, unknown: :field} = %{},
      "%{-__struct__: Date-, -unknown: :field-}",
      "%{}"
    )
  end

  test "maps in lists" do
    map = %{
      "address" => %{
        "street" => "123 Main St",
        "zip" => "62701"
      },
      "age" => 30,
      "first_name" => "John",
      "language" => "en-US",
      "last_name" => "Doe",
      "notifications" => true
    }

    refute_diff(
      [map] == [],
      """
      [
        -%{
          "address" => %{"street" => "123 Main St", "zip" => "62701"},
          "age" => 30,
          "first_name" => "John",
          "language" => "en-US",
          "last_name" => "Doe",
          "notifications" => true
        }-
      ]\
      """,
      "[]"
    )

    refute_diff(
      [] == [map],
      "[]",
      """
      [
        +%{
          "address" => %{"street" => "123 Main St", "zip" => "62701"},
          "age" => 30,
          "first_name" => "John",
          "language" => "en-US",
          "last_name" => "Doe",
          "notifications" => true
        }+
      ]\
      """
    )

    assert_diff([map] == [map], [])
  end

  test "structs in lists" do
    customer = %Customer{
      address: %{
        "street" => "123 Main St",
        "zip" => "62701"
      },
      age: 30,
      first_name: "John",
      language: "en-US",
      last_name: "Doe",
      notifications: true
    }

    refute_diff(
      [customer] == [],
      """
      [
        -%ExUnit.DiffTest.Customer{
          address: %{"street" => "123 Main St", "zip" => "62701"},
          age: 30,
          first_name: "John",
          language: "en-US",
          last_name: "Doe",
          notifications: true
        }-
      ]\
      """,
      "[]"
    )

    refute_diff(
      [] == [customer],
      "[]",
      """
      [
        +%ExUnit.DiffTest.Customer{
          address: %{"street" => "123 Main St", "zip" => "62701"},
          age: 30,
          first_name: "John",
          language: "en-US",
          last_name: "Doe",
          notifications: true
        }+
      ]\
      """
    )

    assert_diff([customer] == [customer], [])
  end

  test "maps and structs with escaped values" do
    refute_diff(
      %User{age: {1, 2, 3}} = %User{age: {1, 2, 4}},
      "%ExUnit.DiffTest.User{age: {1, 2, -3-}}",
      "%ExUnit.DiffTest.User{age: {1, 2, +4+}, name: nil}"
    )

    refute_diff(
      %User{age: {1, 2, 3}, name: name} = %User{age: {1, 2, 4}},
      "%ExUnit.DiffTest.User{age: {1, 2, -3-}, name: name}",
      "%ExUnit.DiffTest.User{age: {1, 2, +4+}, name: nil}"
    )

    refute_diff(
      %User{name: :foo} = %User{name: :bar, age: {1, 2, 3}},
      "%ExUnit.DiffTest.User{name: -:foo-}",
      "%ExUnit.DiffTest.User{name: +:bar+, age: {1, 2, 3}}"
    )

    refute_diff(
      %User{age: {1, 2, 3}} == %User{age: {1, 2, 4}},
      "%ExUnit.DiffTest.User{age: {1, 2, -3-}, name: nil}",
      "%ExUnit.DiffTest.User{age: {1, 2, +4+}, name: nil}"
    )

    refute_diff(
      %User{age: {1, 2, 4}} == %User{age: {1, 2, 3}},
      "%ExUnit.DiffTest.User{age: {1, 2, -4-}, name: nil}",
      "%ExUnit.DiffTest.User{age: {1, 2, +3+}, name: nil}"
    )

    refute_diff(
      %{name: :foo} == %{name: :foo, age: {1, 2, 3}},
      "%{name: :foo}",
      "%{name: :foo, +age: {1, 2, 3}+}"
    )

    refute_diff(
      %{name: :foo, age: {1, 2, 3}} == %{name: :foo},
      "%{name: :foo, -age: {1, 2, 3}-}",
      "%{name: :foo}"
    )
  end

  test "strings" do
    assert_diff("" = "", [])
    assert_diff("fox hops over the dog" = "fox hops over the dog", [])

    refute_diff("fox" = "foo", "fo-x-", "fo+o+")

    refute_diff(
      "fox hops over \"the dog" = "fox  jumps over the  lazy cat",
      ~s/"fox -ho-ps over -\\\"-the -dog-"/,
      ~s/"fox + jum+ps over the + lazy cat+"/
    )

    refute_diff(
      "short" = "really long string that should not emit diff against short",
      ~s/"-short-"/,
      ~s/"+really long string that should not emit diff against short+"/
    )

    refute_diff("foo" = :a, ~s/-"foo"-/, "+:a+")
  end

  test "strings outside match context" do
    assert_diff("" == "", [])
    assert_diff("fox hops over the dog" == "fox hops over the dog", [])
    refute_diff("fox" == "foo", "fo-x-", "fo+o+")

    refute_diff(
      "{\"foo\":1,\"barbaz\":[1,2,3]}" == "4",
      ~s/"-{\\\"foo\\\":1,\\\"barbaz\\\":[1,2,3]}-"/,
      ~s/"+4+"/
    )
  end

  test "concat binaries" do
    assert_diff("fox hops" <> _ = "fox hops over the dog", [])
    assert_diff("fox hops" <> " over the dog" = "fox hops over the dog", [])
    assert_diff("fox hops " <> "over " <> "the dog" = "fox hops over the dog", [])

    refute_diff(
      "fox hops" <> _ = "dog hops over the fox",
      ~s/"-f-o-x- hops" <> _/,
      ~s/+d+o+g+ hops over the fox/
    )

    refute_diff(
      "fox hops" <> " under the dog" = "fox hops over the dog",
      ~s/"fox hops" <> " -und-er the dog"/,
      ~s/"fox hops +ov+er the dog"/
    )

    refute_diff(
      "fox hops over" <> " the dog" = "fox hops over",
      ~s/"fox hops over" <> "- the dog-"/,
      ~s/"fox hops over"/
    )

    refute_diff(
      "fox hops" <> " over the dog" = "fox",
      ~s/"-fox hops-" <> "- over the dog-"/,
      ~s/"+fox+"/
    )

    refute_diff(
      "fox" <> " hops" = "fox h",
      ~s/"fox" <> " h-ops-"/,
      ~s/"fox h"/
    )

    refute_diff(
      "fox hops " <> "hover " <> "the dog" = "fox hops over the dog",
      ~s/"fox hops " <> "-h-over " <> "the dog"/,
      ~s/"fox hops over the dog"/
    )

    refute_diff("fox" <> " hops" = :a, ~s/-"fox" <> " hops"-/, "+:a+")
  end

  test "concat binaries with pin" do
    pins = %{{:x, nil} => " over the dog"}

    assert_diff("fox hops" <> x = "fox hops over the dog", x: " over the dog")
    assert_diff("fox hops " <> "over " <> x = "fox hops over the dog", x: "the dog")
    assert_diff("fox hops" <> ^x = "fox hops over the dog", [], pins)

    refute_diff(
      "fox hops " <> "hover " <> x = "fox hops over the dog",
      ~s/"fox hops " <> "-h-over " <> x/,
      ~s/"fox hops over +t+he dog"/
    )

    refute_diff(
      "fox hops " <> "hover " <> ^x = "fox hops over the dog",
      ~s/"fox hops " <> "-h-over " <> -^x-/,
      ~s/"fox hops over +t+he dog"/,
      pins
    )
  end

  test "concat binaries with specifiers" do
    input = "foobar"

    refute_diff(
      <<trap::binary-size(3)>> <> "baz" = input,
      "-<<trap::binary-size(3)>> <> \"baz\"-",
      "+\"foobar\"+"
    )

    refute_diff(
      "hello " <> <<_::binary-size(6)>> = "hello world",
      "\"hello \" <> -<<_::binary-size(6)>>-",
      "\"hello +world+\""
    )
  end

  test "underscore" do
    assert_diff(_ = :a, [])
    assert_diff({_, _} = {:a, :b}, [])

    refute_diff({_, :a} = {:b, :b}, "{_, -:a-}", "{:b, +:b+}")
  end

  test "macros" do
    assert_diff(one() = 1, [])
    assert_diff(tuple(x, x) = {1, 1}, x: 1)

    refute_diff(one() = 2, "-1-", "+2+")
    refute_diff(tuple(x, x) = {1, 2}, "{x, -x-}", "{1, +2+}")

    pins = %{{:x, nil} => 1}
    assert_diff(pin_x() = 1, [], pins)
    refute_diff(pin_x() = 2, "-pin_x()-", "+2+", pins)
  end

  test "guards" do
    assert_diff((x when x == 0) = 0, x: 0)
    assert_diff((x when x == 0 and is_integer(x)) = 0, x: 0)
    assert_diff((x when x == 0 or x == 1) = 0, x: 0)
    assert_diff((x when x == 0 when x == 1) = 0, x: 0)
    assert_diff((x when one() == 1) = 0, x: 0)

    refute_diff((x when x == 1) = 0, "x when -x == 1-", "0")
    refute_diff((x when x == 0 and x == 1) = 0, "x when x == 0 and -x == 1-", "0")
    refute_diff((x when x == 1 and x == 2) = 0, "x when -x == 1- and -x == 2-", "0")
    refute_diff((x when x == 1 or x == 2) = 0, "x when -x == 1- or -x == 2-", "0")
    refute_diff((x when x == 1 when x == 2) = 0, "x when -x == 1- when -x == 2-", "0")
    refute_diff((x when x in [1, 2]) = 0, "x when -x in [1, 2]-", "0")
    refute_diff(({:ok, x} when x == 1) = :error, "-{:ok, x}- when x == 1", "+:error+")

    refute_diff((x when x == z) = 0, "x when x == z", "0", z: 1)
  end

  test "blocks" do
    refute_diff(
      block_head(
        (
          1
          2
        )
      ) = 3,
      "1",
      "3"
    )

    refute_diff(
      ["foo" | {:__block__, [], [1]}] = ["bar" | {:__block__, [], [2]}],
      "[\"-foo-\" | {:__block__, [], [-1-]}]",
      "[\"+bar+\" | {:__block__, [], [+2+]}]"
    )

    refute_diff(
      ["foo" | {:__block__, [], [1]}] == ["bar" | {:__block__, [], [2]}],
      "[\"-foo-\" | {:__block__, [], [-1-]}]",
      "[\"+bar+\" | {:__block__, [], [+2+]}]"
    )
  end

  test "charlists" do
    refute_diff(
      ~c"fox hops over 'the dog" = ~c"fox jumps over the lazy cat",
      "~c\"fox -ho-ps over -'-the -dog-\"",
      "~c\"fox +jum+ps over the +lazy cat+\""
    )

    refute_diff({[], :ok} = {[], [], :ok}, "{[], -:ok-}", "{[], +[]+, +:ok+}")
    refute_diff({[], :ok} = {~c"foo", [], :ok}, "{~c\"--\", -:ok-}", "{~c\"+foo+\", +[]+, +:ok+}")
    refute_diff({~c"foo", :ok} = {[], [], :ok}, "{~c\"-foo-\", -:ok-}", "{~c\"++\", +[]+, +:ok+}")

    refute_diff(
      {~c"foo", :ok} = {~c"bar", [], :ok},
      "{~c\"-foo-\", -:ok-}",
      "{~c\"+bar+\", +[]+, +:ok+}"
    )
  end

  test "refs" do
    ref1 = make_ref()
    ref2 = make_ref()

    inspect_ref1 = inspect(ref1)
    inspect_ref2 = inspect(ref2)

    assert_diff(ref1 == ref1, [])
    assert_diff({ref1, ref2} == {ref1, ref2}, [])

    refute_diff(ref1 == ref2, "-#{inspect_ref1}-", "+#{inspect_ref2}+")

    refute_diff(
      {ref1, ref2} == {ref2, ref1},
      """
      {
        -#{inspect_ref1}-,
        -#{inspect_ref2}-
      }\
      """,
      """
      {
        +#{inspect_ref2}+,
        +#{inspect_ref1}+
      }\
      """
    )

    refute_diff(
      {ref1, ref2} == ref1,
      "-{#{inspect_ref1}, #{inspect_ref2}}-",
      "+#{inspect_ref1}+"
    )

    refute_diff(
      ref1 == {ref1, ref2},
      "-#{inspect_ref1}-",
      "+{#{inspect_ref1}, #{inspect_ref2}}+"
    )

    refute_diff(ref1 == :a, "-#{inspect_ref1}-", "+:a+")
    refute_diff({ref1, ref2} == :a, "-{#{inspect_ref1}, #{inspect_ref2}}", "+:a+")

    refute_diff(
      %{ref1 => ref2} == :a,
      """
      -%{
        #{inspect_ref1} => #{inspect_ref2}
      }\
      """,
      "+:a+"
    )

    refute_diff(
      %Opaque{data: ref1} == :a,
      "-#Opaque<???>-",
      "+:a+"
    )
  end

  test "pids" do
    pid = self()
    inspect_pid = inspect(pid)

    assert_diff(pid == pid, [])
    assert_diff({pid, pid} == {pid, pid}, [])

    refute_diff(pid == :a, "-#{inspect_pid}-", "+:a+")
    refute_diff({pid, pid} == :a, "-{#{inspect_pid}, #{inspect_pid}}", "+:a+")

    refute_diff({pid, :a} == {:a, pid}, "{-#{inspect_pid}-, -:a-}", "{+:a+, +#{inspect_pid}+}")
    refute_diff(%{pid => pid} == :a, "-%{#{inspect_pid} => #{inspect_pid}}", "+:a+")

    refute_diff(
      %Opaque{data: pid} == :a,
      "-#Opaque<???>-",
      "+:a+"
    )
  end

  @compile {:no_warn_undefined, String}

  test "functions" do
    identity = & &1
    inspect = inspect(identity)

    assert_diff(identity == identity, [])
    assert_diff({identity, identity} == {identity, identity}, [])

    refute_diff(identity == :a, "-#{inspect}-", "+:a+")
    refute_diff({identity, identity} == :a, "-{#{inspect}, #{inspect}}", "+:a+")
    refute_diff({identity, :a} == {:a, identity}, "{-#{inspect}-, -:a-}", "{+:a+, +#{inspect}+}")

    refute_diff(
      %{identity => identity} == :a,
      """
      -%{
        #{inspect} => #{inspect}
      }-\
      """,
      "+:a+"
    )

    refute_diff(
      (&String.to_charlist/1) == (&String.unknown/1),
      "-&String.to_charlist/1-",
      "+&String.unknown/1"
    )

    refute_diff(
      %Opaque{data: identity} == :a,
      "-#Opaque<???>-",
      "+:a+"
    )
  end

  defp closure(a), do: fn -> a end

  test "functions with closure" do
    closure1 = closure(1)
    closure2 = closure(2)

    fun_info = Function.info(closure1)
    uniq = Integer.to_string(fun_info[:new_index]) <> "." <> Integer.to_string(fun_info[:uniq])

    assert_diff(closure1 == closure1, [])

    refute_diff(
      closure1 == closure2,
      "#Function<\n  #{uniq}/0 in ExUnit.DiffTest.closure/1\n  [-1-]\n>",
      "#Function<\n  #{uniq}/0 in ExUnit.DiffTest.closure/1\n  [+2+]\n>"
    )
  end

  test "not supported" do
    refute_diff(
      <<147, 1, 2, 31>> = <<193, 1, 31>>,
      "-<<147, 1, 2, 31>>-",
      "+<<193, 1, 31>>+"
    )
  end
end
