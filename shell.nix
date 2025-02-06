# Impure development environment to retain the normal python development flow
# This devShell simply adds Python and undoes the dependency leakage done by Nixpkgs Python infrastructure.
{
  pkgs,
  lib,
  python,
  ...
}:
pkgs.mkShell {
  buildInputs = [
    pkgs.libcoap # debug tools for coap protocol
    pkgs.git # otherwise git complains about missing tools
  ];

  packages = [
    python
    pkgs.uv
  ];
  env =
    {
      # Prevent uv from downloading different Python versions
      UV_PYTHON_DOWNLOADS = "never";
      # Force uv to use nixpkgs Python interpreter
      UV_PYTHON = python.interpreter;
    }
    // lib.optionalAttrs pkgs.stdenv.isLinux {
      # Python libraries often load native shared objects using dlopen(3).
      # Setting LD_LIBRARY_PATH makes the dynamic library loader aware of libraries without using RPATH for lookup.
      LD_LIBRARY_PATH = lib.makeLibraryPath pkgs.pythonManylinuxPackages.manylinux1;
    };
  shellHook = ''
    unset PYTHONPATH
  '';
}
