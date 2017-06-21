{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE RecordWildCards #-}

module ProjectScoresheet.GameState where

import ClassyPrelude hiding (toLower)
import Control.Lens
import Data.Csv
import ProjectScoresheet.BaseballTypes
import ProjectScoresheet.EventTypes
import ProjectScoresheet.PlayResult
import qualified Data.ByteString.Lazy as BL

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

data Game
  = Game
  { gameHomeTeam :: !(Maybe Text)
  , gameAwayTeam :: !(Maybe Text)
  , gameDate :: !(Maybe Text)
  , gameStartTime :: !(Maybe Text)
  , gameEvents :: ![EventWithState]
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

applyAction :: PlayAction -> FrameState -> FrameState
applyAction (Outs outs) gs = gs & _frameStateOuts %~ (+ batterOuts outs)
applyAction _ gs = gs

updateFrameState :: Event -> FrameState -> FrameState
updateFrameState (PlayEventType (PlayEvent _ _ playerId _ _ (PlayResult action _ movements))) =
  frameState %~ \state -> foldl' (applyRunnerMovement playerId) state movements
  & frameState %~ applyAction action
  & frameState %~ \state' ->
    if frameStateOuts state' == 3
    then initialFrameState
    else state'
updateFrameState _ = id

gamesFromFilePath :: String -> IO [Game]
gamesFromFilePath file = do
  csvEvents <- BL.readFile file
  case (decode NoHeader csvEvents :: Either String (Vector Event)) of
    Left err -> fail err
    Right v -> do
      let
        events = toList v
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
