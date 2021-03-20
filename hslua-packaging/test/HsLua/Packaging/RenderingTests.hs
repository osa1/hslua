{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeApplications #-}
{-|
Module      : HsLua.Packaging.RenderingTests
Copyright   : © 2020-2021 Albert Krewinkel
License     : MIT
Maintainer  : Albert Krewinkel <tarleb+hslua@zeitkraut.de>

Tests for calling exposed Haskell functions.
-}
module HsLua.Packaging.RenderingTests (tests) where

import Data.Maybe (fromMaybe)
import Data.Version (makeVersion)
import HsLua.Core (StackIndex)
import HsLua.Packaging.Function
import HsLua.Packaging.Rendering
import HsLua.Marshalling
  (force, peekIntegral, peekRealFloat, peekText, pushIntegral, pushRealFloat)
import Test.Tasty.HsLua ((=:), shouldBeResultOf)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit ((@=?))

import qualified Data.Text as T
import qualified HsLua.Core as Lua

-- | Calling Haskell functions from Lua.
tests :: TestTree
tests = testGroup "Rendering"
  [ testGroup "Function"
    [ "rendered docs" =:
      (T.unlines
       [ "Calculates the factorial of a positive integer."
       , ""
       , "*Since: 1.0.0*"
       , ""
       , "Parameters:"
       , ""
       , "n"
       , ":   number for which the factorial is computed (integer)"
       , ""
       , "Returns:"
       , ""
       , " - factorial (integer)"
       ]
       @=?
       renderFunctionDoc (functionDoc factorial))
    ]
  , testGroup "Module"
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

factorialResult :: FunctionResults Lua.Exception Integer
factorialResult = (:[]) $ FunctionResult
  (pushIntegral @Integer)
  (FunctionResultDoc "integer" "factorial")

-- | Calculate the nth root of a number. Defaults to square root.
nroot :: DocumentedFunction Lua.Exception
nroot = toHsFnPrecursor nroot'
  <#> parameter (peekRealFloat @Double) "number" "x" ""
  <#> optionalParameter (peekIntegral @Int) "integer" "n" ""
  =#> functionResult pushRealFloat "number" "nth root"
  where
    nroot' :: Double -> Maybe Int -> Lua.LuaE e Double
    nroot' x nOpt =
      let n = fromMaybe 2 nOpt
      in return $ x ** (1 / fromIntegral n)

mymath :: Module Lua.Exception
mymath = Module
  { moduleName = "mymath"
  , moduleDescription = "A math module."
  , moduleFields = []
  , moduleFunctions = [ ("factorial", factorial)]
  }

-- | Calculate the factorial of a number.
factorial :: DocumentedFunction Lua.Exception
factorial = toHsFnPrecursor (\n -> return $ product [1..n])
  <#> factorialParam
  =#> factorialResult
  #? "Calculates the factorial of a positive integer."
  `since` makeVersion [1,0,0]

factorialParam :: Parameter Lua.Exception Integer
factorialParam =
  parameter (peekIntegral @Integer) "integer"
    "n"
    "number for which the factorial is computed"

factorialResult :: FunctionResults Lua.Exception Integer
factorialResult =
  functionResult (pushIntegral @Integer) "integer" "factorial"
