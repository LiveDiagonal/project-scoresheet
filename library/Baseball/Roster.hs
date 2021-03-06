{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE RecordWildCards #-}

module Baseball.Roster
  ( rosterFromFile
  ) where

import ClassyPrelude
import qualified Data.ByteString.Lazy as ByteString
import Data.Csv
import qualified Data.HashMap.Strict as HashMap

data Handedness = LeftHanded | RightHanded | BothHanded deriving (Eq, Show)

instance FromField Handedness where
  parseField "L" = pure LeftHanded
  parseField "R" = pure RightHanded
  parseField "B" = pure BothHanded
  parseField val = fail $ "Unrecognized value: " ++ show val

type Roster = HashMap Text RosterEntry

data RosterEntry
  = RosterEntry
  { rosterEntryPlayerId :: Text
  , rosterEntryLastName :: Text
  , rosterEntryFirstName :: Text
  , rosterEntryBats :: Handedness
  , rosterEntryThrows :: Handedness
  , rosterEntryTeam :: Text
  , rosterEntryPosition :: Text
  } deriving (Eq, Show, Generic)

instance FromRecord RosterEntry

addEntryToRoster :: RosterEntry -> Roster -> Roster
addEntryToRoster re@RosterEntry{..} = HashMap.insert rosterEntryPlayerId re

rosterFromFile :: String -> IO Roster
rosterFromFile file = do
  csvRosterEntries <- ByteString.readFile file
  case (decode NoHeader csvRosterEntries :: Either String (Vector RosterEntry)) of
    Left err -> fail err
    Right v -> return $ foldl' (flip addEntryToRoster) HashMap.empty v
