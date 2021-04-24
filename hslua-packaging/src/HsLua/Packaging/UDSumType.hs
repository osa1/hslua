{-# LANGUAGE CPP                 #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-|
Module      : HsLua.Packaging.UDSumType
Copyright   : © 2020-2021 Albert Krewinkel
License     : MIT
Maintainer  : Albert Krewinkel <tarleb+hslua@zeitkraut.de>

This module provides types and functions to use Haskell values as
userdata objects in Lua. These objects wrap a Haskell value and provide
methods and properties to interact with the Haskell value.

The terminology in this module refers to the userdata values as /UD
objects/, and to their type as /UD type/.

Note that the values returned by the properties are /copies/ of the
Haskell values; modifying them will not change the underlying Haskell
values.
-}
module HsLua.Packaging.UDSumType
  ( UDSumType (..)
  , defsumtype
  , peekUDSum
  , pushUDSum
  ) where

import Data.Maybe (mapMaybe)
import Data.Map (Map)
#if !MIN_VERSION_base(4,12,0)
import Data.Semigroup (Semigroup ((<>)))
#endif
import HsLua.Core
import HsLua.Marshalling
import HsLua.Packaging.Function
import HsLua.Packaging.Operation
import HsLua.Packaging.UDType
import qualified Data.Map.Strict as Map

-- | A userdata type, capturing the behavior of Lua objects that wrap
-- Haskell values. The type name must be unique; once the type has been
-- used to push or retrieve a value, the behavior can no longer be
-- modified through this type.
data UDSumType e a = UDSumType
  { udSumName          :: Name
  , udSumOperations    :: [(Operation, DocumentedFunction e)]
  , udSumProperties    :: Map Name (Property e a)
  , udSumMethods       :: Map Name (DocumentedFunction e)
  }

-- | Defines a new type, defining the behavior of objects in Lua.
-- Note that the type name must be unique.
defsumtype :: Name                                  -- ^ type name
           -> [(Operation, DocumentedFunction e)]   -- ^ operations
           -> [Member e a]                          -- ^ methods
           -> UDSumType e a
defsumtype name ops members = UDSumType
  { udSumName          = name
  , udSumOperations    = ops
  , udSumProperties    = Map.fromList $ mapMaybe mbproperties members
  , udSumMethods       = Map.fromList $ mapMaybe mbmethods members
  }
  where
    mbproperties = \case
      MemberProperty n p -> Just (n, p)
      _ -> Nothing
    mbmethods = \case
      MemberMethod n m -> Just (n, m)
      _ -> Nothing

peekUDSum :: UDSumType e a -> Peeker e a
peekUDSum = undefined

pushUDSum :: UDSumType e a -> Pusher e a
pushUDSum = undefined
