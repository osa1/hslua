{-# LANGUAGE CPP #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}
{-|
Module      : HsLua.Module.Path
Copyright   : © 2021 Albert Krewinkel
License     : MIT
Maintainer  : Albert Krewinkel <albert+hslua@zeitkraut.de>

Lua module to work with file paths.
-}
module HsLua.Module.Path (
  -- * Module
    documentedModule

  -- * Fields
  , separator
  , search_path_separator

  -- * Path manipulation
  , add_extension
  , combine
  , directory
  , filename
  , is_absolute
  , is_relative
  , join
  , make_relative
  , normalize
  , split
  , split_extension
  , split_search_path
  , treat_strings_as_paths
  )
where

import Data.Char (toLower)
#if !MIN_VERSION_base(4,11,0)
import Data.Semigroup (Semigroup(..))  -- includes (<>)
#endif
import Data.Text (Text)
import HsLua
  ( LuaError, getglobal, getmetatable, nth, pop, rawset, remove, top )
import HsLua.Call
import HsLua.Module hiding (preloadModule, pushModule)
import HsLua.Peek (Peeker, peekBool, peekList, peekString)
import HsLua.Push (pushBool, pushList, pushString)

import qualified Data.Text as T
import qualified System.FilePath as Path

-- | The @path@ module specification.
documentedModule :: LuaError e => Module e
documentedModule = Module
  { moduleName = "path"
  , moduleDescription = "Module for file path manipulations."
  , moduleFields = fields
  , moduleFunctions = functions
  }

--
-- Fields
--

-- | Exported fields.
fields :: [Field e]
fields =
  [ separator
  , search_path_separator
  ]

-- | Wrapper for @'Path.pathSeparator'@.
separator :: Field e
separator = Field
  { fieldName = "separator"
  , fieldDescription = "The character that separates directories."
  , fieldPushValue = pushString [Path.pathSeparator]
  }

-- | Wrapper for @'Path.searchPathSeparator'@.
search_path_separator :: Field e
search_path_separator = Field
  { fieldName = "search_path_separator"
  , fieldDescription = "The character that is used to separate the entries in "
                    <> "the `PATH` environment variable."
  , fieldPushValue = pushString [Path.searchPathSeparator]
  }

--
-- Functions
--

functions :: LuaError e => [(Text, DocumentedFunction e)]
functions =
  [ ("directory", directory)
  , ("filename", filename)
  , ("is_absolute", is_absolute)
  , ("is_relative", is_relative)
  , ("join", join)
  , ("make_relative", make_relative)
  , ("normalize", normalize)
  , ("split", split)
  , ("split_extension", split_extension)
  , ("split_search_path", split_search_path)
  , ("treat_strings_as_paths", treat_strings_as_paths)
  ]

-- | See @Path.takeDirectory@
directory :: LuaError e => DocumentedFunction e
directory = toHsFnPrecursor (return . Path.takeDirectory)
  <#> filepathParam
  =#> [filepathResult "The filepath up to the last directory separator."]
  #? ("Gets the directory name, i.e., removes the last directory " <>
      "separator and everything after from the given path.")

-- | See @Path.takeFilename@
filename :: LuaError e => DocumentedFunction e
filename = toHsFnPrecursor (return . Path.takeFileName)
  <#> filepathParam
  =#> [filepathResult "File name part of the input path."]
  #? "Get the file name."

-- | See @Path.isAbsolute@
is_absolute :: LuaError e => DocumentedFunction e
is_absolute = toHsFnPrecursor (return . Path.isAbsolute)
  <#> filepathParam
  =#> [booleanResult ("`true` iff `filepath` is an absolute path, " <>
                      "`false` otherwise.")]
  #? "Checks whether a path is absolute, i.e. not fixed to a root."

-- | See @Path.isRelative@
is_relative :: LuaError e => DocumentedFunction e
is_relative = toHsFnPrecursor (return . Path.isRelative)
  <#> filepathParam
  =#> [booleanResult ("`true` iff `filepath` is a relative path, " <>
                      "`false` otherwise.")]
  #? "Checks whether a path is relative or fixed to a root."

-- | See @Path.joinPath@
join :: LuaError e => DocumentedFunction e
join = toHsFnPrecursor (return . Path.joinPath)
  <#> Parameter
      { parameterPeeker = peekList peekFilePath
      , parameterDoc = ParameterDoc
        { parameterName = "filepaths"
        , parameterType = "list of strings"
        , parameterDescription = "path components"
        , parameterIsOptional = False
        }
      }
  =#> [filepathResult "The joined path."]
  #? "Join path elements back together by the directory separator."

