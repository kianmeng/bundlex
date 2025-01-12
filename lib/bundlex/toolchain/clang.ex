defmodule Bundlex.Toolchain.Clang do
  @moduledoc false

  use Bundlex.Toolchain
  alias Bundlex.Native
  alias Bundlex.Toolchain.Common.{Unix, Compilers}

  @compilers %Compilers{c: "clang", cpp: "clang++"}

  @impl Toolchain
  def compiler_commands(native) do
    {cflags, lflags} =
      case native do
        %Native{type: :native, interface: :nif} -> {"-fPIC", "-rdynamic -shared"}
        %Native{type: :lib} -> {"-fPIC", ""}
        %Native{} -> {"", ""}
      end

    compiler = @compilers |> Map.get(native.language)

    Unix.compiler_commands(
      native,
      "#{compiler} #{cflags}",
      "#{compiler} #{lflags}",
      native.language,
      wrap_deps: &"-Wl,--whole-archive #{&1} -Wl,--no-whole-archive"
    )
  end
end
