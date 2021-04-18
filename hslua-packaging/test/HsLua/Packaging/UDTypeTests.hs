{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeApplications #-}
{-|
Module      : HsLua.Packaging.UDTypeTests
Copyright   : © 2020-2021 Albert Krewinkel
License     : MIT
Maintainer  : Albert Krewinkel <tarleb+hslua@zeitkraut.de>

Tests for calling exposed Haskell functions.
-}
module HsLua.Packaging.UDTypeTests (tests) where

import HsLua.Core
import HsLua.Packaging.Function
import HsLua.Packaging.Operation
import HsLua.Packaging.UDType
import HsLua.Marshalling
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HsLua ((=:), shouldBeResultOf, shouldBeErrorMessageOf)
import qualified Data.ByteString.Char8 as Char8

-- | Calling Haskell functions from Lua.
tests :: TestTree
tests = testGroup "UDType"
  [ testGroup "Foo type"
    [ "tostring" =:
      "Foo 7 \"seven\"" `shouldBeResultOf` do
        openlibs
        pushUD typeFoo $ Foo 7 "seven"
        setglobal "foo"
        _ <- dostring "return tostring(foo)"
        forcePeek $ peekText top

    , "show" =:
      "Foo 5 \"five\"" `shouldBeResultOf` do
        openlibs
        pushUD typeFoo $ Foo 5 "five"
        setglobal "foo"
        _ <- dostring "return foo:show()"
        forcePeek $ peekText top

    , "peek" =:
      Foo 37 "ananas" `shouldBeResultOf` do
        pushUD typeFoo $ Foo 37 "ananas"
        forcePeek $ peekUD typeFoo top

    , "get number" =:
      (-1) `shouldBeResultOf` do
        openlibs
        pushUD typeFoo $ Foo (-1) "a"
        setglobal "foo"
        dostring "return foo.num" >>= \case
          OK -> forcePeek $ peekIntegral @Int top
          _ -> throwErrorAsException

    , "get number twice" =:
      8 `shouldBeResultOf` do
        openlibs
        pushUD typeFoo $ Foo 4 "d"
        setglobal "foo"
        dostring "return foo.num + foo.num" >>= \case
          OK -> forcePeek $ peekIntegral @Int top
          _ -> throwErrorAsException

    , "modify number" =:
      Foo (-1) "a" `shouldBeResultOf` do
        openlibs
        pushUD typeFoo $ Foo 1 "a"
        setglobal "foo"
        OK <- dostring "foo.num = -1"
        TypeUserdata <- getglobal "foo"
        forcePeek $ peekUD typeFoo top

    , "get string" =:
      "lint" `shouldBeResultOf` do
        openlibs
        pushUD typeFoo $ Foo 0 "lint"
        setglobal "foo"
        dostring "return foo.str" >>= \case
          OK -> forcePeek $ peekText top
          _ -> throwErrorAsException

    , "cannot change readonly string" =:
      "'str' is a read-only property." `shouldBeErrorMessageOf` do
        openlibs
        pushUD typeFoo $ Foo 2 "b"
        setglobal "foo"
        ErrRun <- dostring "foo.str = 'c'"
        throwErrorAsException :: Lua ()

    , "cannot change unknown property" =:
      "Cannot set unknown property." `shouldBeErrorMessageOf` do
        openlibs
        pushUD typeFoo $ Foo 11 "eleven"
        setglobal "foo"
        ErrRun <- dostring "foo.does_not_exist = nil"
        throwErrorAsException :: Lua ()

    , "pairs iterates over properties" =:
      ["num", "5", "str", "echo", "show", "function"] `shouldBeResultOf` do
        openlibs
        pushUD typeFoo $ Foo 5 "echo"
        setglobal "echo"
        OK <- dostring $ Char8.unlines
          [ "local result = {}"
          , "for k, v in pairs(echo) do"
          , "  table.insert(result, k)"
          , "  table.insert("
          , "    result,"
          , "    type(v) == 'function' and 'function' or tostring(v)"
          , "  )"
          , "end"
          , "return result"
          ]
        forcePeek $ peekList peekText top
    ]

  , testGroup "Bar type"
    [ "Modifying a table modifies the object" =:
      Bar [7, 8] `shouldBeResultOf` do
        openlibs
        pushUD typeBar $ Bar [7]
        setglobal "bar"
        OK <- dostring "table.insert(bar.nums, 8)"
        _ <- getglobal "bar"
        forcePeek $ peekUD typeBar top
    ]
  ]

--
-- Sample types
--

data Foo = Foo Int String
  deriving (Eq, Show)

show' :: LuaError e => DocumentedFunction e
show' = defun "show"
  ### liftPure (show @Foo)
  <#> udparam typeFoo "foo" "Object"
  =#> functionResult pushString "string" "stringified foo"

typeFoo :: LuaError e => UDType e Foo
typeFoo = deftype "Foo"
  [ operation Tostring show'
  ]
  [ property "num" "some number"
      (pushIntegral, \(Foo n _) -> n)
      (peekIntegral, \(Foo _ s) n -> Foo n s)
  , readonly "str" "some string" (pushString, \(Foo _ s) -> s)
  , method show'
  ]

newtype Bar = Bar [Int]
  deriving (Eq, Show)

typeBar :: LuaError e => UDType e Bar
typeBar = deftype "Bar" []
  [ property "nums" "some numbers"
    (pushList pushIntegral, \(Bar nums) -> nums)
    (peekList peekIntegral, \(Bar _) nums -> Bar nums)
  ]
