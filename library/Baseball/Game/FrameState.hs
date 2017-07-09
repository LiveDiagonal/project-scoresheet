{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE RecordWildCards #-}

module Baseball.Game.FrameState
  ( initialFrameState
  , runnerOnBase
  , runnerOnBaseOrBatter
  , updateFrameState
  , FrameState(..)
  ) where

import ClassyPrelude
import Control.Lens

import Baseball.BaseballTypes
import Baseball.Game.GameState
import Baseball.Event
import qualified Data.HashMap.Strict as HashMap

data FrameState
  = FrameState
   { frameStateOuts :: !Int
   , frameStateBatterId :: !(Maybe Text)
   , frameStateRunnerOnFirst :: !(Maybe BaseRunner)
   , frameStateRunnerOnSecond :: !(Maybe BaseRunner)
   , frameStateRunnerOnThird :: !(Maybe BaseRunner)
  } deriving (Eq, Show)

makeClassy_ ''FrameState

initialFrameState :: FrameState
initialFrameState = FrameState 0 Nothing Nothing Nothing Nothing

updateFrameState :: Event -> GameState -> FrameState -> FrameState
updateFrameState (SubstitutionEvent sub) gs fs = processSubstitution sub gs fs
updateFrameState (PlayEvent play) gs fs = processPlay play gs fs

processPlay :: Play -> GameState -> FrameState -> FrameState
processPlay p@(Play playerId _ _ movements) gs fs =
  let
    pitcherId = currentPitcherId gs
    batter = BaseRunner playerId pitcherId
  in fs
    & frameState %~ \state -> foldl' (applyRunnerMovement batter) state movements
    & _frameStateOuts %~ (if isBatterOut p then (+1) else id)

processSubstitution :: Substitution -> GameState -> FrameState -> FrameState
processSubstitution Substitution{..} GameState{..} fs@FrameState{..} =
  let
    replacedBatter :: Text
    replacedBatter = case subTeam of
      Away -> gameStateAwayBattingOrder HashMap.! subBattingPosition
      Home -> gameStateHomeBattingOrder HashMap.! subBattingPosition
  in
    fs
    & over frameState (replaceRunner replacedBatter subPlayer)

replaceRunner :: Text -> Text -> FrameState -> FrameState
replaceRunner originalRunner newRunner fs =
  let
    updateRunner runnerLens = over runnerLens (map (over _baseRunnerPlayerId (\runner -> runner == originalRunner ? newRunner $ runner)))
  in
    foldr updateRunner fs [_frameStateRunnerOnFirst, _frameStateRunnerOnSecond, _frameStateRunnerOnThird]

applyRunnerMovement :: BaseRunner -> FrameState -> PlayMovement -> FrameState
applyRunnerMovement _ gs (PlayMovement HomePlate _ False _) = gs -- Hack: need cleaner way of not double-counting batter outs
applyRunnerMovement _ gs (PlayMovement startBase _ False _) =
  removeRunnerFromBase startBase gs
  & _frameStateOuts %~ (+1)
applyRunnerMovement batter gs (PlayMovement startBase endBase True _) = gs
  & frameState %~ addRunnerToBase (runnerOnBaseOrBatter batter startBase gs) endBase
  & frameState %~ removeRunnerFromBase startBase

removeRunnerFromBase :: Base -> FrameState -> FrameState
removeRunnerFromBase base = addRunnerToBase Nothing base

addRunnerToBase :: Maybe BaseRunner -> Base -> FrameState -> FrameState
addRunnerToBase mBaseRunner base =
  case base of
    FirstBase -> _frameStateRunnerOnFirst .~ mBaseRunner
    SecondBase -> _frameStateRunnerOnSecond .~ mBaseRunner
    ThirdBase -> _frameStateRunnerOnThird .~ mBaseRunner
    _ -> id

runnerOnBase :: Base -> FrameState -> Maybe BaseRunner
runnerOnBase base FrameState{..} =
  case base of
    FirstBase -> frameStateRunnerOnFirst
    SecondBase -> frameStateRunnerOnSecond
    ThirdBase -> frameStateRunnerOnThird
    HomePlate -> Nothing

runnerOnBaseOrBatter :: BaseRunner -> Base -> FrameState -> Maybe BaseRunner
runnerOnBaseOrBatter batter base FrameState{..} =
  case base of
    FirstBase -> frameStateRunnerOnFirst
    SecondBase -> frameStateRunnerOnSecond
    ThirdBase -> frameStateRunnerOnThird
    HomePlate -> Just batter

-- debugEventInFrame :: Event -> FrameState -> FrameState
-- debugEventInFrame (PlayEvent playedid actions _ movements)) fs =
--   trace (show playerId ++ " - " ++ show actions ++ " - " ++ show movements) (debugFrameState fs)
-- debugEventInFrame _ fs = fs

-- debugFrameState :: FrameState -> FrameState
-- debugFrameState fs@FrameState{..} = trace (unlines $ ("Outs: " ++ show frameStateOuts) : catMaybes
--   [ (("1: " ++) . show) <$> frameStateRunnerOnFirstId
--   , (("2: " ++) . show) <$> frameStateRunnerOnSecondId
--   , (("3: " ++) . show) <$> frameStateRunnerOnThirdId
--   ]) fs
