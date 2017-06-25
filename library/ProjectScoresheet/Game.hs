{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE RecordWildCards #-}

module ProjectScoresheet.Game where

import ClassyPrelude hiding (toLower)
import Control.Lens
import ProjectScoresheet.BaseballTypes
import ProjectScoresheet.Retrosheet.Events
import ProjectScoresheet.Retrosheet.Parser
import ProjectScoresheet.Play

data Game
  = Game
  { gameHomeTeam :: !(Maybe Text)
  , gameAwayTeam :: !(Maybe Text)
  , gameDate :: !(Maybe Text)
  , gameStartTime :: !(Maybe Text)
  , gameEvents :: ![EventWithState]
  } deriving (Eq, Show)

data EventWithState = EventWithState Event FrameState deriving (Eq, Show)

data GameState
  = GameState
  { gameStateHomeLineup :: FieldingLineup
  , gameStateAwayLineup :: FieldingLineup
  , gameStateInning :: Int
  , gameStateInningState :: InningHalf
  }

data FrameState
  = FrameState
  { frameStateInning :: !Int
  , frameStateInningHalf :: InningHalf
  , frameStateOuts :: !Int
  , frameStateIsPinchHit :: !Bool
  , frameStateBatterId :: !(Maybe Text)
  , frameStateBattingTeam :: !(Maybe HomeOrAway)
  , frameStatePitcherId :: !(Maybe Text)
  , frameStateRunnerOnFirstId :: !(Maybe Text)
  , frameStateRunnerOnSecondId :: !(Maybe Text)
  , frameStateRunnerOnThirdId :: !(Maybe Text)
  } deriving (Eq, Show)

makeClassy_ ''FrameState
makeClassy_ ''Game

initialState :: EventWithState
initialState = EventWithState EmptyEvent initialFrameState

initialFrameState :: FrameState
initialFrameState = FrameState 1 BottomInningHalf 0 False Nothing Nothing Nothing Nothing Nothing Nothing

initialGame :: Game
initialGame = Game Nothing Nothing Nothing Nothing []

removePlayerFromBase :: Base -> FrameState -> FrameState
removePlayerFromBase base = addPlayerToBase Nothing base

addPlayerToBase :: Maybe Text -> Base -> FrameState -> FrameState
addPlayerToBase playerId base =
  case base of
    FirstBase -> _frameStateRunnerOnFirstId .~ playerId
    SecondBase -> _frameStateRunnerOnSecondId .~ playerId
    ThirdBase -> _frameStateRunnerOnThirdId .~ playerId
    _ -> id

playerOnBase :: Text -> Base -> FrameState -> Maybe Text
playerOnBase batterId base FrameState{..} =
  case base of
    FirstBase -> frameStateRunnerOnFirstId
    SecondBase -> frameStateRunnerOnSecondId
    ThirdBase -> frameStateRunnerOnThirdId
    HomePlate -> Just batterId

baseForPlayer :: Text -> FrameState -> Maybe Base
baseForPlayer playerId FrameState{..} =
  find (\base -> (== Just playerId) $ case base of
    FirstBase -> frameStateRunnerOnFirstId
    SecondBase -> frameStateRunnerOnSecondId
    ThirdBase -> frameStateRunnerOnThirdId
    _ -> Nothing) [FirstBase, SecondBase, ThirdBase]

applyRunnerMovement :: Text -> FrameState -> PlayMovement -> FrameState
applyRunnerMovement _ gs (PlayMovement startBase _ False) =
  removePlayerFromBase startBase gs
  & _frameStateOuts %~ (+1)
applyRunnerMovement batterId gs (PlayMovement startBase endBase True) = gs
  & frameState %~ addPlayerToBase (playerOnBase batterId startBase gs) endBase
  & frameState %~ removePlayerFromBase startBase

updateFrameState :: Event -> FrameState -> FrameState
updateFrameState (PlayEventType (PlayEvent _ _ playerId _ _ (Play actions _ movements))) =
  frameState %~ \state -> foldl' (applyRunnerMovement playerId) state movements
  & _frameStateOuts %~ (if any isBatterOutOnAction actions then (+1) else id)
  & frameState %~ \state' ->
    if frameStateOuts state' == 3
    then initialFrameState
    else state'
updateFrameState _ = id

gamesFromFilePath :: String -> IO [Game]
gamesFromFilePath file = do
  events <- retrosheetEventsFromFile file
  let
    frameStates = initialFrameState : zipWith updateFrameState events frameStates
    eventsWithState = zipWith EventWithState events frameStates
  pure $ generateGames eventsWithState

generateGames :: [EventWithState] -> [Game]
generateGames events = reverse $ foldl' (flip updateGame) [] events

updateGame :: EventWithState -> [Game] -> [Game]
updateGame (EventWithState (IdEventType _) _) games = initialGame : games
updateGame event (gs:rest) = addEventToGame event gs : rest
updateGame _ games = games

addEventToGame :: EventWithState -> Game -> Game
addEventToGame event = _gameEvents %~ (++ [event])
