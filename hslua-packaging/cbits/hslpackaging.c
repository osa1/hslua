#include <HsFFI.h>
#include <lua.h>
#include <lauxlib.h>
#include <string.h>

/* ***************************************************************
 * Helpers for fast element access
 * ***************************************************************/

/*
** Pushes the caching table of the userdata at index `idx` to the stack.
**
** Creates and sets a new table if none has been attached to the
** userdata yet.
*/
void hsluaP_get_caching_table(lua_State *L, int idx)
{
  int absidx = lua_absindex(L, idx);
  if (lua_getuservalue(L, idx) != LUA_TTABLE) {
    lua_pop(L, 1);  /* remove nil */
    /* no caching table yet, create one */
    lua_createtable(L, 0, 0);
    lua_pushvalue(L, -1);
    lua_setuservalue(L, idx);
  }
}

/*
** Retrieves a key from a Haskell-data holding userdata value.
**
** Does the following, in order, and returns the first non-nil result:
**
**   - Checks the userdata's uservalue table for the given key;
**
**   - Looks up a `getter` for the key and calls it with the userdata and
**     key as arguments;
**
**   - Looks up the key in the table in the `methods` metafield.
*/
int hslua_udindex(lua_State *L)
{
  lua_settop(L, 2);
  /* Use value in caching table if present */
  hsluaP_get_caching_table(L, 1);      /* table */
  lua_pushvalue(L, 2);                 /* key */
  if (lua_rawget(L, 3) != LUA_TNIL) {
    /* found the key in the cache */
    return 1;
  }
  lua_pop(L, 1);              /* remove nil */

  /* Get value from userdata object */
  if (luaL_getmetafield(L, 1, "getters") == LUA_TTABLE) {
    lua_pushvalue(L, 2);      /* key */
    if (lua_rawget(L, -2) != LUA_TNIL) {
      /* Call getter. Slow, as it calls into Haskell. */
      lua_pushvalue(L, 1);
      lua_call(L, 1, 1);

      /* key found in wrapped userdata, add to caching table */
      lua_pushvalue(L, 2);    /* key */
      lua_pushvalue(L, -2);   /* value */
      lua_rawset(L, 3);       /* caching table */
      /* return value */
      return 1;
    }
    lua_pop(L, 1);
  }
  if (luaL_getmetafield(L, 1, "methods") == LUA_TTABLE) {
    lua_pushvalue(L, 2);
    lua_rawget(L, -2);
    return 1;
  }
  lua_pop(L, 1);

  /* key not found, return nil */
  lua_pushnil(L);
  return 1;
}

/*
** Sets a new value in the userdata caching table via a setter
** functions.
**
** The actual assignment is performed by a setter function stored in the
** `setter` metafield. Throws an error if no setter function can be
** found.
 */
int hslua_udnewindex(lua_State *L)
{
  if (luaL_getmetafield(L, 1, "setters") == LUA_TTABLE) {
    lua_pushvalue(L, 2);      /* key */
    if (lua_rawget(L, -2) == LUA_TFUNCTION) {
      lua_insert(L, 1);
      lua_settop(L, 4);       /* 1: setter, 2: ud, 3: key, 4: value */
      lua_call(L, 3, 0);
      return 0;
    }
    lua_pushliteral(L, "Cannot set unknown property.");
  } else {
    lua_pushliteral(L, "Cannot modify read-only object.");
  }
  return lua_error(L);
}

/*
** Sets a value in the userdata's caching table (uservalue). Takes the
** same arguments as a `__newindex` function.
*/
int hslua_udsetter(lua_State *L)
{
  luaL_checkany(L, 3);
  lua_settop(L, 3);
  hsluaP_get_caching_table(L, 1);
  lua_insert(L, 2);
  lua_rawset(L, 2);
  return 0;
}

/*
** Throws an error nothing that the given key is read-only.
*/
int hslua_udreadonly(lua_State *L)
{
  if (lua_type(L, 2) == LUA_TSTRING && lua_checkstack(L, 3)) {
    lua_pushliteral(L, "'");
    lua_pushvalue(L, 2);
    lua_pushliteral(L, "' is a read-only property.");
    lua_concat(L, 3);
  } else {
    lua_pushliteral(L, "Cannot set read-only value.");
  }
  return lua_error(L);
}
