{-# LANGUAGE PatternSynonyms #-}
{-|
Module      : Lua.Constants
Copyright   : © 2007–2012 Gracjan Polak;
              © 2012–2016 Ömer Sinan Ağacan;
              © 2017-2021 Albert Krewinkel
License     : MIT
Maintainer  : Albert Krewinkel <tarleb+hslua@zeitkraut.de>
Stability   : beta
Portability : ForeignFunctionInterface

Lua constants
-}
module Lua.Constants
  ( -- * Special values
    pattern LUA_MULTRET
    -- * Pseudo-indices
  , pattern LUA_REGISTRYINDEX
    -- * Basic types
  , pattern LUA_TNONE
  , pattern LUA_TNIL
  , pattern LUA_TBOOLEAN
  , pattern LUA_TLIGHTUSERDATA
  , pattern LUA_TNUMBER
  , pattern LUA_TSTRING
  , pattern LUA_TTABLE
  , pattern LUA_TFUNCTION
  , pattern LUA_TUSERDATA
  , pattern LUA_TTHREAD
    -- * Status codes
  , pattern LUA_OK
  , pattern LUA_YIELD
  , pattern LUA_ERRRUN
  , pattern LUA_ERRSYNTAX
  , pattern LUA_ERRMEM
  , pattern LUA_ERRERR
  , pattern LUA_ERRFILE
    -- * Relational operator codes
  , pattern LUA_OPEQ
  , pattern LUA_OPLT
  , pattern LUA_OPLE
    -- * Garbage-collection options
  , pattern LUA_GCSTOP
  , pattern LUA_GCRESTART
  , pattern LUA_GCCOLLECT
  , pattern LUA_GCCOUNT
  , pattern LUA_GCCOUNTB
  , pattern LUA_GCSTEP
  , pattern LUA_GCSETPAUSE
  , pattern LUA_GCSETSTEPMUL
  , pattern LUA_GCISRUNNING
    -- * Predefined references
  , pattern LUA_REFNIL
  , pattern LUA_NOREF
    -- * Boolean
  , pattern TRUE
  , pattern FALSE
  ) where

import Foreign.C (CInt (..))
import Lua.Types

#include <lua.h>
#include <lauxlib.h>

--
-- Special values
--

-- | Option for multiple returns in @'Lua.lua_pcall'@.
pattern LUA_MULTRET :: NumResults
pattern LUA_MULTRET = NumResults (#{const LUA_MULTRET})

-- | Stack index of the Lua registry.
pattern LUA_REGISTRYINDEX :: StackIndex
pattern LUA_REGISTRYINDEX = StackIndex (#{const LUA_REGISTRYINDEX})

--
-- Type of Lua values
--
-- | Non-valid stack index
pattern LUA_TNONE :: TypeCode
pattern LUA_TNONE = TypeCode (#{const LUA_TNONE})

-- | Type of Lua's @nil@ value
pattern LUA_TNIL :: TypeCode
pattern LUA_TNIL = TypeCode (#{const LUA_TNIL})

-- | Type of Lua booleans
pattern LUA_TBOOLEAN :: TypeCode
pattern LUA_TBOOLEAN = TypeCode (#{const LUA_TBOOLEAN})

-- | Type of light userdata
pattern LUA_TLIGHTUSERDATA :: TypeCode
pattern LUA_TLIGHTUSERDATA = TypeCode (#{const LUA_TLIGHTUSERDATA})

-- | Type of Lua numbers. See @'Lua.Number'@
pattern LUA_TNUMBER :: TypeCode
pattern LUA_TNUMBER = TypeCode (#{const LUA_TNUMBER})

-- | Type of Lua string values
pattern LUA_TSTRING :: TypeCode
pattern LUA_TSTRING = TypeCode (#{const LUA_TSTRING})

-- | Type of Lua tables
pattern LUA_TTABLE :: TypeCode
pattern LUA_TTABLE = TypeCode (#{const LUA_TTABLE})

-- | Type of functions, either normal or @'CFunction'@
pattern LUA_TFUNCTION :: TypeCode
pattern LUA_TFUNCTION = TypeCode (#{const LUA_TFUNCTION})

-- | Type of full user data
pattern LUA_TUSERDATA :: TypeCode
pattern LUA_TUSERDATA = TypeCode (#{const LUA_TUSERDATA})

-- | Type of Lua threads
pattern LUA_TTHREAD :: TypeCode
pattern LUA_TTHREAD = TypeCode (#{const LUA_TTHREAD})

--
-- Status codes
--

-- | Success.
pattern LUA_OK :: StatusCode
pattern LUA_OK = StatusCode #{const LUA_OK}

-- | Yielding / suspended coroutine.
pattern LUA_YIELD :: StatusCode
pattern LUA_YIELD = StatusCode #{const LUA_YIELD}

-- | A runtime error.
pattern LUA_ERRRUN :: StatusCode
pattern LUA_ERRRUN = StatusCode #{const LUA_ERRRUN}

-- | A syntax error.
pattern LUA_ERRSYNTAX :: StatusCode
pattern LUA_ERRSYNTAX = StatusCode #{const LUA_ERRSYNTAX}

-- | Memory allocation error. For such errors, Lua does not call the
-- message handler.
pattern LUA_ERRMEM :: StatusCode
pattern LUA_ERRMEM = StatusCode #{const LUA_ERRMEM}

-- | Error while running the message handler.
pattern LUA_ERRERR :: StatusCode
pattern LUA_ERRERR = StatusCode #{const LUA_ERRERR}

-- | File related error (e.g., the file cannot be opened or read).
pattern LUA_ERRFILE :: StatusCode
pattern LUA_ERRFILE = StatusCode #{const LUA_ERRFILE}

--
-- Comparison operators
--

-- | Compares for equality (==)
pattern LUA_OPEQ :: OPCode
pattern LUA_OPEQ = OPCode #{const LUA_OPEQ}

-- | Compares for less than (<)
pattern LUA_OPLT :: OPCode
pattern LUA_OPLT = OPCode #{const LUA_OPLT}

-- | Compares for less or equal (<=)
pattern LUA_OPLE :: OPCode
pattern LUA_OPLE = OPCode #{const LUA_OPLE}

--
-- Garbage-collection options
--

-- | Stops the garbage collector.
pattern LUA_GCSTOP :: GCCode
pattern LUA_GCSTOP = GCCode #{const LUA_GCSTOP}

-- | Restarts the garbage collector.
pattern LUA_GCRESTART :: GCCode
pattern LUA_GCRESTART = GCCode #{const LUA_GCRESTART}

-- | Performs a full garbage-collection cycle.
pattern LUA_GCCOLLECT :: GCCode
pattern LUA_GCCOLLECT = GCCode #{const LUA_GCCOLLECT}

-- | Returns the current amount of memory (in Kbytes) in use by Lua.
pattern LUA_GCCOUNT :: GCCode
pattern LUA_GCCOUNT = GCCode #{const LUA_GCCOUNT}

-- | Returns the remainder of dividing the current amount of bytes of
-- memory in use by Lua by 1024.
pattern LUA_GCCOUNTB :: GCCode
pattern LUA_GCCOUNTB = GCCode #{const LUA_GCCOUNTB}

-- | Performs an incremental step of garbage collection.
pattern LUA_GCSTEP :: GCCode
pattern LUA_GCSTEP = GCCode #{const LUA_GCSTEP}

-- | Sets data as the new value for the pause of the collector (see
-- §2.5) and returns the previous value of the pause.
pattern LUA_GCSETPAUSE :: GCCode
pattern LUA_GCSETPAUSE = GCCode #{const LUA_GCSETPAUSE}

-- | Sets data as the new value for the step multiplier of the collector
-- (see §2.5) and returns the previous value of the step multiplier.
pattern LUA_GCSETSTEPMUL :: GCCode
pattern LUA_GCSETSTEPMUL = GCCode #{const LUA_GCSETSTEPMUL}

-- | Returns a boolean that tells whether the collector is running
-- (i.e., not stopped).
pattern LUA_GCISRUNNING :: GCCode
pattern LUA_GCISRUNNING = GCCode #{const LUA_GCISRUNNING}

--
-- Special registry values
--

-- | Value signaling that no reference was created.
pattern LUA_REFNIL :: CInt
pattern LUA_REFNIL = #{const LUA_NOREF}

-- | Value signaling that no reference was found.
pattern LUA_NOREF :: CInt
pattern LUA_NOREF = #{const LUA_NOREF}

--
-- Booleans
--

-- | Value which Lua usually uses as 'True'.
pattern TRUE :: LuaBool
pattern TRUE = LuaBool 1

-- | Value which Lua usually uses as 'False'.
pattern FALSE :: LuaBool
pattern FALSE = LuaBool 0
