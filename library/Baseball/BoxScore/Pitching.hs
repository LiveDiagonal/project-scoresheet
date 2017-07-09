{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE DeriveGeneric #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}

module Baseball.BoxScore.Pitching
  ( Pitching
  , initialPitching
  , addPlayerToPitching
  , addPlayToPitching
  , prettyPrintPitching
  ) where

import ClassyPrelude hiding (replicate)
import Control.Lens

import Baseball.BaseballTypes
import Baseball.Game.FrameState
import Baseball.Game.GameState
import Baseball.Play
import Retrosheet.Events
import Data.HashMap.Strict.InsOrd (InsOrdHashMap)
import Data.Text (replicate)
import qualified Data.HashMap.Strict.InsOrd as InsOrdHashMap
import Generics.Deriving.Monoid hiding ((<>))

data Pitching
  = Pitching
  { pitchingStats :: !(InsOrdHashMap Text PitchingLine)
  } deriving (Eq, Show)

data PitchingLine
  = PitchingLine
  { pitchingLinePlayerId :: !Text
  , pitchingLineStrikeouts :: !Int
  , pitchingLineWalks :: !Int
  , pitchingLineHits :: !Int
  , pitchingLineHomeRuns :: !Int
  , pitchingLineRuns :: !Int
  } deriving (Eq, Show, Generic)

makeClassy_ ''Pitching
makeClassy_ ''PitchingLine

instance Monoid Int where
  mempty  = 0
  mappend = (+)

instance Monoid PitchingLine where
  mempty = initialPitchingLine "Total"
  mappend = mappenddefault

initialPitching :: Pitching
initialPitching = Pitching InsOrdHashMap.empty

initialPitchingLine :: Text -> PitchingLine
initialPitchingLine player = PitchingLine player 0 0 0 0 0

addPlayerToPitching :: Text -> FieldingPosition -> Pitching -> Pitching
addPlayerToPitching player Pitcher = _pitchingStats %~ (at player ?~ initialPitchingLine player)
addPlayerToPitching _ _ = id

addPlayToPitching :: PlayEvent -> GameState -> FrameState -> Pitching -> Pitching
addPlayToPitching PlayEvent{..} gs@GameState{..} fs p =
  let
    pitcherId = pitcherIdWhenBatting gs playEventHomeOrAway
    batter = BaseRunner playEventPlayerId pitcherId
  in
    p &
    pitching %~ (if isHit playEventResult then addHitToPitcher pitcherId else id) &
    pitching %~ (if isHomeRun playEventResult then addHomeRunToPitcher pitcherId else id) &
    pitching %~ (if isStrikeout playEventResult then addStrikeoutToPitcher pitcherId else id) &
    pitching %~ (if isWalk playEventResult then addWalkToPitcher pitcherId else id) &
    pitching %~ addRunsToPitchers fs batter playEventResult

addToPitcher
  :: Text
  -> Int
  -> ASetter PitchingLine PitchingLine Int Int
  -> Pitching
  -> Pitching
addToPitcher pitcher num stat =
  _pitchingStats . at pitcher %~ map (stat %~ (+num))

addOneToPitcher
  :: Text
  -> ASetter PitchingLine PitchingLine Int Int
  -> Pitching
  -> Pitching
addOneToPitcher pitcher stat = addToPitcher pitcher 1 stat

addHitToPitcher :: Text -> Pitching -> Pitching
addHitToPitcher pitcher = addOneToPitcher pitcher _pitchingLineHits

addHomeRunToPitcher :: Text -> Pitching -> Pitching
addHomeRunToPitcher pitcher = addOneToPitcher pitcher _pitchingLineHomeRuns

addStrikeoutToPitcher :: Text -> Pitching -> Pitching
addStrikeoutToPitcher pitcher = addOneToPitcher pitcher _pitchingLineStrikeouts

addWalkToPitcher :: Text -> Pitching -> Pitching
addWalkToPitcher pitcher = addOneToPitcher pitcher _pitchingLineWalks

addRunToPitcher :: Text -> Pitching -> Pitching
addRunToPitcher pitcher = addOneToPitcher pitcher _pitchingLineRuns

chargePitcherForMovement :: FrameState -> BaseRunner -> PlayMovement -> Pitching -> Pitching
chargePitcherForMovement fs batter (PlayMovement startBase HomePlate True) =
  let
    Just BaseRunner{..} = runnerOnBaseOrBatter batter startBase fs
  in
    addRunToPitcher baseRunnerResponsiblePitcherId
chargePitcherForMovement _ _ _ = id

addRunsToPitchers :: FrameState -> BaseRunner -> Play -> Pitching -> Pitching
addRunsToPitchers fs batter Play{..} p = foldr (chargePitcherForMovement fs batter) p playMovements

prettyPrintPitching :: Pitching -> Text
prettyPrintPitching Pitching{..} = unlines
  [ "-------------------------------------------"
  , "Pitchers        IP   H   R   ER   W  SO  HR"
  , "-------------------------------------------"
  , prettyPrintPitchingLines pitchingStats
  , "-------------------------------------------"
  , prettyPrintPitchingLine $ set _pitchingLinePlayerId "Total:  " $ mconcat (InsOrdHashMap.elems pitchingStats)
  ]

prettyPrintPitchingLines :: InsOrdHashMap Text PitchingLine -> Text
prettyPrintPitchingLines pls = unlines $ map prettyPrintPitchingLine (InsOrdHashMap.elems pls)

prettyPrintPitchingLine :: PitchingLine -> Text
prettyPrintPitchingLine PitchingLine{..} = pitchingLinePlayerId
  <> "          "
  <> prettyColumn (tshow pitchingLineHits)
  <> prettyColumn (tshow pitchingLineRuns)
  <> "     "
  <> prettyColumn (tshow pitchingLineWalks)
  <> prettyColumn (tshow pitchingLineStrikeouts)
  <> prettyColumn (tshow pitchingLineHomeRuns)

prettyColumn :: Text -> Text
prettyColumn t = replicate (4 - length t) " " <>  t