make_relative :: LuaError e => DocumentedFunction e
make_relative = toHsFnPrecursor
  (\path root unsafe -> return $ makeRelative path root unsafe)
  <#> parameter
        peekFilePath
        "string"
        "path"
        "path to be made relative"
  <#> parameter
        peekFilePath
        "string"
        "root"
        "root path"
  <#> optionalParameter
        peekBool
        "boolean"
        "unsafe"
        "whether to allow `..` in the result."
  =#> [filepathResult "contracted filename"]
  #? mconcat
     [ "Contract a filename, based on a relative path. Note that the "
     , "resulting path will never introduce `..` paths, as the "
     , "presence of symlinks means `../b` may not reach `a/b` if it "
     , "starts from `a/c`. For a worked example see "
     , "[this blog post](http://neilmitchell.blogspot.co.uk"
     , "/2015/10/filepaths-are-subtle-symlinks-are-hard.html)."
     ]

-- | See @Path.normalise@
normalize :: LuaError e => DocumentedFunction e
normalize = toHsFnPrecursor (return . Path.normalise)
  <#> filepathParam
  =#> [filepathResult "The normalized path."]
  #? T.unlines
     [ "Normalizes a path."
     , ""
     , " - `//` makes sense only as part of a (Windows) network drive;"
     , "   elsewhere, multiple slashes are reduced to a single"
     , "   `path.separator` (platform dependent)."
     , " - `/` becomes `path.separator` (platform dependent)."
     , " - `./` is removed."
     , " - an empty path becomes `.`"
     ]

-- | See @Path.splitDirectories@.
--
-- Note that this does /not/ wrap @'Path.splitPath'@, as that function
-- adds trailing slashes to each directory, which is often inconvenient.
split :: LuaError e => DocumentedFunction e
split = toHsFnPrecursor (return . Path.splitDirectories)
  <#> filepathParam
  =#> [filepathListResult "List of all path components."]
  #? "Splits a path by the directory separator."

-- | See @Path.splitExtension@
split_extension :: LuaError e => DocumentedFunction e
split_extension = toHsFnPrecursor (return . Path.splitExtension)
  <#> filepathParam
  =#> [ FunctionResult
        { fnResultPusher = pushString . fst
        , fnResultDoc = FunctionResultDoc
          { functionResultType = "string"
          , functionResultDescription = "filepath without extension"
          }
        },
        FunctionResult
        { fnResultPusher = pushString . snd
        , fnResultDoc = FunctionResultDoc
          { functionResultType = "string"
          , functionResultDescription = "extension or empty string"
          }
        }
      ]
  #? ("Splits the last extension from a file path and returns the parts. "
      <> "The extension, if present, includes the leading separator; "
      <> "if the path has no extension, then the empty string is returned "
      <> "as the extension.")

-- | Wraps function @'Path.splitSearchPath'@.
split_search_path :: LuaError e => DocumentedFunction e
split_search_path = toHsFnPrecursor (return . Path.splitSearchPath)
  <#> Parameter
      { parameterPeeker = peekString
      , parameterDoc = ParameterDoc
        { parameterName = "search_path"
        , parameterType = "string"
        , parameterDescription = "platform-specific search path"
        , parameterIsOptional = False
        }
      }
  =#> [filepathListResult "list of directories in search path"]
  #? ("Takes a string and splits it on the `search_path_separator` "
      <> "character. Blank items are ignored on Windows, "
      <> "and converted to `.` on Posix. "
      <> "On Windows path elements are stripped of quotes.")

-- | Join two paths with a directory separator. Wraps @'Path.combine'@.
combine :: LuaError e => DocumentedFunction e
combine = toHsFnPrecursor (\fp1 fp2 -> return $ Path.combine fp1 fp2)
  <#> filepathParam
  <#> filepathParam
  =#> [filepathResult "combined paths"]
  #? "Combine two paths with a path separator."

-- | Adds an extension to a file path. Wraps @'Path.addExtension'@.
add_extension :: LuaError e => DocumentedFunction e
add_extension = toHsFnPrecursor (\fp ext -> return $ Path.addExtension fp ext)
  <#> filepathParam
  <#> Parameter
      { parameterPeeker = peekString
      , parameterDoc = ParameterDoc
        { parameterName = "extension"
        , parameterType = "string"
        , parameterDescription = "an extension, with or without separator dot"
        , parameterIsOptional = False
        }
      }
  =#> [filepathResult "filepath with extension"]
  #? "Adds an extension, even if there is already one."

