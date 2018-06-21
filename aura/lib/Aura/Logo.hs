{-# LANGUAGE OverloadedStrings #-}

-- Library for printing an animated AURA version message.

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

module Aura.Logo where

import           Aura.Colour (yellow)
import           BasePrelude
import qualified Data.Text as T
import qualified Data.Text.IO as T
import           System.IO (stdout, hFlush)
import           Utilities (cursorUpLineCode)

---

data MouthState = Open | Closed deriving (Eq)

-- Taken from: figlet -f small "aura"
auraLogo :: T.Text
auraLogo = " __ _ _  _ _ _ __ _ \n" <>
           "/ _` | || | '_/ _` |\n" <>
           "\\__,_|\\_,_|_| \\__,_|"

openMouth :: [T.Text]
openMouth = map yellow
            [ " .--."
            , "/ _.-'"
            , "\\  '-."
            , " '--'" ]

closedMouth :: [T.Text]
closedMouth = map yellow
              [ " .--."
              , "/ _..\\"
              , "\\  ''/"
              , " '--'" ]

pill :: [T.Text]
pill = [ ""
       , ".-."
       , "'-'"
       , "" ]

takeABite :: Int -> IO ()
takeABite pad = drawMouth Closed *> drawMouth Open
    where drawMouth mouth = do
            traverse_ T.putStrLn $ renderPacmanHead pad mouth
            raiseCursorBy 4
            hFlush stdout
            threadDelay 125000

drawPills :: Int -> IO ()
drawPills numOfPills = traverse_ T.putStrLn pills
    where pills = renderPills numOfPills

raiseCursorBy :: Int -> IO ()
raiseCursorBy = T.putStr . raiseCursorBy'

raiseCursorBy' :: Int -> T.Text
raiseCursorBy' = cursorUpLineCode

clearGrid :: IO ()
clearGrid = T.putStr blankLines *> raiseCursorBy 4
    where blankLines = fold . replicate 4 . padString 23 $ "\n"

renderPill :: Int -> [T.Text]
renderPill pad = padString pad <$> pill

renderPills :: Int -> [T.Text]
renderPills numOfPills = take numOfPills pillPostitions >>= render
    where pillPostitions = [17, 12, 7]
          render pos = renderPill pos <> [raiseCursorBy' 5]

renderPacmanHead :: Int -> MouthState -> [T.Text]
renderPacmanHead pad Open   = map (padString pad) openMouth
renderPacmanHead pad Closed = map (padString pad) closedMouth

padString :: Int -> T.Text -> T.Text
padString pad cs = T.justifyRight (pad + T.length cs) ' ' cs
