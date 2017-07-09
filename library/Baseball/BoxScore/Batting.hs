{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE DeriveGeneric #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}

module Baseball.BoxScore.Batting where

import ClassyPrelude hiding (replicate)
import Control.Lens hiding ((.=))
import qualified Data.ByteString.Lazy as BL
import Data.Csv
import qualified Data.HashMap.Strict as HashMap
import Data.Text (replicate)
import Generics.Deriving.Monoid hiding ((<>))

import Baseball.BaseballTypes
import Baseball.Game.FrameState
import Baseball.Event

type BattingOrderMap = HashMap BattingOrderPosition [Text]

data Batting
  = Batting
  { battingStats :: !(HashMap Text BattingLine)
  , battingOrder :: !BattingOrderMap
  } deriving (Eq, Show)

data BattingLine
  = BattingLine
  { battingLinePlayerId :: !Text
  , battingLineAtBats :: !Int
  , battingLineRuns :: !Int
  , battingLineHits :: !Int
  , battingLineRBI :: !Int
  , battingLineWalks :: !Int
  , battingLineStrikeouts :: !Int
  , battingLineLOB :: !Int
  } deriving (Eq, Show, Generic)

makeClassy_ ''Batting
makeClassy_ ''BattingLine

instance Monoid Int where
  mempty  = 0
  mappend = (+)

instance Monoid BattingLine where
  mempty = initialBattingLine "Total"
  mappend = mappenddefault

playerIdL, atBatsL, runsL, hitsL, rbiL, walksL, strikeoutsL, lobL :: ByteString
playerIdL   = "PlayerID"
atBatsL     = "AtBats"
runsL       = "Runs"
hitsL       = "Hits"
rbiL        = "RBI"
walksL      = "Walks"
strikeoutsL = "Strikeouts"
lobL        = "LOB"

toBattingCsv :: Batting -> BL.ByteString
toBattingCsv Batting{..} = encode $ HashMap.elems battingStats

battingCsvHeader :: Header
battingCsvHeader = header [ playerIdL, atBatsL, runsL, hitsL, rbiL, walksL, strikeoutsL, lobL ]

instance ToNamedRecord BattingLine where
  toNamedRecord BattingLine{..} = namedRecord
    [ playerIdL   .= battingLinePlayerId
    , atBatsL     .= battingLineAtBats
    , runsL       .= battingLineRuns
    , hitsL       .= battingLineHits
    , rbiL        .= battingLineRBI
    , walksL      .= battingLineWalks
    , strikeoutsL .= battingLineStrikeouts
    , lobL        .= battingLineLOB
    ]

instance ToRecord BattingLine where
  toRecord BattingLine{..} = record
    [ toField battingLinePlayerId
    , toField battingLineAtBats
    , toField battingLineRuns
    , toField battingLineHits
    , toField battingLineRBI
    , toField battingLineWalks
    , toField battingLineStrikeouts
    , toField battingLineLOB
    ]

initialBatting :: Batting
initialBatting = Batting HashMap.empty initialBattingOrderMap

initialBattingLine :: Text -> BattingLine
initialBattingLine playerId = BattingLine playerId 0 0 0 0 0 0 0

initialBattingOrderMap :: BattingOrderMap
initialBattingOrderMap = HashMap.fromList $ zip [minBound ..] $ repeat []

addPlayerToBatting :: Text -> BattingOrderPosition -> Batting -> Batting
addPlayerToBatting player battingPosition bs =
  case bs ^. _battingStats . at player of
    Just _ -> bs
    Nothing ->
      bs
      & _battingStats . at player ?~ initialBattingLine player
      & _battingOrder . at battingPosition %~ map (player :)

addPlayToBatting :: Play -> FrameState -> Batting -> Batting
addPlayToBatting play@Play{..} gs b = b
  & batting %~ (if isAtBat play then addAtBatToPlayer playPlayer else id)
  & batting %~ (if isHit play then addHitToPlayer playPlayer else id)
  & batting %~ (if isWalk play then addWalkToPlayer playPlayer else id)
  & batting %~ (if isStrikeout play then addStrikeoutToPlayer playPlayer else id)
  & batting %~ (if isAtBat play && isOut play then addLOB playPlayer play gs else id)
  & batting %~ addRBIToPlayer playPlayer (numRBI play)
  & batting %~ addRuns playPlayer play gs

isOut :: Play -> Bool
isOut Play{..} = flip any playActions $ \a -> case a of
  Strikeout _ -> not $ any isBatterAdvancedOnMovement playMovements
  FieldersChoice _ -> True
  RoutinePlay _ _ -> True
  Error _ -> True
  _ -> False

numNotLeftOnBase :: Play -> Int
numNotLeftOnBase Play{..} =
  length $ filter (\m -> case m of PlayMovement _ HomePlate True _ -> True; _ -> False) playMovements

addLOB :: Text -> Play -> FrameState -> Batting -> Batting
addLOB playerId pr FrameState{..} score =
  let
    numOB = length $ catMaybes [frameStateRunnerOnFirst, frameStateRunnerOnSecond, frameStateRunnerOnThird]
    numLOB = numOB - numNotLeftOnBase pr
  in
    addLOBToPlayer playerId numLOB score

addRunForMovement :: Text ->  FrameState -> PlayMovement -> Batting -> Batting
addRunForMovement _ state (PlayMovement startBase HomePlate True _) score =
  fromMaybe score $ map ((`addRunToPlayer` score) . baseRunnerPlayerId) $ runnerOnBase startBase state
addRunForMovement _ _ _ score = score

addRuns :: Text -> Play -> FrameState -> Batting -> Batting
addRuns player Play{..} state score =
  let
    hitRun = flip any playActions $ \a -> case a of
      Hit HomePlate _ -> True
      _ -> False
    scoreWithRun = if hitRun then addRunToPlayer player score else score
  in
    foldr (addRunForMovement player state) scoreWithRun playMovements

addToPlayer
  :: Text
  -> Int
  -> ASetter BattingLine BattingLine Int Int
  -> Batting
  -> Batting
addToPlayer player num stat bs =
  bs & _battingStats . at player %~ map (stat %~ (+num))

addOneToPlayer
  :: Text
  -> ASetter BattingLine BattingLine Int Int
  -> Batting
  -> Batting
addOneToPlayer player stat = addToPlayer player 1 stat

addLOBToPlayer :: Text -> Int -> Batting -> Batting
addLOBToPlayer player lob = addToPlayer player lob _battingLineLOB

addRunToPlayer :: Text -> Batting -> Batting
addRunToPlayer player = addOneToPlayer player _battingLineRuns

addAtBatToPlayer :: Text -> Batting -> Batting
addAtBatToPlayer player = addOneToPlayer player _battingLineAtBats

addHitToPlayer :: Text -> Batting -> Batting
addHitToPlayer player = addOneToPlayer player _battingLineHits

addRBIToPlayer :: Text -> Int -> Batting -> Batting
addRBIToPlayer player rbi = addToPlayer player rbi _battingLineRBI

addWalkToPlayer :: Text -> Batting -> Batting
addWalkToPlayer player = addOneToPlayer player _battingLineWalks

addStrikeoutToPlayer :: Text -> Batting -> Batting
addStrikeoutToPlayer player = addOneToPlayer player _battingLineStrikeouts

prettyPrintBatting :: Batting -> Text
prettyPrintBatting Batting{..} =
  unlines
    [ "-------------------------------------------"
    , "Batters          AB   R   H RBI  BB  SO LOB"
    , "-------------------------------------------"
    , prettyPrintBattingOrderMap battingOrder battingStats
    ]

prettyPrintBattingOrderMap :: BattingOrderMap -> HashMap Text BattingLine -> Text
prettyPrintBattingOrderMap bom counts =
  let
    (_:hitters) = [(minBound :: BattingOrderPosition) ..]
    battingLines = reverse $ map (counts HashMap.!) $ concatMap (bom HashMap.!) hitters
    battingTotals = mconcat battingLines
    playerLines = unlines $ map (\i ->
        tshow (fromIntegral i :: Integer) <> ": "
        <> prettyPrintBattingLines (map (counts HashMap.!) (bom HashMap.! i))
      ) hitters
  in
    playerLines <> prettyPrintBattingTotals battingTotals

prettyPrintBattingTotals :: BattingLine -> Text
prettyPrintBattingTotals bl =
  unlines
    [ "-------------------------------------------"
    , prettyPrintBattingLine (set _battingLinePlayerId "Total:     " bl)
    ]

prettyPrintBattingLines :: [BattingLine] -> Text
prettyPrintBattingLines [] = ""
prettyPrintBattingLines [x] = prettyPrintBattingLine x
prettyPrintBattingLines (x:xs) = prettyPrintBattingLines xs <> "\n   " <> prettyPrintBattingLine x

prettyPrintBattingLine :: BattingLine -> Text
prettyPrintBattingLine BattingLine{..} = battingLinePlayerId
  <> "    "
  <> prettyColumn (tshow battingLineAtBats)
  <> prettyColumn (tshow battingLineRuns)
  <> prettyColumn (tshow battingLineHits)
  <> prettyColumn (tshow battingLineRBI)
  <> prettyColumn (tshow battingLineWalks)
  <> prettyColumn (tshow battingLineStrikeouts)
  <> prettyColumn (tshow battingLineLOB)

prettyColumn :: Text -> Text
prettyColumn t = replicate (4 - length t) " " <>  t
