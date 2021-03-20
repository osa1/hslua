{-# LANGUAGE CPP               #-}
{-# LANGUAGE OverloadedStrings #-}
{-|
Module      : HsLua.Packaging.Module
Copyright   : © 2019-2021 Albert Krewinkel
License     : MIT
Maintainer  : Albert Krewinkel <albert+hslua@zeitkraut.de>
Stability   : alpha
Portability : Requires GHC 8 or later.

Utility functions for HsLua modules.
-}
module HsLua.Packaging.Module
  ( -- * Documented module
    Module (..)
  , Field (..)
  , registerModule
  , preloadModule
  , preloadModuleWithName
  , pushModule
  )
where

import Control.Monad (forM_)
import Data.Text (Text)
import HsLua.Packaging.Function (DocumentedFunction)
import HsLua.Core
import HsLua.Marshalling (pushText)
import qualified HsLua.Packaging.Function as Call

#if !MIN_VERSION_base(4,12,0)
import Data.Semigroup (Semigroup ((<>)))
#endif

-- | Create a new module (i.e., a Lua table).
create :: LuaE e ()
create = newtable

-- | Named and documented Lua module.
data Module e = Module
  { moduleName :: Name
  , moduleDescription :: Text
  , moduleFields :: [Field e]
  , moduleFunctions :: [(Text, DocumentedFunction e)]
  }

-- | Self-documenting module field
data Field e = Field
  { fieldName :: Text
  , fieldDescription :: Text
  , fieldPushValue :: LuaE e ()
  }

-- | Registers a 'Module'; leaves a copy of the module table on
-- the stack.
registerModule :: LuaError e => Module e -> LuaE e ()
registerModule mdl =
  requirehs (moduleName mdl) (pushModule mdl)

-- | Add the module under a different name to the table of preloaded
-- packages.
preloadModuleWithName :: LuaError e => Module e -> Name -> LuaE e ()
preloadModuleWithName documentedModule name = preloadModule $
  documentedModule { moduleName = name }

-- | Preload self-documenting module using the module's default name.
preloadModule :: LuaError e => Module e -> LuaE e ()
preloadModule mdl =
  preloadhs (moduleName mdl) $ do
    pushModule mdl
    return (NumResults 1)

-- | Pushes a documented module to the Lua stack.
pushModule :: LuaError e => Module e -> LuaE e ()
pushModule mdl = do
  create
  forM_ (moduleFunctions mdl) $ \(name, fn) -> do
    pushText name
    Call.pushDocumentedFunction fn
    rawset (nth 3)
  forM_ (moduleFields mdl) $ \field -> do
    pushText (fieldName field)
    fieldPushValue field
    rawset (nth 3)
