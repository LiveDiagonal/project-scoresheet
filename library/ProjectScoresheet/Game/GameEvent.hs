{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE ScopedTypeVariables #-}

module ProjectScoresheet.Game.GameEvent
  ( GameEvent(..)
  , initialGameEvent
  , nextGameEvent
  ) where

import ClassyPrelude

import ProjectScoresheet.Game.GameState
import ProjectScoresheet.Game.FrameState
import ProjectScoresheet.Retrosheet.Events

data GameEvent = 
  GameEvent 
  { gameEventEvent :: Event
  , gameEventGameState :: GameState
  , gameEventFrameState :: FrameState 
  } deriving (Eq, Show)

initialGameEvent :: Event -> GameEvent
initialGameEvent event = GameEvent event initialGameState initialFrameState

nextGameEvent :: Event -> GameEvent -> GameEvent
nextGameEvent event previousGameEvent =
  let
    nextGameState = updateGameState (gameEventEvent previousGameEvent) (gameEventGameState previousGameEvent)
    nextFrameState = updateFrameState (gameEventEvent previousGameEvent) (gameEventFrameState previousGameEvent)
  in
    GameEvent event nextGameState nextFrameState
