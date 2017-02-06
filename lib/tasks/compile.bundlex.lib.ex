defmodule Mix.Tasks.Compile.Bundlex.Lib do
  use Mix.Task
  alias Bundlex.Makefile
  alias Bundlex.Helper.MixHelper
  alias Bundlex.Helper.ErlangHelper


  @moduledoc """
  Builds a library for the given platform.
  """

  @shortdoc "Builds a library for the given platform"
  @switches [
    platform: :string,
    "no-deps": :string,
    "no-archives-check": :string,
    "no-elixir-version-check": :string,
    "no-warnings-as-errors": :string,
  ]

  @spec run(OptionParser.argv) :: :ok
  def run(args) do
    # Get app
    app = MixHelper.get_app!()
    Bundlex.Output.info1 "Bulding Bundlex Library \"#{app}\""

    # Parse options
    Bundlex.Output.info2 "Target platform"
    {opts, _} = OptionParser.parse!(args, aliases: [t: :platform], switches: @switches)

    {platform_name, platform_module} = Bundlex.Platform.get_platform_from_opts!(opts)
    Bundlex.Output.info3 "Building for platform #{platform_name}"

    # Configuration
    build_config = MixHelper.get_config!(app, :bundlex_lib, platform_name)

    # Toolchain
    Bundlex.Output.info2 "Toolchain"
    before_all = platform_module.toolchain_module.before_all!(platform_name)

    # NIFs
    {nif_compiler_commands, nif_post_copy_commands} = case build_config |> List.keyfind(:nif, 0) do
      {:nif, nifs_config} ->
        Bundlex.Output.info2 "NIFs"

        erlang_includes = ErlangHelper.get_includes!(platform_name)

        Bundlex.Output.info3 "Found Erlang include dir in #{erlang_includes}"

        compiler_commands =
          nifs_config
          |> Enum.reduce([], fn({nif_name, nif_config}, acc) ->
            Bundlex.Output.info3 to_string(nif_name)

            includes = case nif_config |> List.keyfind(:includes, 0) do
              {:includes, includes} -> [erlang_includes|includes]
              _ -> [erlang_includes]
            end

            libs = case nif_config |> List.keyfind(:libs, 0) do
              {:libs, libs} -> libs
              _ -> []
            end

            sources = case nif_config |> List.keyfind(:sources, 0) do
              {:sources, sources} -> sources
              _ -> Mix.raise "NIF #{nif_name} does not define any sources"
            end

            acc ++ platform_module.toolchain_module.compiler_commands(includes, libs, sources, nif_name)
          end)


        post_copy_commands =
          nifs_config
          |> Enum.reduce([], fn({nif_name, _nif_config}, acc) ->
            acc ++ platform_module.toolchain_module.post_copy_commands(nif_name)
          end)

        {compiler_commands, post_copy_commands}

      _ ->
        {[], []}
    end

    # Build & run makefile
    Bundlex.Output.info2 "Building"
    Makefile.new
    |> Makefile.append_commands!(before_all)
    |> Makefile.append_commands!(nif_compiler_commands)
    |> Makefile.append_commands!(nif_post_copy_commands)
    |> Makefile.run!(platform_name)

    Bundlex.Output.info2 "Done"
  end
end