stringAugmentationFunctions :: LuaError e => [(String, DocumentedFunction e)]
stringAugmentationFunctions =
  [ ("directory", directory)
  , ("filename", filename)
  , ("is_absolute", is_absolute)
  , ("is_relative", is_relative)
  , ("normalize", normalize)
  , ("split", split)
  , ("split_extension", split_extension)
  , ("split_search_path", split_search_path)
  ]

treat_strings_as_paths :: LuaError e => DocumentedFunction e
treat_strings_as_paths = toHsFnPrecursor
  ( do
      let addField (k, v) =
            pushString k *> pushDocumentedFunction v *> rawset (nth 3)
      -- for some reason we can't just dump all functions into the
      -- string metatable, but have to use the string module for
      -- non-metamethods.
      pushString "" *> getmetatable top *> remove (nth 2)
      mapM_ addField [("__add", add_extension), ("__div", combine)]
      pop 1  -- string metatable

      _ <- getglobal "string"
      mapM_ addField stringAugmentationFunctions
      pop 1 -- string module
  )
  =#> []
  #? ("Augment the string module such that strings can be used as "
      <> "path objects.")

--
-- Parameters
--

-- | Retrieves a file path from the stack.
peekFilePath :: LuaError e => Peeker e FilePath
peekFilePath = peekString

-- | Filepath function parameter.
filepathParam :: LuaError e => Parameter e FilePath
filepathParam = Parameter
  { parameterPeeker = peekFilePath
  , parameterDoc = ParameterDoc
    { parameterName = "filepath"
    , parameterType = "string"
    , parameterDescription = "path"
    , parameterIsOptional = False
    }
  }

-- | Result of a function returning a file path.
filepathResult :: Text -- ^ Description
               -> FunctionResult e FilePath
filepathResult desc = FunctionResult
  { fnResultPusher = pushString
  , fnResultDoc = FunctionResultDoc
    { functionResultType = "string"
    , functionResultDescription = desc
    }
  }

-- | List of filepaths function result.
filepathListResult :: LuaError e
                   => Text -- ^ Description
                   -> FunctionResult e [FilePath]
filepathListResult desc = FunctionResult
  { fnResultPusher = pushList pushString
  , fnResultDoc = FunctionResultDoc
    { functionResultType = "list of strings"
    , functionResultDescription = desc
    }
  }

-- | Boolean function result.
booleanResult :: Text -- ^ Description
              -> FunctionResult e Bool
booleanResult desc = FunctionResult
  { fnResultPusher = pushBool
  , fnResultDoc = FunctionResultDoc
    { functionResultType = "boolean"
    , functionResultDescription = desc
    }
  }

--
-- Helpers
--

-- | Alternative version of @'Path.makeRelative'@, which introduces @..@
-- paths if desired.
makeRelative :: FilePath      -- ^ path to be made relative
             -> FilePath      -- ^ root directory from which to start
             -> Maybe Bool    -- ^ whether to use unsafe relative paths.
             -> FilePath
makeRelative path root unsafe
 | Path.equalFilePath root path = "."
 | takeAbs root /= takeAbs path = path
 | otherwise = go (dropAbs path) (dropAbs root)
  where
    go x "" = dropWhile Path.isPathSeparator x
    go x y =
      let (x1, x2) = breakPath x
          (y1, y2) = breakPath y
      in case () of
        _ | Path.equalFilePath x1 y1 -> go x2 y2
        _ | unsafe == Just True      -> Path.joinPath ["..", x1, go x2 y2]
        _                            -> path

    breakPath = both (dropWhile Path.isPathSeparator)
              . break Path.isPathSeparator
              . dropWhile Path.isPathSeparator

    both f (a, b) = (f a, f b)

    leadingPathSepOnWindows = \case
      ""                  -> False
      x | Path.hasDrive x -> False
      c:_                 -> Path.isPathSeparator c

    dropAbs x = if leadingPathSepOnWindows x then tail x else Path.dropDrive x

    takeAbs x = if leadingPathSepOnWindows x
                then [Path.pathSeparator]
                else map (\y ->
                            if Path.isPathSeparator y
                            then Path.pathSeparator
                            else toLower y)
                         (Path.takeDrive x)
