{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE RecordWildCards #-}

module Baseball.Game.GameState
  ( GameState(..)
  , initialGameState
  , playerAtPosition
  , updateGameState
  , advanceHalfInning
  , currentTeam
  ) where

import ClassyPrelude
import Control.Lens
import Data.HashMap.Strict ((!))

import Baseball.BaseballTypes
import Baseball.Event

data GameState
  = GameState
  { gameStateInning :: Int
  , gameStateInningState :: InningHalf
  , gameStateHomeLineup :: FieldingLineup
  , gameStateAwayLineup :: FieldingLineup
  , gameStateHomeBattingOrder :: BattingOrder
  , gameStateAwayBattingOrder :: BattingOrder
  } deriving (Eq, Show)

makeClassy_ ''GameState

initialGameState :: GameState
initialGameState = GameState 1 TopInningHalf initialFieldingLineup initialFieldingLineup initialBattingOrder initialBattingOrder

updateGameState :: Event -> GameState -> GameState
updateGameState (SubstitutionEvent sub) = processSubstitution sub
updateGameState _ = id

currentTeam :: GameState -> HomeOrAway
currentTeam GameState{..} =
  case gameStateInningState of
    TopInningHalf -> Away
    BottomInningHalf -> Home

playerAtPosition :: FieldingPosition -> GameState -> Text
playerAtPosition pos GameState{..} = case gameStateInningState of
  TopInningHalf -> gameStateHomeLineup ! pos
  BottomInningHalf -> gameStateAwayLineup ! pos

advanceHalfInning :: GameState -> GameState
advanceHalfInning gs =
  case gameStateInningState gs of
    TopInningHalf -> gs &
      _gameStateInningState .~ BottomInningHalf
    BottomInningHalf -> gs &
      _gameStateInning %~ (+1) &
      _gameStateInningState .~ TopInningHalf

processSubstitution :: Substitution -> GameState -> GameState
processSubstitution Substitution{..} =
  case subTeam of
    Away ->
      over _gameStateAwayBattingOrder (addToBattingOrder subPlayer subBattingPosition) .
      over _gameStateAwayLineup (addToFieldingLineup subPlayer subFieldingPosition)
    Home ->
      over _gameStateHomeBattingOrder (addToBattingOrder subPlayer subBattingPosition) .
      over _gameStateHomeLineup (addToFieldingLineup subPlayer subFieldingPosition)
