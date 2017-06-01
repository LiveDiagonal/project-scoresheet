{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE RecordWildCards #-}

module ProjectScoresheet.Print where

import ClassyPrelude hiding (tail)
import Data.List (tail)
import ProjectScoresheet.BaseballTypes
import ProjectScoresheet.GameState
import ProjectScoresheet.BoxScore
import qualified Data.HashMap.Strict as HashMap

prettyPrintGame :: Game -> Text
prettyPrintGame Game{..} =
  unlines
    [ tshow (fromMaybe "" gameAwayTeam) <> "@" <> tshow (fromMaybe "" gameHomeTeam)
    , ""
    , prettyPrintGameState gameState
    ]

prettyPrintGameState :: GameState -> Text
prettyPrintGameState GameState{..} =
  unlines
    [ "Inning: " <> tshow gameStateInning <> ", Outs: " <> tshow gameStateOuts
    , ""
    , "Away: "
    , prettyPrintBattingOrder gameStateAwayBattingOrder
    , "Home: "
    , prettyPrintBattingOrder gameStateAwayBattingOrder
    ]

prettyPrintBattingOrder :: BattingOrder -> Text
prettyPrintBattingOrder battingOrder =
  unlines $ map (\i -> tshow i <> ": " <> battingOrder HashMap.! i) $ tail [(minBound :: BattingPositionId) ..]

prettyPrintBoxScore :: BoxScore -> Text
prettyPrintBoxScore BoxScore{..} =
  unlines
    [ "Home:"
    , prettyPrintTeamBoxScore homeBoxScore
    , "Away:"
    , prettyPrintTeamBoxScore awayBoxScore
    ]

prettyPrintTeamBoxScore :: TeamBoxScore -> Text
prettyPrintTeamBoxScore TeamBoxScore{..} =
  unlines 
    [ "Batting: H"
    , prettyPrintBattingLines batting
    -- , prettyPrintPitching pitching
    ]

prettyPrintBattingLines :: BattingLines -> Text
prettyPrintBattingLines battingLines =
  unlines $ map (\i -> tshow i <> ": " <> prettyPrintBattingLineList (battingLines HashMap.! i)) $ tail [(minBound :: BattingPositionId) ..]

prettyPrintBattingLineList :: [BattingLine] -> Text
prettyPrintBattingLineList battingLines =
  unlines $ map prettyPrintBattingLine battingLines

prettyPrintBattingLine :: BattingLine -> Text
prettyPrintBattingLine BattingLine{..} = battingLinePlayedId <> " " <> tshow battingLineHits


