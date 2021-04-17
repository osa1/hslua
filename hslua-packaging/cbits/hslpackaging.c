#include <HsFFI.h>
#include <lua.h>
#include <lauxlib.h>
#include <string.h>

/* ***************************************************************
 * Helpers for fast element access
 * ***************************************************************/

/*
** Testing
**
** One, two, test.
*/
int hslua_wrappedudindex(lua_State *L)
{
  luaL_checktype(L, 1, LUA_TTABLE);
  lua_settop(L, 2);

  /* Use value in table if present */
  lua_pushvalue(L, 2);
  if (lua_rawget(L, 1) != LUA_TNIL) {
    return 1;
  }
  lua_pop(L, 1);  /* remove nil */

  /* Get wrapped object */
  lua_pushliteral(L, "_hslua_value");
  if (lua_rawget(L, 1) != LUA_TUSERDATA) {
    /* something went wrong, didn't get a userdata */
    lua_pushliteral(L, "Corrupted object, wrapped userdata not found.");
    return lua_error(L);
  }

  /* Get value from wrapped object */
  lua_pushvalue(L, 2); /* key */
  if (lua_gettable(L, -2) != LUA_TNIL) {
    /* key found in wrapped userdata, add to wrapping table */
    lua_pushvalue(L, 2);  /* key */
    lua_pushvalue(L, -2); /* value */
    lua_rawset(L, 1);
    /* return value */
    return 1;
  }

  /* key not found, return nil */
  lua_pushnil(L);
  return 1;
}

void hsluaP_get_caching_table(lua_State *L, int idx)
{
  int absidx = lua_absindex(L, idx);
  if (lua_getuservalue(L, idx) == LUA_TNIL) { /* caching table */
    lua_pop(L, 1);  /* remove nil */
    /* no caching table yet, create one */
    lua_createtable(L, 0, 0);
    lua_pushvalue(L, -1);
    lua_setuservalue(L, idx);
  }
}

/*
** Access a userdata, but use caching.
**
** One, two, test.
*/
int hslua_cachedindex(lua_State *L)
{
  lua_settop(L, 2);
  /* Use value in caching table if present */
  hsluaP_get_caching_table(L, 1);
  lua_pushvalue(L, 2);    /* key */
  if (lua_rawget(L, 3) != LUA_TNIL) {
    /* found the key in the cache */
    return 1;
  }
  lua_pop(L, 1);  /* remove nil */

  /* Get value from userdata object;
   * this is slow, as it calls into Haskell */
  if (luaL_getmetafield(L, 1, "getters") == LUA_TTABLE) {
    lua_pushvalue(L, 2);    /* key */
    if (lua_rawget(L, -2) != LUA_TNIL) {
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

int hslua_cachedsetindex(lua_State *L)
{
  luaL_checkany(L, 3);
  lua_settop(L, 3);
  hsluaP_get_caching_table(L, 1);
  lua_insert(L, 2);
  lua_rawset(L, 2);
  return 0;
}
