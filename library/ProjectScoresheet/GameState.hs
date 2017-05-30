{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE ScopedTypeVariables #-}

module ProjectScoresheet.GameState where

import ClassyPrelude
import ProjectScoresheet.RawTypes

data FieldPosition
  = Pitcher
  | Catcher
  | FirstBaseman
  | SecondBaseman
  | ThirdBaseman
  | ShortStop
  | LeftFielder
  | CenterFielder
  | RightFielder
  | DesignatedHitter
  | PinchHitter
  | PinchRunner
  deriving (Eq, Show, Enum)

fieldPositionFromId :: Int -> FieldPosition
fieldPositionFromId fpId = toEnum (fpId - 1)

data LineupSlot
  = LineupSlot
  { lineupSlotPlayerId :: !Text
  , lineupSlotFieldPosition :: FieldPosition
  } deriving (Eq, Show)

data Lineup
  = Lineup
  { lineupSlotOne :: Maybe LineupSlot
  , lineupSlotTwo :: Maybe LineupSlot
  , lineupSlotThree :: Maybe LineupSlot
  , lineupSlotFour :: Maybe LineupSlot
  , lineupSlotFive :: Maybe LineupSlot
  , lineupSlotSix :: Maybe LineupSlot
  , lineupSlotSeven :: Maybe LineupSlot
  , lineupSlotEight :: Maybe LineupSlot
  , lineupSlotNine :: Maybe LineupSlot
  } deriving (Eq, Show)

emptyLineup :: Lineup
emptyLineup = Lineup Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing

data Game
  = Game
  { gameHomeTeam :: !(Maybe Text)
  , gameAwayTeam :: !(Maybe Text)
  , gameDate :: !(Maybe Text)
  , gameStartTime :: !(Maybe Text)
  , gameState :: GameState
  , gameLastPlay :: !(Maybe PlayResult)
  }

unstartedGame :: Game
unstartedGame = Game Nothing Nothing Nothing Nothing unstartedGameState Nothing

data GameState
  = GameState
  { gameStateOuts :: !Int
  , gameStateInning :: !Int
  , gameStateIsLeadOff :: !Bool
  , gameStateHomeLineup :: Lineup
  , gameStateAwayLineup :: Lineup
  , gameStateBatterId :: !(Maybe Text)
  , gameStatePitcherId :: !(Maybe Text)
  , gameStateRunnerFirstBaseId :: !(Maybe Text)
  , gameStateRunnerSecondBaseId :: !(Maybe Text)
  , gameStateRunnerThirdBaseId :: !(Maybe Text)
  } deriving (Eq, Show)

unstartedGameState :: GameState
unstartedGameState = GameState 0 0 False emptyLineup emptyLineup Nothing Nothing Nothing Nothing Nothing
