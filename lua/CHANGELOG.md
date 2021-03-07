# Changelog

`lua` uses [PVP Versioning][1].

## lua 3.0.0

Release pending.

- Update to Lua 5.4, include Lua 5.4.2 by default.

## lua 2.0.0

Release pending.

- Module hierarchy moved from `Foreign.Lua.Raw` to `Lua`.

- Documentation has been improved.

- Added new function `withNewState` to run Lua operations.

- New modules `Lua.Ersatz` containing all bindings to safe
  ersatz functions.

- Higher level and enum types have been removed, only the
  low-level "code" types are kept in this package.

- Constants are now represented as pattern synonyms like `LUA_OK`.

- Provide bindings to more functions:
    + `lua_is...` type-checking functions;
    + `lua_pushstring` to push plain CStrings;
    + unsafe functions
        * `lua_gettable`,
        * `lua_settable`,
        * `lua_getglobal`, and
        * `lua_setglobal`.

- The function `lua_pop` now expects a `CInt` instead of a
  `StackIndex`.

- New StackIndex constructor functions `nthTop`, `nthBottom`,
  `nth`, and `top`.

- Avoid unnecessary modification of HSFUN metatable.

- Various cleanups and test improvements.

## lua 1.0.0

Released 2021-02-18.

- Initially created. Contains all modules in the `Foreign.Lua.Raw`
  hierarchy from `hslua-1.3`. Documentation has been improved.

[1]: https://pvp.haskell.org
