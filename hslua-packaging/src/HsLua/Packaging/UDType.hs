{-# LANGUAGE CPP                 #-}
{-# LANGUAGE ForeignFunctionInterface #-}
{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-|
Module      : HsLua.Packaging.UDType
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
module HsLua.Packaging.UDType
  ( UDType (..)
  , deftype
  , method
  , property
  , readonly
  , operation
  , peekUD
  , pushUD
  , udparam
    -- * Helper types for building
  , Member
  , Property
  , Operation
  ) where

import Control.Monad.Except
import Foreign.Ptr (FunPtr)
import Data.Maybe (mapMaybe)
import Data.Map (Map)
#if !MIN_VERSION_base(4,12,0)
import Data.Semigroup (Semigroup ((<>)))
#endif
import Data.Text (Text)
import HsLua.Core
import HsLua.Marshalling
import HsLua.Packaging.Function
import HsLua.Packaging.Operation
import qualified Data.Map.Strict as Map
import qualified HsLua.Core.Utf8 as Utf8

-- | A userdata type, capturing the behavior of Lua objects that wrap
-- Haskell values. The type name must be unique; once the type has been
-- used to push or retrieve a value, the behavior can no longer be
-- modified through this type.
data UDType e a = UDType
  { udName          :: Name
  , udOperations    :: [(Operation, DocumentedFunction e)]
  , udProperties    :: Map Name (Property e a)
  , udMethods       :: Map Name (DocumentedFunction e)
  }

-- | Defines a new type, defining the behavior of objects in Lua.
-- Note that the type name must be unique.
deftype :: Name                                  -- ^ type name
        -> [(Operation, DocumentedFunction e)]   -- ^ operations
        -> [Member e a]                          -- ^ methods
        -> UDType e a
deftype name ops members = UDType
  { udName          = name
  , udOperations    = ops
  , udProperties    = Map.fromList $ mapMaybe mbproperties members
  , udMethods       = Map.fromList $ mapMaybe mbmethods members
  }
  where
    mbproperties = \case
      MemberProperty n p -> Just (n, p)
      _ -> Nothing
    mbmethods = \case
      MemberMethod n m -> Just (n, m)
      _ -> Nothing

-- | A read- and writable property on a UD object.
data Property e a = Property
  { propertyGet :: a -> LuaE e NumResults
  , propertySet :: StackIndex -> a -> LuaE e a
  , propertyDescription :: Text
  }

-- | A type member, either a method or a variable.
data Member e a
  = MemberProperty Name (Property e a)
  | MemberMethod Name (DocumentedFunction e)

-- | Use a documented function as an object method.
method :: DocumentedFunction e -> Member e a
method f = MemberMethod (functionName f) f

-- | Declares a new read- and writable property.
property :: LuaError e
         => Name                       -- ^ property name
         -> Text                       -- ^ property description
         -> (Pusher e b, a -> b)       -- ^ how to get the property value
         -> (Peeker e b, a -> b -> a)  -- ^ how to set a new property value
         -> Member e a
property name desc (push, get) (peek, set) = MemberProperty name $
  Property
  { propertyGet = \x -> do
      push $ get x
      return (NumResults 1)
  , propertySet = \idx x -> do
      value  <- forcePeek $ peek idx
      return $ set x value
  , propertyDescription = desc
  }

-- | Creates a read-only object property. Attempts to set the value will
-- cause an error.
readonly :: LuaError e
         => Name                 -- ^ property name
         -> Text                 -- ^ property description
         -> (Pusher e b, a -> b) -- ^ how to get the property value
         -> Member e a
readonly name desc getter = property name desc getter $
  let msg = "'" <> fromName name <> "' is a read-only property."
  in (const (failPeek msg), const)

-- | Declares a new object operation from a documented function.
operation :: Operation             -- ^ the kind of operation
          -> DocumentedFunction e  -- ^ function used to perform the operation
          -> (Operation, DocumentedFunction e)
operation op f = (,) op $ setName (metamethodName op) f

-- | Pushes the metatable for the given type to the Lua stack. Creates
-- the new table afresh on the first time it is needed, and retrieves it
-- from the registry after that.
pushUDMetatable :: LuaError e => UDType e a -> LuaE e ()
pushUDMetatable ty = do
  created <- newudmetatable (udName ty)
  when created $ do
    add (metamethodName Shl)      $ pushcfunction hslua_test
    add (metamethodName Index)    $ pushHaskellFunction (indexFunction ty)
    add (metamethodName Newindex) $ pushHaskellFunction (newindexFunction ty)
    add (metamethodName Pairs)    $ pushHaskellFunction (pairsFunction ty)
    forM_ (udOperations ty) $ \(op, f) -> do
      add (metamethodName op) $ pushDocumentedFunction f
  where
    add :: LuaError e => Name -> LuaE e () -> LuaE e ()
    add name op = do
      pushName name
      op
      rawset (nth 3)

foreign import ccall "hslpackaging.c &hslua_test"
  hslua_test :: FunPtr (State -> IO NumResults)

-- | Pushes the function used to access object properties and methods.
-- This is expected to be used with the /Index/ operation.
indexFunction :: LuaError e => UDType e a -> LuaE e NumResults
indexFunction ty = do
  x    <- forcePeek $ peekUD ty (nthBottom 1)
  name <- forcePeek $ peekName (nthBottom 2)
  case Map.lookup name (udProperties ty) of
    Just p -> propertyGet p x
    Nothing -> case Map.lookup name (udMethods ty) of
                 Just m -> 1 <$ pushDocumentedFunction m
                 Nothing -> failLua $
                            "no key " ++ Utf8.toString (fromName name)

-- | Pushes the function used to modify object properties.
-- This is expected to be used with the /Newindex/ operation.
newindexFunction :: LuaError e => UDType e a -> LuaE e NumResults
newindexFunction ty = do
  x     <- forcePeek $ peekUD ty (nthBottom 1)
  name  <- forcePeek $ peekName (nthBottom 2)
  case Map.lookup name (udProperties ty) of
    Just p -> do
      newx <- propertySet p (nthBottom 3) x
      success <- putuserdata (nthBottom 1) (udName ty) newx
      if success
        then return (NumResults 0)
        else failLua "Could not set userdata value."
    Nothing -> failLua $ "no key " ++ Utf8.toString (fromName name)

-- | Pushes the function used to iterate over the object's key-value
-- pairs in a generic *for* loop.
pairsFunction :: forall e a. LuaError e => UDType e a -> LuaE e NumResults
pairsFunction ty = do
  obj <- forcePeek $ peekUD ty (nthBottom 1)
  let pushMember = \case
        MemberProperty name prop -> do
          pushName name
          getresults <- propertyGet prop obj
          return $ getresults + 1
        MemberMethod name f -> do
          pushName name
          pushDocumentedFunction f
          return 2
  pushIterator pushMember $
    map (uncurry MemberProperty) (Map.toAscList (udProperties ty)) ++
    map (uncurry MemberMethod) (Map.toAscList (udMethods ty))

-- | Pushes a userdata value of the given type.
pushUD :: LuaError e => UDType e a -> a -> LuaE e ()
pushUD ty x = do
  newhsuserdata x
  pushUDMetatable ty
  setmetatable (nth 2)

-- | Retrieves a userdata value of the given type.
peekUD :: UDType e a -> Peeker e a
peekUD ty = do
  let name = udName ty
  reportValueOnFailure name (`fromuserdata` name)

-- | Defines a function parameter that takes the given type.
udparam :: UDType e a      -- ^ expected type
        -> Text            -- ^ parameter name
        -> Text            -- ^ parameter description
        -> Parameter e a
udparam ty = parameter (peekUD ty) (Utf8.toText . fromName $ udName ty)
