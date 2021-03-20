{-# LANGUAGE CPP #-}
{-# LANGUAGE DeriveFunctor #-}
{-# LANGUAGE OverloadedStrings #-}
{-|
Module      : HsLua.Packaging.Rendering
Copyright   : © 2020-2021 Albert Krewinkel
License     : MIT
Maintainer  : Albert Krewinkel <tarleb+hslua@zeitkraut.de>
Stability   : alpha
Portability : Portable

Render function and module documentation.
-}
module HsLua.Packaging.Rendering
  ( -- * Documentation
    render
  , renderModuleDoc
  , renderFunctionDoc
  ) where

import Data.Text (Text)
import Data.Version (showVersion)
import HsLua.Core
import HsLua.Packaging.Function
import HsLua.Packaging.Module
import qualified Data.Text as T
import qualified Data.Text.Encoding as T

#if !MIN_VERSION_base(4,12,0)
import Data.Semigroup (Semigroup ((<>)))
#endif

--
-- Module documentation
--

-- | Alias for 'renderModuleDoc'.
render :: Module e -> Text
render = renderModuleDoc

-- | Renders module documentation as Markdown.
renderModuleDoc :: Module e -> Text
renderModuleDoc mdl =
  let fields = moduleFields mdl
  in T.unlines
     [ "# " <> T.decodeUtf8 (fromName $ moduleName mdl)
     , ""
     , moduleDescription mdl
     , if null (moduleFields mdl) then "" else renderFields fields
     , "## Functions"
     , ""
     ]
     <> T.intercalate "\n"
        (map (uncurry renderFunctionDoc') (moduleFunctions mdl))

-- | Renders documentation of a function.
renderFunctionDoc' :: Text                  -- ^ name
                   -> DocumentedFunction e  -- ^ function
                   -> Text                  -- ^ function docs
renderFunctionDoc' name fn =
  let fnDoc = functionDoc fn
  in T.intercalate "\n"
     [ "### " <> name <> " (" <> renderFunctionParams fnDoc <> ")"
     , ""
     , renderFunctionDoc fnDoc
     ]

-- | Renders the parameter names of a function, separated by commas.
renderFunctionParams :: FunctionDoc -> Text
renderFunctionParams fd =
    T.intercalate ", "
  . map parameterName
  $ parameterDocs fd

-- | Render documentation for fields as Markdown.
renderFields :: [Field e] -> Text
renderFields fs =
  if null fs
  then mempty
  else T.unlines $ map renderField fs

-- | Renders documentation for a single field.
renderField :: Field e -> Text
renderField f =
  "### " <> fieldName f <> "\n\n" <> fieldDescription f <> "\n"

--
-- Function documentation
--

-- | Renders the documentation of a function as Markdown.
renderFunctionDoc :: FunctionDoc -> Text
renderFunctionDoc (FunctionDoc desc paramDocs resultDoc mVersion) =
  let sinceTag = case mVersion of
        Nothing -> mempty
        Just version -> T.pack $ "\n\n*Since: " <> showVersion version <> "*"
  in (if T.null desc
      then ""
      else desc <> sinceTag <> "\n\n") <>
     renderParamDocs paramDocs <>
     case resultDoc of
       [] -> ""
       rd -> "\nReturns:\n\n" <> T.intercalate "\n" (map renderResultDoc rd)

-- | Renders function parameter documentation as a Markdown blocks.
renderParamDocs :: [ParameterDoc] -> Text
renderParamDocs pds = "Parameters:\n\n" <>
  T.intercalate "\n" (map renderParamDoc pds)

-- | Renders the documentation of a function parameter as a Markdown
-- line.
renderParamDoc :: ParameterDoc -> Text
renderParamDoc pd = mconcat
  [ parameterName pd
  ,  "\n:   "
  , parameterDescription pd
  , " (", parameterType pd, ")\n"
  ]

-- | Renders the documentation of a function result as a Markdown list
-- item.
renderResultDoc :: FunctionResultDoc -> Text
renderResultDoc rd = mconcat
  [ " - "
  , functionResultDescription rd
  , " (", functionResultType rd, ")\n"
  ]
