# MPL3115A2

API for MPL3115A2 pressure/temperature/altitude sensor

See implementations of various `get_reading` methods for idea of how to use
more low level api to do advanced things.

## Big ugly glitches

At this time the first reading taken will always be nonsense

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `mpl3115a2` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:mpl3115a2, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/mpl3115a2](https://hexdocs.pm/mpl3115a2).

