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
import qualified HsLua.Core.Unsafe as Unsafe
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
  , propertySet :: Maybe (StackIndex -> a -> LuaE e a)
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
  , propertySet = Just $ \idx x -> do
      value  <- forcePeek $ peek idx
      return $ set x value
  , propertyDescription = desc
  }

-- | Creates a read-only object property. Attempts to set the value will
-- cause an error.
readonly :: Name                 -- ^ property name
         -> Text                 -- ^ property description
         -> (Pusher e b, a -> b) -- ^ how to get the property value
         -> Member e a
readonly name desc (push, get) = MemberProperty name $
  Property
  { propertyGet = \x -> do
      push $ get x
      return (NumResults 1)
  , propertySet = Nothing
  , propertyDescription = desc
  }

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
    add (metamethodName Index)    $ pushcfunction hslua_udindex_ptr
    add (metamethodName Newindex) $ pushcfunction hslua_udnewindex_ptr
    add (metamethodName Pairs)    $ pushHaskellFunction (pairsFunction ty)
    forM_ (udOperations ty) $ \(op, f) -> do
      add (metamethodName op) $ pushDocumentedFunction f
    add "getters" $ pushGetters ty
    add "setters" $ pushSetters ty
    add "methods" $ pushMethods ty
  where
    add :: LuaError e => Name -> LuaE e () -> LuaE e ()
    add name op = do
      pushName name
      op
      rawset (nth 3)

-- | Retrieves a key from a Haskell-data holding userdata value.
--
-- Does the following, in order, and returns the first non-nil result:
--
--   - Checks the userdata's uservalue table for the given key;
--
--   - Looks up a @getter@ for the key and calls it with the userdata
--     and key as arguments;
--
--   - Looks up the key in the table in the @methods@ metafield.
foreign import ccall "hslpackaging.c &hslua_udindex"
  hslua_udindex_ptr :: FunPtr (State -> IO NumResults)

-- | Sets a new value in the userdata caching table via a setter
-- functions.
--
-- The actual assignment is performed by a setter function stored in the
-- @setter@ metafield. Throws an error if no setter function can be
-- found.
foreign import ccall "hslpackaging.c &hslua_udnewindex"
  hslua_udnewindex_ptr :: FunPtr (State -> IO NumResults)

-- | Sets a value in the userdata's caching table (uservalue). Takes the
-- same arguments as a @__newindex@ function.
foreign import ccall "hslpackaging.c &hslua_udsetter"
  hslua_udsetter_ptr :: FunPtr (State -> IO NumResults)

-- | Throws an error nothing that the given key is read-only.
foreign import ccall "hslpackaging.c &hslua_udreadonly"
  hslua_udreadonly_ptr :: FunPtr (State -> IO NumResults)

-- | Pushes the metatable's @getters@ field table.
pushGetters :: LuaError e => UDType e a -> LuaE e ()
pushGetters ty = do
  newtable
  void $ flip Map.traverseWithKey (udProperties ty) $ \name prop -> do
    pushName name
    pushHaskellFunction $ forcePeek (peekUD ty 1) >>= propertyGet prop
    rawset (nth 3)

-- | Pushes the metatable's @setters@ field table.
pushSetters :: LuaError e => UDType e a -> LuaE e ()
pushSetters ty = do
  newtable
  void $ flip Map.traverseWithKey (udProperties ty) $ \name prop -> do
    pushName name
    pushcfunction $ case propertySet prop of
      Just _  -> hslua_udsetter_ptr
      Nothing -> hslua_udreadonly_ptr
    rawset (nth 3)

-- | Pushes the metatable's @methods@ field table.
pushMethods :: LuaError e => UDType e a -> LuaE e ()
pushMethods ty = do
  newtable
  void $ flip Map.traverseWithKey (udMethods ty) $ \name fn -> do
    pushName name
    pushDocumentedFunction fn
    rawset (nth 3)

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
peekUD :: LuaError e => UDType e a -> Peeker e a
peekUD ty idx = do
  let name = udName ty
  x <- reportValueOnFailure name (`fromuserdata` name) idx
  liftLua $ do
    getuservalue idx >>= \case
      TypeTable -> do
        pushnil
        setProperties (udProperties ty) x
      _ -> do
        return x

setProperties :: LuaError e => Map Name (Property e a) -> a -> LuaE e a
setProperties props x = do
  hasNext <- Unsafe.next (nth 2)
  if not hasNext
    then return x
    else ltype (nth 2) >>= \case
      TypeString -> do
        propName <- forcePeek $ peekName (nth 2)
        case Map.lookup propName props of
          Nothing -> pop 1 *> setProperties props x
          Just prop -> case propertySet prop of
            Nothing -> failLua $ "Trying to set read-only property "
                       ++ Utf8.toString (fromName propName)
            Just setter -> do
              x' <- setter top x
              pop 1
              setProperties props x'
      _ -> x <$ pop 1


-- | Defines a function parameter that takes the given type.
udparam :: LuaError e
        => UDType e a      -- ^ expected type
        -> Text            -- ^ parameter name
        -> Text            -- ^ parameter description
        -> Parameter e a
udparam ty = parameter (peekUD ty) (Utf8.toText . fromName $ udName ty)
