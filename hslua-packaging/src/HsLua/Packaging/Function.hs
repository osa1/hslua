{-# LANGUAGE CPP #-}
{-# LANGUAGE DeriveFunctor #-}
{-# LANGUAGE OverloadedStrings #-}
{-|
Module      : HsLua.Packaging.Function
Copyright   : © 2020-2021 Albert Krewinkel
License     : MIT
Maintainer  : Albert Krewinkel <tarleb+hslua@zeitkraut.de>
Stability   : alpha
Portability : Portable

Marshaling and documenting Haskell functions.
-}
module HsLua.Packaging.Function
  ( DocumentedFunction (..)
  , toHsFnPrecursor
  , toHsFnPrecursorWithStartIndex
  , applyParameter
  , returnResult
  , since
  , Parameter (..)
  , FunctionResult (..)
  , FunctionResults
    -- * Operators
  , (<#>)
  , (=#>)
  , (#?)
    -- * Documentation
  , FunctionDoc (..)
  , ParameterDoc (..)
  , FunctionResultDoc (..)
    -- * Pushing to Lua
  , pushDocumentedFunction
    -- * Convenience functions
  , parameter
  , optionalParameter
  , functionResult
  ) where

import Control.Monad.Except
import Data.Text (Text)
import Data.Version (Version)
import HsLua.Core
import HsLua.Marshalling
import qualified Data.Text as T
import qualified HsLua.Core as Lua

#if !MIN_VERSION_base(4,12,0)
import Data.Semigroup (Semigroup ((<>)))
#endif

-- | Lua operation with an additional failure mode that can stack errors
-- from different contexts; errors are not based on exceptions).
type LuaExcept e a = ExceptT PeekError (LuaE e) a

--
-- Function components
--

-- | Result of a call to a Haskell function.
data FunctionResult e a
  = FunctionResult
  { fnResultPusher :: Pusher e a
  , fnResultDoc :: FunctionResultDoc
  }

-- | List of function results in the order in which they are
-- returned in Lua.
type FunctionResults e a = [FunctionResult e a]

-- | Function parameter.
data Parameter e a = Parameter
  { parameterPeeker :: Peeker e a
  , parameterDoc    :: ParameterDoc
  }

-- | Haskell equivallent to CFunction, i.e., function callable
-- from Lua.
data DocumentedFunction e = DocumentedFunction
  { callFunction :: LuaE e NumResults
  , functionDoc :: FunctionDoc
  }

--
-- Documentation
--

-- | Documentation for a Haskell function
data FunctionDoc = FunctionDoc
  { functionDescription :: Text
  , parameterDocs       :: [ParameterDoc]
  , functionResultDocs  :: [FunctionResultDoc]
  , functionSince       :: Maybe Version  -- ^ Version in which the function
                                          -- was introduced.
  }
  deriving (Eq, Ord, Show)

-- | Documentation for function parameters.
data ParameterDoc = ParameterDoc
  { parameterName :: Text
  , parameterType :: Text
  , parameterDescription :: Text
  , parameterIsOptional :: Bool
  }
  deriving (Eq, Ord, Show)

-- | Documentation for the result of a function.
data FunctionResultDoc = FunctionResultDoc
  { functionResultType :: Text
  , functionResultDescription :: Text
  }
  deriving (Eq, Ord, Show)


--
-- Haskell function building
--

-- | Helper type used to create 'HaskellFunction's.
data HsFnPrecursor e a = HsFnPrecursor
  { hsFnPrecursorAction :: LuaExcept e a
  , hsFnMaxParameterIdx :: StackIndex
  , hsFnParameterDocs :: [ParameterDoc]
  }
  deriving (Functor)

-- | Create a HaskellFunction precursor from a pure function.
toHsFnPrecursor :: a -> HsFnPrecursor e a
toHsFnPrecursor = toHsFnPrecursorWithStartIndex (StackIndex 0)

-- | Create a HaskellFunction precursor from a pure function, selecting
-- the stack index after which the first function parameter will be
-- placed.
toHsFnPrecursorWithStartIndex :: StackIndex -> a -> HsFnPrecursor e a
toHsFnPrecursorWithStartIndex idx f = HsFnPrecursor
  { hsFnPrecursorAction = return f
  , hsFnMaxParameterIdx = idx
  , hsFnParameterDocs = mempty
  }

-- | Partially apply a parameter.
applyParameter :: HsFnPrecursor e (a -> b)
               -> Parameter e a
               -> HsFnPrecursor e b
applyParameter bldr param = do
  let action = hsFnPrecursorAction bldr
  let i = hsFnMaxParameterIdx bldr + 1
  let context = "retrieving function argument " <>
        (parameterName . parameterDoc) param
  let nextAction f = withExceptT (pushMsg context) $ do
        x <- ExceptT $ parameterPeeker param i
        return $ f x
  HsFnPrecursor
    { hsFnPrecursorAction = action >>= nextAction
    , hsFnMaxParameterIdx = i
    , hsFnParameterDocs = parameterDoc param : hsFnParameterDocs bldr
    }

-- | Take a 'HaskellFunction' precursor and convert it into a full
-- 'HaskellFunction', using the given 'FunctionResult's to return
-- the result to Lua.
returnResults :: HsFnPrecursor e (LuaE e a)
              -> FunctionResults e a
              -> DocumentedFunction e
returnResults bldr fnResults = DocumentedFunction
  { callFunction = do
      hsResult <- runExceptT $ hsFnPrecursorAction bldr
      case hsResult of
        Left err -> do
          pushString $ formatPeekError err
          Lua.error
        Right x -> do
          result <- x
          forM_ fnResults $ \(FunctionResult push _) -> push result
          return $! NumResults (fromIntegral $ length fnResults)

  , functionDoc = FunctionDoc
    { functionDescription = ""
    , parameterDocs = reverse $ hsFnParameterDocs bldr
    , functionResultDocs = map fnResultDoc fnResults
    , functionSince = Nothing
    }
  }

-- | Like @'returnResult'@, but returns only a single result.
returnResult :: HsFnPrecursor e (LuaE e a)
             -> FunctionResult e a
             -> DocumentedFunction e
returnResult bldr = returnResults bldr . (:[])

-- | Updates the description of a Haskell function. Leaves the function
-- unchanged if it has no documentation.
updateFunctionDescription :: DocumentedFunction e
                          -> Text
                          -> DocumentedFunction e
updateFunctionDescription fn desc =
  let fnDoc = functionDoc fn
  in fn { functionDoc = fnDoc { functionDescription = desc} }

-- | Sets the library version at which the function was introduced in its
-- current form.
since :: DocumentedFunction e -> Version -> DocumentedFunction e
since fn version =
  let fnDoc = functionDoc fn
  in fn { functionDoc = fnDoc { functionSince = Just version  }}

--
-- Operators
--

infixl 8 <#>, =#>, #?, `since`

-- | Inline version of @'applyParameter'@.
(<#>) :: HsFnPrecursor e (a -> b)
      -> Parameter e a
      -> HsFnPrecursor e b
(<#>) = applyParameter

-- | Inline version of @'returnResults'@.
(=#>) :: HsFnPrecursor e (LuaE e a)
      -> FunctionResults e a
      -> DocumentedFunction e
(=#>) = returnResults

-- | Inline version of @'updateFunctionDescription'@.
(#?) :: DocumentedFunction e -> Text -> DocumentedFunction e
(#?) = updateFunctionDescription

--
-- Push to Lua
--

-- | Pushes a documented Haskell function to the Lua stack, making it
-- usable as a normal function in Lua.
pushDocumentedFunction :: LuaError e
                       => DocumentedFunction e -> LuaE e ()
pushDocumentedFunction = Lua.pushHaskellFunction . callFunction

--
-- Convenience functions
--

-- | Creates a parameter.
parameter :: Peeker e a   -- ^ method to retrieve value from Lua
          -> Text         -- ^ expected Lua type
          -> Text         -- ^ parameter name
          -> Text         -- ^ parameter description
          -> Parameter e a
parameter peeker type_ name desc = Parameter
  { parameterPeeker = peeker
  , parameterDoc = ParameterDoc
    { parameterName = name
    , parameterDescription = desc
    , parameterType = type_
    , parameterIsOptional = False
    }
  }

-- | Creates an optional parameter.
optionalParameter :: Peeker e a   -- ^ method to retrieve the value from Lua
                  -> Text         -- ^ expected Lua type
                  -> Text         -- ^ parameter name
                  -> Text         -- ^ parameter description
                  -> Parameter e (Maybe a)
optionalParameter peeker type_ name desc = Parameter
  { parameterPeeker = optional peeker
  , parameterDoc = ParameterDoc
    { parameterName = name
    , parameterDescription = desc
    , parameterType = type_
    , parameterIsOptional = True
    }
  }

-- | Creates a function result.
functionResult :: Pusher e a      -- ^ method to push the Haskell result to Lua
               -> Text            -- ^ Lua type of result
               -> Text            -- ^ result description
               -> FunctionResults e a
functionResult pusher type_ desc = (:[]) $ FunctionResult
  { fnResultPusher = pusher
  , fnResultDoc = FunctionResultDoc
    { functionResultType = type_
    , functionResultDescription = desc
    }
  }
