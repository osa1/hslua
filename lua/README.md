# lua

[![Build status][GitHub Actions badge]][GitHub Actions]
[![AppVeyor Status]](https://ci.appveyor.com/project/tarleb/hslua-r2y18)
[![Hackage]](https://hackage.haskell.org/package/lua)

The *lua* package provides a Lua interpreter as well as bindings,
wrappers and types to combine Haskell and Lua.

[GitHub Actions badge]: https://img.shields.io/github/workflow/status/hslua/hslua/CI.svg?logo=github
[GitHub Actions]: https://github.com/hslua/hslua/actions
[AppVeyor Status]: https://ci.appveyor.com/api/projects/status/ldutrilgxhpcau94/branch/main?svg=true
[Hackage]: https://img.shields.io/hackage/v/lua.svg


Overview
--------

[Lua](https://lua.org) is a small, well-designed, embeddable
scripting language. It has become the de-facto default to make
programs extensible and is widely used everywhere from servers
over games and desktop applications up to security software and
embedded devices. This package provides Haskell bindings to Lua,
enable coders to embed the language into their programs, making
them scriptable.

*Lua* ships with the official Lua interpreter, version 5.4.2.
Cabal flags allow to compile against a system-wide Lua
installation instead, if desired.

Build flags
-----------

The following cabal build flags are supported:

- `system-lua`: Use the locally installed Lua version instead of
  the version shipped as part of this package.

- `pkg-config`: Use *pkg-config* to discover library and include
  paths. Setting this flag implies `system-lua`.

- `allow-unsafe-gc`: Allow optimizations which make Lua's garbage
  collection potentially unsafe; enabling this should be safe if
  there are no callbacks into Haskell during Lua garbage
  collection cycles. The flag should be *disabled* if Lua objects
  can have Haskell finalizers, i.e., `__gc` metamethods that call
  Haskell function.

  The flag is *enabled* per default, as Haskell functions are
  rarely used in finalizers. It can help to disable the flag if
  there are issues related to Lua's garbage collection.

- `apicheck`: Compile Lua with its API checks enabled.

- `lua_32bits`: Compile Lua for a 32-bits system (e.g., i386,
  PowerPC G4).

- `export-dynamic`: Add all symbols to dynamic symbol table;
  disabling this will make it possible to create fully static
  binaries, but renders loading of dynamic C libraries impossible.

- `hardcode-reg-keys`: Don't use CAPI to determine the names of
  certain registry key names but use hard coded values instead.
  This flag is required when compiling against Lua 5.3.3 or
  earlier, as those versions do not expose the necessary
  information in the @lauxlib.h@ header file. Setting this flag
  should usually be unproblematic, except if the used Lua version
  has been patched heavily.

### Example: using a different Lua version

To use a system-wide installed Lua when linking *lua* as a
dependency, build/install your package using
`--constraint="lua +system-lua"`. For example, you can
install Pandoc with hslua that uses system-wide Lua like this:

``` sh
cabal install pandoc --constraint="lua +system-lua"
```

or with stack:

``` sh
stack install pandoc --flag=lua:system-lua
```
