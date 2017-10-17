defmodule TwilioListLookup.Mixfile do
  use Mix.Project

  def project do
    [
      app: :twilio_list_lookup,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_twilio, github: "danielberkompas/ex_twilio"},
      {:nimble_csv, "~> 0.2.0"},
      {:parallel_stream, "~> 1.0.5"},
      {:osdi, git: "https://github.com/BrandNewCongress/osdi_ex.git"},
      {:flow, "~> 0.11"}
    ]
  end
end
