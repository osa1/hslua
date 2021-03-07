{-# LANGUAGE CPP #-}
{-|
Module      : Lua.Functions
Copyright   : © 2007–2012 Gracjan Polak;
              © 2012–2016 Ömer Sinan Ağacan;
              © 2017-2021 Albert Krewinkel
License     : MIT
Maintainer  : Albert Krewinkel <tarleb+hslua@zeitkraut.de>
Stability   : beta
Portability : ForeignFunctionInterface, CPP

Haskell bindings to Lua C API functions.

The exposed functions correspond closely to the respective C Lua API
functions. However, C API functions which can throw Lua errors are not
exported directly, as any errors would crash the program. Non-error
throwing @hslua_@ versions are provided instead. The @hslua@ ersatz
functions have worse performance than the original.

Some of the Lua functions may, directly or indirectly, call a Haskell
function, and trigger garbage collection, rescheduling etc. These
functions are always imported safely (i.e., with the @safe@ keyword).

However, all function can trigger garbage collection. If that can lead
to problems, then the package should be configured without flag
@allow-unsafe-gc@.
-}
module Lua.Functions
  ( lua_absindex
  , lua_checkstack
  , lua_close
  , lua_copy
  , lua_createtable
  , lua_gc
  , lua_getglobal
  , lua_getmetatable
  , lua_gettable
  , lua_gettop
  , lua_insert
  , lua_isboolean
  , lua_iscfunction
  , lua_isfunction
  , lua_isinteger
  , lua_islightuserdata
  , lua_isnil
  , lua_isnone
  , lua_isnoneornil
  , lua_isnumber
  , lua_isstring
  , lua_istable
  , lua_isthread
  , lua_isuserdata
  , lua_load
  , lua_newthread
  , lua_newuserdata
  , lua_pcall
  , lua_pop
  , lua_pushboolean
  , lua_pushcclosure
  , lua_pushglobaltable
  , lua_pushinteger
  , lua_pushlightuserdata
  , lua_pushlstring
  , lua_pushnil
  , lua_pushnumber
  , lua_pushstring
  , lua_pushthread
  , lua_pushvalue
  , lua_rawequal
  , lua_rawget
  , lua_rawgeti
  , lua_rawlen
  , lua_rawset
  , lua_rawseti
  , lua_remove
  , lua_replace
  , lua_setglobal
  , lua_setmetatable
  , lua_settable
  , lua_settop
  , lua_status
  , lua_toboolean
  , lua_tocfunction
  , lua_tointegerx
  , lua_tolstring
  , lua_tonumberx
  , lua_topointer
  , lua_tothread
  , lua_touserdata
  , lua_type
  , lua_typename
  , module Lua.Ersatz.Functions
  , module Lua.Ersatz.Auxiliary
  )
where

import Foreign.C
import Lua.Ersatz.Auxiliary
import Lua.Ersatz.Functions
import Lua.Types as Lua
import Foreign.Ptr

#ifdef ALLOW_UNSAFE_GC
#define SAFTY unsafe
#else
#define SAFTY safe
#endif

-- | Converts the acceptable index @idx@ into an equivalent absolute
-- index (that is, one that does not depend on the stack top).
--
-- <https://www.lua.org/manual/5.3/manual.html#lua_absindex>
foreign import ccall unsafe "lua.h lua_absindex"
  lua_absindex :: Lua.State
               -> StackIndex     -- ^ idx
               -> IO StackIndex

-- | Ensures that the stack has space for at least @n@ extra slots (that
-- is, that you can safely push up to @n@ values into it). It returns
-- false if it cannot fulfill the request, either because it would cause
-- the stack to be larger than a fixed maximum size (typically at least
-- several thousand elements) or because it cannot allocate memory for
-- the extra space. This function never shrinks the stack; if the stack
-- already has space for the extra slots, it is left unchanged.
--
-- <https://www.lua.org/manual/5.3/manual.html#lua_checkstack>
foreign import capi unsafe "lua.h lua_checkstack"
  lua_checkstack :: Lua.State -> CInt {- ^ n -} -> IO LuaBool

-- | Destroys all objects in the given Lua state (calling the
-- corresponding garbage-collection metamethods, if any) and frees all
-- dynamic memory used by this state. In several platforms, you may not
-- need to call this function, because all resources are naturally
-- released when the host program ends. On the other hand, long-running
-- programs that create multiple states, such as daemons or web servers,
-- will probably need to close states as soon as they are not needed.
--
-- <https://www.lua.org/manual/5.3/manual.html#lua_close>
foreign import ccall safe "lua.h lua_close"
  lua_close :: Lua.State -> IO ()

-- | Copies the element at index @fromidx@ into the valid index @toidx@,
-- replacing the value at that position. Values at other positions are
-- not affected.
--
-- <https://www.lua.org/manual/5.3/manual.html#lua_copy>
foreign import ccall unsafe "lua.h lua_copy"
  lua_copy :: Lua.State
           -> StackIndex  -- ^ fromidx
           -> StackIndex  -- ^ toidx
           -> IO ()

-- | Creates a new empty table and pushes it onto the stack. Parameter
-- @narr@ is a hint for how many elements the table will have as a
-- sequence; parameter @nrec@ is a hint for how many other elements the
-- table will have. Lua may use these hints to preallocate memory for
-- the new table. This preallocation is useful for performance when you
-- know in advance how many elements the table will have. Otherwise you
-- can use the function @lua_newtable@.
--
-- <https://www.lua.org/manual/5.3/manual.html#lua_createtable>.
foreign import ccall SAFTY "lua.h lua_createtable"
  lua_createtable :: Lua.State
                  -> CInt -- ^ narr
                  -> CInt -- ^ nrec
                  -> IO ()

-- | Controls the garbage collector.
--
-- See the Lua docs at
-- <https://www.lua.org/manual/5.3/manual.html#lua_gc>.
foreign import ccall safe "lua.h lua_gc"
  lua_gc :: Lua.State -> GCCode {- ^ what -} -> CInt {- ^ data -} -> IO CInt

-- | Pushes onto the stack the value of the global name. Returns the
-- type of that value.
--
-- __WARNING__: @lua_getglobal@ is unsafe in Haskell: if the call to a
-- metamethod triggers an error, then that error cannot be handled and
-- will lead to an unrecoverable program crash. Consider using the
-- @'Lua.hslua_getglobal'@ ersatz function instead. Likewise, the
-- metamethod may not call a Haskell function unless the library was
-- compiled without @allow-unsafe-gc@.
--
-- <https://www.lua.org/manual/5.3/manual.html#lua_getglobal>.
foreign import ccall SAFTY "lua.h lua_getglobal"
  lua_getglobal :: State -> CString {- ^ name -} -> IO TypeCode
{-# WARNING lua_getglobal
      [ "This is an unsafe function, errors will lead to a program crash;"
      , "consider using hslua_getglobal instead."
      ] #-}

-- | If the value at the given index has a metatable, the function
-- pushes that metatable onto the stack and returns @1@. Otherwise, the
-- function returns @0@ and pushes nothing on the stack.
--
-- <https://www.lua.org/manual/5.3/manual.html#lua_getmetatable>.
foreign import ccall unsafe "lua.h lua_getmetatable"
  lua_getmetatable :: Lua.State -> StackIndex -> IO LuaBool

-- | Pushes onto the stack the value @t[k]@, where @t@ is the value at
-- the given index and @k@ is the value at the top of the stack.
--
-- This function pops the key from the stack, pushing the resulting
-- value in its place. As in Lua, this function may trigger a metamethod
-- for the \"index\" event (see
-- <https://www.lua.org/manual/5.3/manual.html#2.4 §2.4>).
--
-- Returns the type of the pushed value.
--
-- __WARNING__: @lua_gettable@ is unsafe in Haskell: if the call to a
-- metamethod triggers an error, then that error cannot be handled and
-- will lead to an unrecoverable program crash. Consider using the
-- @'Lua.hslua_gettable'@ ersatz function instead. Likewise, the
-- metamethod may not call a Haskell function unless the library was
-- compiled without @allow-unsafe-gc@.
--
-- <https://www.lua.org/manual/5.3/manual.html#lua_gettable>.
foreign import ccall SAFTY "lua.h lua_gettable"
  lua_gettable :: Lua.State -> StackIndex {- ^ index -} -> IO TypeCode
{-# WARNING lua_gettable
      [ "This is an unsafe function, errors will lead to a program crash;"
      , "consider using hslua_gettable instead."
      ] #-}

-- | Returns the index of the top element in the stack. Because indices
-- start at 1, this result is equal to the number of elements in the
-- stack (and so 0 means an empty stack).
--
-- <https://www.lua.org/manual/5.3/manual.html#lua_gettop>
foreign import ccall unsafe "lua.h lua_gettop"
  lua_gettop :: Lua.State -> IO StackIndex

-- | Moves the top element into the given valid index, shifting up the
-- elements above this index to open space. This function cannot be
-- called with a pseudo-index, because a pseudo-index is not an actual
-- stack position.
--
-- <https://www.lua.org/manual/5.3/manual.html#lua_insert>
foreign import capi unsafe "lua.h lua_insert"
  lua_insert :: Lua.State -> StackIndex -> IO ()

-- | Returns @'Lua.TRUE'@ if the value at the given index is a
-- boolean, and @'Lua.FALSE'@ otherwise.
--
-- <https://www.lua.org/manual/5.3/manual.html#lua_isboolean>
foreign import capi unsafe "lua.h lua_isboolean"
  lua_isboolean :: Lua.State -> StackIndex -> IO LuaBool

-- | Returns @'Lua.TRUE'@ if the value at the given index is a C
-- function, and @'Lua.FALSE'@ otherwise.
--
-- <https://www.lua.org/manual/5.3/manual.html#lua_iscfunction>
foreign import ccall unsafe "lua.h lua_iscfunction"
  lua_iscfunction :: Lua.State -> StackIndex -> IO LuaBool

-- | Returns @'Lua.TRUE'@ if the value at the given index is a
-- function (either C or Lua), and @'Lua.FALSE'@ otherwise.
--
-- <https://www.lua.org/manual/5.3/manual.html#lua_isfunction>
foreign import capi unsafe "lua.h lua_isfunction"
  lua_isfunction :: Lua.State -> StackIndex -> IO LuaBool

-- | Returns @'Lua.TRUE'@ if the value at the given index is an
-- integer (that is, the value is a number and is represented as an
-- integer), and @'Lua.FALSE'@ otherwise.
--
-- <https://www.lua.org/manual/5.3/manual.html#lua_isinteger>
foreign import ccall unsafe "lua.h lua_isinteger"
  lua_isinteger :: Lua.State -> StackIndex -> IO LuaBool

-- | Returns @'Lua.TRUE'@ if the value at the given index is a
-- light userdata, and @'Lua.FALSE'@ otherwise.
--
-- <https://www.lua.org/manual/5.3/manual.html#lua_islightuserdata>
foreign import capi unsafe "lua.h lua_islightuserdata"
  lua_islightuserdata :: Lua.State -> StackIndex -> IO LuaBool

-- | Returns @'Lua.TRUE'@ if the value at the given index is
-- __nil__, and @'Lua.FALSE'@ otherwise.
--
-- <https://www.lua.org/manual/5.3/manual.html#lua_isnil>
foreign import capi unsafe "lua.h lua_isnil"
  lua_isnil :: Lua.State -> StackIndex -> IO LuaBool

-- | Returns @'Lua.TRUE'@ if the given index is not valid, and
-- @'Lua.FALSE'@ otherwise.
--
-- <https://www.lua.org/manual/5.3/manual.html#lua_isnone>
foreign import capi unsafe "lua.h lua_isnone"
  lua_isnone :: Lua.State -> StackIndex -> IO LuaBool

-- | Returns @'Lua.TRUE'@ if the given index is not valid or if
-- the value at the given index is __nil__, and @'Lua.FALSE'@
-- otherwise.
--
-- <https://www.lua.org/manual/5.3/manual.html#lua_isnoneornil>
foreign import capi unsafe "lua.h lua_isnoneornil"
  lua_isnoneornil :: Lua.State -> StackIndex -> IO LuaBool

-- | Returns @'Lua.TRUE'@ if the value at the given index is a
-- number or a string convertible to a number, and @'Lua.FALSE'@
-- otherwise.
--
-- <https://www.lua.org/manual/5.3/manual.html#lua_isnumber>
foreign import ccall unsafe "lua.h lua_isnumber"
  lua_isnumber :: Lua.State -> StackIndex -> IO LuaBool

-- | Returns @'Lua.TRUE'@ if the value at the given index is a
-- string or a number (which is always convertible to a string), and
-- @'Lua.FALSE'@ otherwise.
--
-- <https://www.lua.org/manual/5.3/manual.html#lua_isstring>
foreign import ccall unsafe "lua.h lua_isstring"
  lua_isstring :: Lua.State -> StackIndex -> IO LuaBool

-- | Returns @'Lua.TRUE'@ if the value at the given index is a
-- table, and @'Lua.FALSE'@ otherwise.
--
-- <https://www.lua.org/manual/5.3/manual.html#lua_istable>
foreign import capi unsafe "lua.h lua_istable"
  lua_istable :: Lua.State -> StackIndex -> IO LuaBool

-- | Returns @'Lua.TRUE'@ if the value at the given index is a
-- thread, and @'Lua.FALSE'@ otherwise.
--
-- <https://www.lua.org/manual/5.3/manual.html#lua_isthread>
foreign import capi unsafe "lua.h lua_isthread"
  lua_isthread :: Lua.State -> StackIndex -> IO LuaBool

-- | Returns @'Lua.TRUE'@ if the value at the given index is a
-- userdata (either full or light), and @'Lua.FALSE'@ otherwise.
--
-- <https://www.lua.org/manual/5.3/manual.html#lua_isuserdata>
foreign import ccall unsafe "lua.h lua_isuserdata"
  lua_isuserdata :: Lua.State -> StackIndex -> IO LuaBool

-- | Loads a Lua chunk (without running it). If there are no errors,
-- @lua_load@ pushes the compiled chunk as a Lua function on top of the
-- stack. Otherwise, it pushes an error message.
--
-- The return values of @lua_load@ are:
--
-- - @'Lua.LUA_OK'@: no errors;
-- - @'Lua.LUA_ERRSYNTAX'@: syntax error during pre-compilation;
-- - @'Lua.LUA_ERRMEM'@: memory allocation error;
-- - @'Lua.LUA_ERRGCMM'@: error while running a @__gc@
--   metamethod. (This error has no relation with the chunk being
--   loaded. It is generated by the garbage collector.)
--
-- This function only loads a chunk; it does not run it.
--
-- @lua_load@ automatically detects whether the chunk is text or binary,
-- and loads it accordingly (see program luac).
--
-- The @lua_load@ function uses a user-supplied reader function to
-- read the chunk (see @'Lua.Reader'@). The data argument is an opaque
-- value passed to the reader function.
--
-- The @chunkname@ argument gives a name to the chunk, which is used for
-- error messages and in debug information (see
-- <https://www.lua.org/manual/5.3/manual.html#4.9 §4.9>).
--
-- @lua_load@ automatically detects whether the chunk is text or binary
-- and loads it accordingly (see program @luac@). The string mode works
-- as in function @load@, with the addition that a @NULL@ value is
-- equivalent to the string "bt".
--
-- @lua_load@ uses the stack internally, so the reader function must
-- always leave the stack unmodified when returning.
--
-- <https://www.lua.org/manual/5.3/manual.html#lua_load>.
foreign import ccall safe "lua.h lua_load"
  lua_load :: Lua.State
           -> Lua.Reader     -- ^ reader
           -> Ptr ()         -- ^ data
           -> CString        -- ^ chunkname
           -> CString        -- ^ mode
           -> IO StatusCode

-- | Creates a new thread, pushes it on the stack, and returns a
-- 'Lua.State' that represents this new thread. The new thread returned
-- by this function shares with the original thread its global
-- environment, but has an independent execution stack.
--
-- There is no explicit function to close or to destroy a thread.
-- Threads are subject to garbage collection, like any Lua object.
--
-- <https://www.lua.org/manual/5.3/manual.html#lua_newthread>
foreign import ccall SAFTY "lua.h lua_newthread"
  lua_newthread :: Lua.State -> IO Lua.State

-- | This function allocates a new block of memory with the given size,
-- pushes onto the stack a new full userdata with the block address, and
-- returns this address. The host program can freely use this memory.
--
-- <https://www.lua.org/manual/5.3/manual.html#lua_newuserdata>.
foreign import capi SAFTY "lua.h lua_newuserdata"
  lua_newuserdata :: Lua.State -> CSize -> IO (Ptr ())

-- | Calls a function in protected mode.
--
-- To call a function you must use the following protocol: first, the
-- function to be called is pushed onto the stack; then, the arguments
-- to the function are pushed in direct order; that is, the first
-- argument is pushed first. Finally you call @lua_pcall@; @nargs@ is
-- the number of arguments that you pushed onto the stack. All arguments
-- and the function value are popped from the stack when the function is
-- called. The function results are pushed onto the stack when the
-- function returns. The number of results is adjusted to @nresults@,
-- unless @nresults@ is @'Lua.LUA_MULTRET'@. In this case, all
-- results from the function are pushed. Lua takes care that the
-- returned values fit into the stack space. The function results are
-- pushed onto the stack in direct order (the first result is pushed
-- first), so that after the call the last result is on the top of the
-- stack.
--
-- If there is any error, @lua_pcall@ catches it, pushes a single value
-- on the stack (the error message), and returns the error code.
-- @lua_pcall@ always removes the function and its arguments from the
-- stack.
--
-- If @msgh@ is @0@, then the error object returned on the stack is
-- exactly the original error object. Otherwise, @msgh@ is the location
-- of a message handler. (This index cannot be a pseudo-index.) In case
-- of runtime errors, this function will be called with the error object
-- and its return value will be the object returned on the stack by
-- @'lua_pcall'@.
--
-- Typically, the message handler is used to add more debug information
-- to the error object, such as a stack traceback. Such information
-- cannot be gathered after the return of @'lua_pcall'@, since by then
-- the stack has unwound.
--
-- <https://www.lua.org/manual/5.3/manual.html#lua_pcall>.
foreign import capi safe "lua.h lua_pcall"
  lua_pcall :: Lua.State
            -> NumArgs        -- ^ nargs
            -> NumResults     -- ^ nresults
            -> StackIndex     -- ^ msgh
            -> IO StatusCode

-- | Pops @n@ elements from the stack.
--
-- <https://www.lua.org/manual/5.3/manual.html#lua_pop>
foreign import capi unsafe "lua.h lua_pop"
  lua_pop :: Lua.State -> CInt {- ^ n -} -> IO ()

-- | Pushes a boolean value with the given value onto the stack.
--
-- <https://www.lua.org/manual/5.3/manual.html#lua_pushboolean>.
foreign import ccall unsafe "lua.h lua_pushboolean"
  lua_pushboolean :: Lua.State -> LuaBool -> IO ()

-- | Pushes a new C closure onto the stack.
--
-- When a C function is created, it is possible to associate some values
-- with it, thus creating a C closure (see
-- <https://www.lua.org/manual/5.1/manual.html#3.4 §3.4>); these values
-- are then accessible to the function whenever it is called. To
-- associate values with a C function, first these values should be
-- pushed onto the stack (when there are multiple values, the first
-- value is pushed first). Then lua_pushcclosure is called to create and
-- push the C function onto the stack, with the argument @n@ telling how
-- many values should be associated with the function. lua_pushcclosure
-- also pops these values from the stack.
--
-- The maximum value for @n@ is 255.
--
-- <https://www.lua.org/manual/5.3/manual.html#lua_pushcclosure>.
foreign import ccall SAFTY "lua.h lua_pushcclosure"
  lua_pushcclosure :: Lua.State
                   -> CFunction   -- ^ fn
                   -> NumArgs     -- ^ n
                   -> IO ()

-- | Pushes the global environment onto the stack.
--
-- <https://www.lua.org/manual/5.3/manual.html#lua_pushglobaltable>
foreign import capi unsafe "lua.h lua_pushglobaltable"
  lua_pushglobaltable :: Lua.State -> IO ()

-- | Pushes an integer with with the given value onto the stack.
--
-- <https://www.lua.org/manual/5.3/manual.html#lua_pushinteger>.
foreign import ccall unsafe "lua.h lua_pushinteger"
  lua_pushinteger :: Lua.State -> Lua.Integer -> IO ()

-- | Pushes a light userdata onto the stack.
--
-- Userdata represent C values in Lua. A light userdata represents a
-- pointer, a @Ptr ()@ (i.e., @void*@ in C lingo). It is a value (like a
-- number): you do not create it, it has no individual metatable, and it
-- is not collected (as it was never created). A light userdata is equal
-- to "any" light userdata with the same C address.
--
-- <https://www.lua.org/manual/5.3/manual.html#lua_pushlightuserdata>.
foreign import ccall unsafe "lua.h lua_pushlightuserdata"
  lua_pushlightuserdata :: Lua.State -> Ptr a -> IO ()

-- | Pushes the string pointed to by @s@ with size @len@ onto the stack.
-- Lua makes (or reuses) an internal copy of the given string, so the
-- memory at s can be freed or reused immediately after the function
-- returns. The string can contain any binary data, including embedded
-- zeros.
--
-- Returns a pointer to the internal copy of the string.
--
-- <https://www.lua.org/manual/5.3/manual.html#lua_pushlstring>.
foreign import ccall SAFTY "lua.h lua_pushlstring"
  lua_pushlstring :: Lua.State
                  -> Ptr CChar    -- ^ s
                  -> CSize        -- ^ len
                  -> IO ()

-- | Pushes a nil value onto the stack.
--
-- <https://www.lua.org/manual/5.3/manual.html#lua_pushnil>.
foreign import ccall unsafe "lua.h lua_pushnil"
  lua_pushnil :: Lua.State -> IO ()

-- | Pushes a float with the given value onto the stack.
--
-- <https://www.lua.org/manual/5.3/manual.html#lua_pushnumber>.
foreign import ccall unsafe "lua.h lua_pushnumber"
  lua_pushnumber :: Lua.State -> Lua.Number -> IO ()


-- | Pushes the zero-terminated string pointed to by @s@ onto the stack.
-- Lua makes (or reuses) an internal copy of the given string, so the
-- memory at @s@ can be freed or reused immediately after the function
-- returns.
--
-- Returns a pointer to the internal copy of the string.
--
-- If s is NULL, pushes nil and returns NULL.
foreign import ccall unsafe "lua.h lua_pushstring"
  lua_pushstring :: Lua.State -> CString {- ^ s -} -> IO CString


-- | Pushes the current thread onto the stack. Returns @1@ iff this
-- thread is the main thread of its state.
--
-- <https://www.lua.org/manual/5.3/manual.html#lua_pushthread>.
foreign import ccall unsafe "lua.h lua_pushthread"
  lua_pushthread :: Lua.State -> IO CInt

-- | Pushes a copy of the element at the given index onto the stack.
--
-- <https://www.lua.org/manual/5.3/manual.html#lua_pushvalue>
foreign import ccall unsafe "lua.h lua_pushvalue"
  lua_pushvalue :: Lua.State -> StackIndex -> IO ()

-- | Returns @True@ if the two values in indices @idx1@ and @idx2@ are
-- primitively equal (that is, without calling the @__eq@ metamethod).
-- Otherwise returns @False@. Also returns @False@ if any of the indices
-- are not valid.
--
-- <https://www.lua.org/manual/5.3/manual.html#lua_rawequal>
foreign import ccall unsafe "lua.h lua_rawequal"
  lua_rawequal :: Lua.State
               -> StackIndex  -- ^ idx1
               -> StackIndex  -- ^ idx2
               -> IO LuaBool

-- | Similar to @'lua_gettable'@, but does a raw access (i.e., without
-- metamethods).
--
-- <https://www.lua.org/manual/5.3/manual.html#lua_rawget>.
foreign import ccall unsafe "lua.h lua_rawget"
  lua_rawget :: Lua.State -> StackIndex -> IO ()

-- | Pushes onto the stack the value @t[n]@, where @t@ is the table at
-- the given index. The access is raw, that is, it does not invoke the
-- @__index@ metamethod.
--
-- <https://www.lua.org/manual/5.3/manual.html#lua_rawgeti>.
foreign import ccall unsafe "lua.h lua_rawgeti"
  lua_rawgeti :: Lua.State -> StackIndex -> Lua.Integer {- ^ n -} -> IO ()

-- | Returns the raw "length" of the value at the given index: for
-- strings, this is the string length; for tables, this is the result of
-- the length operator (@#@) with no metamethods; for userdata, this is
-- the size of the block of memory allocated for the userdata; for other
-- values, it is 0.
--
-- <https://www.lua.org/manual/5.3/manual.html#lua_rawlen>.
foreign import ccall unsafe "lua.h lua_rawlen"
  lua_rawlen :: Lua.State -> StackIndex -> IO CSize

-- | Similar to @'lua_settable'@, but does a raw assignment (i.e.,
-- without metamethods).
--
-- <https://www.lua.org/manual/5.3/manual.html#lua_rawset>.
foreign import ccall SAFTY "lua.h lua_rawset"
  lua_rawset :: Lua.State -> StackIndex -> IO ()

-- | Does the equivalent of @t[i] = v@, where @t@ is the table at the
-- given index and @v@ is the value at the top of the stack.
--
-- This function pops the value from the stack. The assignment is raw,
-- that is, it does not invoke the @__newindex@ metamethod.
--
-- <https://www.lua.org/manual/5.3/manual.html#lua_rawseti>.
foreign import ccall SAFTY "lua.h lua_rawseti"
  lua_rawseti :: Lua.State -> StackIndex -> Lua.Integer -> IO ()

-- | Removes the element at the given valid index, shifting down the
-- elements above this index to fill the gap. This function cannot be
-- called with a pseudo-index, because a pseudo-index is not an actual
-- stack position.
--
-- <https://www.lua.org/manual/5.3/manual.html#lua_remove>
foreign import capi unsafe "lua.h lua_remove"
  lua_remove :: Lua.State -> StackIndex -> IO ()

-- | Moves the top element into the given valid index without shifting
-- any element (therefore replacing the value at that given index), and
-- then pops the top element.
--
-- <https://www.lua.org/manual/5.3/manual.html#lua_replace>
foreign import capi unsafe "lua.h lua_replace"
  lua_replace :: Lua.State -> StackIndex -> IO ()

-- | Pops a value from the stack and sets it as the new value of global
-- @name@.
--
-- __WARNING__: @lua_setglobal@ is unsafe in Haskell: if the call to a
-- metamethod triggers an error, then that error cannot be handled and
-- will lead to an unrecoverable program crash. Consider using the
-- @'Lua.hslua_setglobal'@ ersatz function instead. Likewise,
-- the global metamethod may not call a Haskell function unless the
-- library was compiled without @allow-unsafe-gc@.
--
-- <https://www.lua.org/manual/5.3/manual.html#lua_setglobal>.
foreign import ccall SAFTY "lua.h lua_setglobal"
  lua_setglobal :: State -> CString {- ^ name -} -> IO ()
{-# WARNING lua_setglobal
      [ "This is an unsafe function, errors will lead to a program crash;"
      , "consider using hslua_getglobal instead."
      ] #-}

-- | Pops a table from the stack and sets it as the new metatable for
-- the value at the given index.
--
-- <https://www.lua.org/manual/5.3/manual.html#lua_setmetatable>.
foreign import ccall unsafe "lua.h lua_setmetatable"
  lua_setmetatable :: Lua.State -> StackIndex -> IO ()

-- | Does the equivalent to @t[k] = v@, where @t@ is the value at the
-- given index, @v@ is the value at the top of the stack, and @k@ is the
-- value just below the top.
--
-- This function pops both the key and the value from the stack. As in
-- Lua, this function may trigger a metamethod for the \"newindex\"
-- event (see <https://www.lua.org/manual/5.3/manual.html#2.4 §2.4>).
--
-- __WARNING__: @lua_settable@ is unsafe in Haskell: if the call to a
-- metamethod triggers an error, then that error cannot be handled and
-- will lead to an unrecoverable program crash. Consider using the
-- @'Lua.hslua_settable'@ ersatz function instead. Likewise, the
-- metamethod may not call a Haskell function unless the library was
-- compiled without @allow-unsafe-gc@.
--
-- <https://www.lua.org/manual/5.3/manual.html#lua_settable>
foreign import ccall SAFTY "lua.h lua_settable"
  lua_settable :: Lua.State -> StackIndex {- ^ index -} -> IO ()
{-# WARNING lua_settable
      [ "This is an unsafe function, errors will lead to a program crash;"
      , "consider using hslua_settable instead."
      ] #-}

-- | Accepts any index, or 0, and sets the stack top to this index. If
-- the new top is larger than the old one, then the new elements are
-- filled with *nil*. If @index@ is 0, then all stack elements are
-- removed.
--
-- <https://www.lua.org/manual/5.3/manual.html#lua_settop>
foreign import ccall unsafe "lua.h lua_settop"
  lua_settop :: Lua.State -> StackIndex {- ^ index -} -> IO ()

-- |  Returns the status of this Lua thread.
--
-- The status can be @'Lua.LUA_OK'@ for a normal thread, an
-- error value if the thread finished the execution of a @lua_resume@
-- with an error, or @'Lua.LUA_YIELD'@ if the thread is
-- suspended.
--
-- You can only call functions in threads with status
-- @'Lua.LUA_OK'@. You can resume threads with status
-- @'Lua.LUA_OK'@ (to start a new coroutine) or
-- @'Lua.LUA_YIELD'@ (to resume a coroutine).
--
-- <https://www.lua.org/manual/5.3/manual.html#lua_status>.
foreign import ccall unsafe "lua.h lua_status"
  lua_status :: Lua.State -> IO StatusCode

-- | Converts the Lua value at the given index to a haskell boolean
-- value. Like all tests in Lua, @toboolean@ returns @True@ for any Lua
-- value different from *false* and *nil*; otherwise it returns @False@.
-- (If you want to accept only actual boolean values, use
-- @'lua_isboolean'@ to test the value's type.)
--
-- <https://www.lua.org/manual/5.3/manual.html#lua_toboolean>
foreign import capi unsafe "lua.h lua_toboolean"
  lua_toboolean :: Lua.State -> StackIndex -> IO LuaBool

-- | Converts a value at the given index to a C function. That value
-- must be a C function; otherwise, returns @Nothing@.
--
-- <https://www.lua.org/manual/5.3/manual.html#lua_tocfunction>
foreign import ccall unsafe "lua.h lua_tocfunction"
  lua_tocfunction :: Lua.State -> StackIndex -> IO CFunction

-- | Converts the Lua value at the given acceptable index to the signed
-- integral type 'Lua.Integer'. The Lua value must be an integer, a
-- number, or a string convertible to an integer (see
-- <https://www.lua.org/manual/5.3/manual.html#3.4.3 §3.4.3> of the Lua
-- 5.3 Reference Manual); otherwise, @lua_tointegerx@ returns @0@.
--
-- If the number is not an integer, it is truncated in some
-- non-specified way.
--
-- If @isnum@ is not @NULL@, its referent is assigned a boolean value
-- that indicates whether the operation succeeded.
--
-- <https://www.lua.org/manual/5.3/manual.html#lua_tointegerx>
foreign import ccall unsafe "lua.h lua_tointegerx"
  lua_tointegerx :: Lua.State
                 -> StackIndex       -- ^ index
                 -> Ptr LuaBool      -- ^ isnum
                 -> IO Lua.Integer

-- | Converts the Lua value at the given index to a C string. If @len@
-- is not @NULL@, it sets the referent with the string length. The Lua
-- value must be a string or a number; otherwise, the function returns
-- @NULL@. If the value is a number, then @lua_tolstring@ also changes
-- the actual value in the stack to a string. (This change confuses
-- @lua_next@ when @lua_tolstring@ is applied to keys during a table
-- traversal.)
--
-- @lua_tolstring@ returns a pointer to a string inside the Lua state.
-- This string always has a zero ('\0') after its last character (as in
-- C), but can contain other zeros in its body.
--
-- Because Lua has garbage collection, there is no guarantee that the
-- pointer returned by @lua_tolstring@ will be valid after the
-- corresponding Lua value is removed from the stack.
--
-- <https://www.lua.org/manual/5.3/manual.html#lua_tolstring>
foreign import ccall SAFTY "lua.h lua_tolstring"
  lua_tolstring :: Lua.State
                -> StackIndex        -- ^ index
                -> Ptr CSize         -- ^ len
                -> IO (Ptr CChar)

-- | Converts the Lua value at the given index to the C type lua_Number
-- (see lua_Number). The Lua value must be a number or a string
-- convertible to a number (see §3.4.3); otherwise, lua_tonumberx
-- returns 0.
--
-- If @isnum@ is not @NULL@, its referent is assigned a boolean value
-- that indicates whether the operation succeeded.
--
-- <https://www.lua.org/manual/5.3/manual.html#lua_tonumberx>
foreign import ccall unsafe "lua.h lua_tonumberx"
  lua_tonumberx :: Lua.State
                -> StackIndex        -- ^ index
                -> Ptr LuaBool       -- ^ isnum
                -> IO Lua.Number

-- | Converts the value at the given index to a generic C pointer
-- (@void*@). The value can be a userdata, a table, a thread, or a
-- function; otherwise, @lua_topointer@ returns @'nullPtr'@. Different
-- objects will give different pointers. There is no way to convert the
-- pointer back to its original value.
--
-- Typically this function is used only for hashing and debug
-- information.
--
-- <https://www.lua.org/manual/5.3/manual.html#lua_topointer>
foreign import ccall unsafe "lua.h lua_topointer"
  lua_topointer :: Lua.State -> StackIndex -> IO (Ptr ())

-- | Converts the value at the given index to a Lua thread (represented
-- as @'Lua.State'@). This value must be a thread; otherwise, the
-- function returns @'nullPtr'@.
--
-- <https://www.lua.org/manual/5.3/manual.html#lua_tothread>
foreign import ccall unsafe "lua.h lua_tothread"
  lua_tothread :: Lua.State -> StackIndex -> IO Lua.State

-- | If the value at the given index is a full userdata, returns its
-- block address. If the value is a light userdata, returns its pointer.
-- Otherwise, returns @'nullPtr'@.
--
-- <https://www.lua.org/manual/5.3/manual.html#lua_touserdata>
foreign import ccall unsafe "lua.h lua_touserdata"
  lua_touserdata :: Lua.State -> StackIndex -> IO (Ptr a)

-- | Returns the type of the value in the given valid index, or
-- @'Lua.LUA_TNONE'@ for a non-valid (but acceptable) index.
--
-- <https://www.lua.org/manual/5.3/manual.html#lua_type>
foreign import ccall unsafe "lua.h lua_type"
  lua_type :: Lua.State -> StackIndex -> IO TypeCode

-- | Returns the name of the type encoded by the value @tp@, which must
-- be one the values returned by @'lua_type'@.
--
-- <https://www.lua.org/manual/5.3/manual.html#lua_typename>
foreign import ccall unsafe "lua.h lua_typename"
  lua_typename :: Lua.State -> TypeCode {- ^ tp -} -> IO CString
