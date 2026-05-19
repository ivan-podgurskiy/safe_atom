defmodule SafeAtom.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/ivan-podgurskiy/safe_atom"

  def project do
    [
      app: :safe_atom,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Hex
      description: description(),
      package: package(),

      # Docs
      name: "SafeAtom",
      source_url: @source_url,
      docs: docs(),

      # Dialyzer
      dialyzer: [
        plt_add_apps: [:ex_unit, :mix],
        plt_local_path: "priv/plts/local.plt",
        plt_core_path: "priv/plts/core.plt"
      ]
    ]
  end

  def application do
    []
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:telemetry, "~> 1.0"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  defp description do
    "Whitelist-based casting of values to atoms without growing the VM atom table from untrusted input."
  end

  defp package do
    [
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE CHANGELOG.md),
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      maintainers: ["Ivan Podgurskiy"]
    ]
  end

  defp docs do
    [
      main: "SafeAtom",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: ["README.md", "CHANGELOG.md"]
    ]
  end
end
