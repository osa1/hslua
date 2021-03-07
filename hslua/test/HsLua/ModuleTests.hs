{-# LANGUAGE CPP               #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeApplications  #-}
{-|
Module      : HsLua.ModuleTests
Copyright   : © 2019-2021 Albert Krewinkel
License     : MIT
Maintainer  : Albert Krewinkel <albert+hslua@zeitkraut.de>
Stability   : alpha
Portability : Requires GHC 8 or later.

Tests creating and loading of modules with Haskell.
-}
module HsLua.ModuleTests (tests) where

import HsLua.Call hiding (render)
import HsLua.Module
import HsLua.Peek (peekIntegral)
import HsLua.Push (pushIntegral)
import Test.Tasty.HsLua ((=:), pushLuaExpr, shouldBeResultOf)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit ((@=?))

import qualified Data.Text as T
import qualified HsLua as Lua

-- | Specifications for Attributes parsing functions.
tests :: TestTree
tests = testGroup "Module"
  [ testGroup "requirehs"
    [ "pushes module to stack" =:
      1 `shouldBeResultOf` do
        Lua.openlibs
        old <- Lua.gettop
        requirehs "foo" (Lua.pushnumber 5.0)
        new <- Lua.gettop
        return (new - old)

    , "module can be loaded with `require`" =:
      let testModule = "string as a module"
      in Just testModule `shouldBeResultOf` do
        Lua.openlibs
        requirehs "test.module" (Lua.pushstring testModule)
        pushLuaExpr "require 'test.module'"
        Lua.tostring Lua.top
    ]

  , testGroup "preloadhs"
    [ "does not modify the stack" =:
      0 `shouldBeResultOf` do
        Lua.openlibs
        old <- Lua.gettop
        preloadhs "foo" (1 <$ Lua.pushnumber 5.0)
        new <- Lua.gettop
        return (new - old)

    , "module can be loaded with `require`" =:
      let testModule = "string as a module"
      in Just testModule `shouldBeResultOf` do
        Lua.openlibs
        preloadhs "test.module" (1 <$ Lua.pushstring testModule)
        pushLuaExpr "require 'test.module'"
#if MIN_VERSION_lua(3,0,0)
        Lua.tostring (Lua.nth 2)
#else
        Lua.tostring Lua.top
#endif
    ]

  , testGroup "creation helpers"
    [ "create produces a table" =:
      Lua.TypeTable `shouldBeResultOf` do
        create
        Lua.ltype Lua.top
    ]
  , testGroup "module type"
    [ "register module" =:
      1 `shouldBeResultOf` do
        Lua.openlibs
        old <- Lua.gettop
        registerModule mymath
        new <- Lua.gettop
        return (new - old)

    , "call module function" =:
      Right 24 `shouldBeResultOf` do
        Lua.openlibs
        registerModule mymath
        _ <- Lua.dostring $ mconcat
             [ "local mymath = require 'mymath'\n"
             , "return mymath.factorial(4)"
             ]
        peekIntegral @Integer Lua.top
    ]
  , testGroup "documentation"
    [ "module docs" =:
      (T.intercalate "\n"
        [ "# mymath"
        , ""
        , "A math module."
        , ""
        , "## Functions"
        , ""
        , "### factorial (n)"
        , ""
        , "Parameters:"
        , ""
        , "n"
        , ":   number for which the factorial is computed (integer)"
        , ""
        , "Returns:"
        , ""
        , " - factorial (integer)\n"
        ] @=?
        render mymath)
    ]
  ]

mymath :: Module Lua.Exception
mymath = Module
  { moduleName = "mymath"
  , moduleDescription = "A math module."
  , moduleFields = []
  , moduleFunctions = [ ("factorial", factorial)]
  }

factorial :: DocumentedFunction Lua.Exception
factorial = toHsFnPrecursor (\n -> product [1..n])
  <#> factorialParam
  =#> factorialResult

factorialParam :: Parameter Lua.Exception Integer
factorialParam =
  parameter (peekIntegral @Integer) "integer"
    "n"
    "number for which the factorial is computed"

factorialResult :: FunctionResults Lua.Exception Integer
factorialResult =
  functionResult (pushIntegral @Integer) "integer" "factorial"
