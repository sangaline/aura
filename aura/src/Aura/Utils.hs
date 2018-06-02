-- Utility functions specific to Aura

{-

Copyright 2012 - 2018 Colin Woodbury <colin@fosskers.ca>

This file is part of Aura.

Aura is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Aura is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Aura.  If not, see <http://www.gnu.org/licenses/>.

-}

module Aura.Utils where

import Aura.Colour.Text
import Aura.Languages (Language, whitespace, yesNoMessage, yesRegex)
import Aura.Settings.Base
import Aura.Utils.Numbers
import BasePrelude hiding (Version)
import System.IO (stdout, hFlush)
import Text.Regex.PCRE ((=~))
import Utilities (postPad)

---

----------------
-- CUSTOM OUTPUT
----------------
putStrLnA :: MonadIO m => Colouror -> String -> m ()
putStrLnA colour s = putStrA colour $ s <> "\n"

putStrLnA' :: Colouror -> String -> String
putStrLnA' colour s = putStrA' colour s <> "\n"

-- Added `hFlush` here because some output appears to lag sometimes.
putStrA :: MonadIO m => Colouror -> String -> m ()
putStrA colour = liftIO . putStr . putStrA' colour
--putStrA colour s = liftIO (putStr (putStrA' colour s) *> hFlush stdout)

putStrA' :: Colouror -> String -> String
putStrA' colour s = "aura >>= " <> colour s

printList :: MonadIO m => Colouror -> Colouror -> String -> [String] -> m ()
printList _ _ _ []        = pure ()
printList tc ic msg items = liftIO . putStrLn . printList' tc ic msg $ items

printList' :: Colouror -> Colouror -> String -> [String] -> String
printList' tc ic m is = putStrLnA' tc m <> colouredItems
    where colouredItems = is >>= \i -> ic i <> "\n"

----------
-- PROMPTS
----------
-- | Takes a prompt message and a regex of valid answer patterns.
yesNoPrompt :: MonadIO m => Language -> String -> m Bool
yesNoPrompt lang msg = do
  putStrA yellow $ msg <> " " <> yesNoMessage lang <> " "
  liftIO $ hFlush stdout
  response <- liftIO getLine
  pure $ response =~ yesRegex lang

-- | Doesn't prompt when `--noconfirm` is used.
optionalPrompt :: MonadIO m => Settings -> (Language -> String) -> m Bool
optionalPrompt ss msg | mustConfirm ss = yesNoPrompt (langOf ss) (msg $ langOf ss)
                      | otherwise      = pure True

-------
-- MISC
-------

splitNameAndVer :: String -> (String, String)
splitNameAndVer pkg = (before, after)
    where (before, _, after) = pkg =~ "[<>=]+" :: (String, String, String)

splitName :: String -> String
splitName = fst . splitNameAndVer

splitVer :: String -> String
splitVer = snd . splitNameAndVer

sortPkgs :: [String] -> [String]
sortPkgs = sortBy verNums
    where verNums a b | name a /= name b = compare a b  -- Different pkgs
                      | otherwise        = compare (ver a) (ver b)
          name = fst . pkgFileNameAndVer
          ver  = snd . pkgFileNameAndVer

-- Test on:
-- linux-3.2.14-1-x86_64.pkg.tar.xz
-- wine-1.4rc6-1-x86_64.pkg.tar.xz
-- ruby-1.9.3_p125-4-x86_64.pkg.tar.xz
-- NOTE: regex stuff is a little sloppy here.
pkgFileNameAndVer :: String -> (String, Maybe Version)
pkgFileNameAndVer p = (name, verNum')
    where (name, _, _) = p =~ "-[0-9]+" :: (String, String, String)
          verNum     = p =~ ("[0-9][-0-9a-z._]+-" <> archs) :: String
          archs      = "(a|x|i)"  -- Representing "(any|x86_64|i686)"
          verNum'    = version verNum

-- Format two lists into two nice rows a la `-Qi` or `-Si`.
entrify :: Settings -> [String] -> [String] -> String
entrify ss fs es = intercalate "\n" fsEs
    where fsEs = zipWith combine fs' es
          fs'  = padding ss fs
          combine f e = f <> " : " <> e

-- Right-pads strings according to the longest string in the group.
padding :: Settings -> [String] -> [String]
padding ss fs = (\x -> postPad x ws longest) <$> fs
    where ws      = whitespace $ langOf ss
          longest = maximum (length <$> fs)
