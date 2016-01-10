{-|
Module      : Game.Werewolf.Response
Description : Response and message data structures.

Copyright   : (c) Henry J. Wylde, 2015
License     : BSD3
Maintainer  : public@hjwylde.com

Response and message data structures.
-}

{-# LANGUAGE CPP               #-}
{-# LANGUAGE DeriveGeneric     #-}
{-# LANGUAGE OverloadedStrings #-}

module Game.Werewolf.Response (
    -- * Response
    Response(..),

    -- ** Common responses
    success, failure,

    -- ** Exit functions
    exitWith, exitSuccess, exitFailure,

    -- * Message
    Message(..),
    publicMessage, privateMessage,

    -- ** Game messages
    newGameMessages, seersTurnMessages, villagersTurnMessages, werewolvesTurnMessages,
    playerSeenMessage, playerMadeKillVoteMessage, playerKilledMessage, noPlayerKilledMessage,
    playerMadeLynchVoteMessage, playerLynchedMessage, noPlayerLynchedMessage, gameOverMessage,

    -- ** Error messages
    playerDoesNotExistMessage, playerCannotDoThatMessage, playerCannotDoThatRightNowMessage,
    gameIsOverMessage, playerIsDeadMessage, playerHasAlreadySeenMessage,
    playerHasAlreadyVotedMessage, targetIsDeadMessage,
) where

import Control.Lens
import Control.Monad.IO.Class

import Data.Aeson
#if !MIN_VERSION_aeson(0,10,0)
import Data.Aeson.Types
#endif
import qualified Data.ByteString.Lazy.Char8 as BS
import           Data.List
import           Data.Text                  (Text)
import qualified Data.Text                  as T

import Game.Werewolf.Player
import Game.Werewolf.Role   hiding (name, _name)
import GHC.Generics

import qualified System.Exit as Exit

data Response = Response
    { ok       :: Bool
    , messages :: [Message]
    } deriving (Eq, Generic, Show)

instance FromJSON Response

instance ToJSON Response where
    toJSON      = genericToJSON defaultOptions
#if MIN_VERSION_aeson(0,10,0)
    toEncoding  = genericToEncoding defaultOptions
#endif

success :: Response
success = Response True []

failure :: Response
failure = Response False []

exitWith :: MonadIO m => Response -> m ()
exitWith response = liftIO $ BS.putStrLn (encode response) >> Exit.exitSuccess

exitSuccess :: MonadIO m => m ()
exitSuccess = exitWith success

exitFailure :: MonadIO m => m ()
exitFailure = exitWith failure

data Message = Message
    { to      :: Maybe [Text]
    , message :: Text
    } deriving (Eq, Generic, Show)

instance FromJSON Message

instance ToJSON Message where
    toJSON      = genericToJSON defaultOptions
#if MIN_VERSION_aeson(0,10,0)
    toEncoding  = genericToEncoding defaultOptions
#endif

publicMessage :: Text -> Message
publicMessage = Message Nothing

privateMessage :: [Text] -> Text -> Message
privateMessage to = Message (Just to)

newGameMessages :: [Player] -> [Message]
newGameMessages players = concat [
    seersTurnMessages $ filterSeers players,
    map newPlayerMessage players,
    werewolvesFirstTurnMessages (filterWerewolves players)
    ]

newPlayerMessage :: Player -> Message
newPlayerMessage player = privateMessage [player ^. name] (message' $ player ^. role ^. allegiance)
    where
        message' Villagers  = "ZzZZzz, you're sound asleep."
        message' Werewolves = "You slip away silently from your home."

werewolvesFirstTurnMessages :: [Player] -> [Message]
werewolvesFirstTurnMessages werewolves = map (\werewolf -> privateMessage [werewolf ^. name] (messageFor werewolf)) werewolves
    where
        messageFor werewolf = T.concat $ "As you look around you see the rest of your " : T.intercalate ", " ("pack":names (werewolves \\ [werewolf])) : ["."]
        names = map _name

seersTurnMessages :: [Player] -> [Message]
seersTurnMessages seers = (publicMessage "The seer(s) wake up."):(map (\seer -> privateMessage [seer ^. name] "Who would you like to see?") seers)

villagersTurnMessages :: [Message]
villagersTurnMessages = [publicMessage "The sun rises. Everybody wakes up and opens their eyes..."]

werewolvesTurnMessages :: [Message]
werewolvesTurnMessages = [publicMessage "Night falls, the town is asleep. The werewolves wake up, recognise one another and choose a new victim."]

playerSeenMessage :: Text -> Player -> Message
playerSeenMessage seerName target = privateMessage [seerName] $ T.concat [target ^. name, " is a ", T.pack . init . show $ target ^. role . allegiance, "."]

playerMadeKillVoteMessage :: [Text] -> Text -> Text -> Message
playerMadeKillVoteMessage to voterName targetName = privateMessage to $ T.concat [voterName, " voted to kill ", targetName, "."]

playerKilledMessage :: Text -> Text -> Message
playerKilledMessage name roleName = publicMessage $ T.concat [
    "As you open them you notice a door broken down and ",
    name, "'s guts spilling out over the cobblestones.",
    " From the look of their personal effects, you deduce they were a ", roleName, "."
    ]

noPlayerKilledMessage :: Message
noPlayerKilledMessage = publicMessage "Surprisingly you see everyone present at the town square. Perhaps the werewolves have left Miller's Hollow?"

playerMadeLynchVoteMessage :: Text -> Text -> Message
playerMadeLynchVoteMessage voterName targetName = publicMessage $ T.concat [voterName, " voted to lynch ", targetName, "."]

playerLynchedMessage :: Text -> Text -> Message
playerLynchedMessage name "Werewolf"    = publicMessage $ T.unwords [
    name,
    "is tied up to a pyre and set alight.",
    "As they scream their body starts to contort and writhe, transforming into a werewolf.",
    "Thankfully they go limp before breaking free of their restraints."
    ]
playerLynchedMessage name roleName      = publicMessage $ T.concat [
    name, "is tied up to a pyre and set alight.",
    " Eventually the screams start to die and with their last breath,",
    " they reveal themselves as a ", roleName, "."
    ]

noPlayerLynchedMessage :: Message
noPlayerLynchedMessage = publicMessage "Daylight is wasted as the villagers squabble over whom to tie up. Looks like no one is being burned this day."

gameOverMessage :: Maybe Text -> Message
gameOverMessage Nothing             = publicMessage "The game is over! Everyone died..."
gameOverMessage (Just allegiance)   = publicMessage $ T.unwords ["The game is over! The", allegiance, "have won."]

playerDoesNotExistMessage :: Text -> Text -> Message
playerDoesNotExistMessage to name = privateMessage [to] $ T.unwords ["Player", name, "does not exist."]

playerCannotDoThatMessage :: Text -> Message
playerCannotDoThatMessage name = privateMessage [name] "You cannot do that!"

playerCannotDoThatRightNowMessage :: Text -> Message
playerCannotDoThatRightNowMessage name = privateMessage [name] "You cannot do that right now!"

gameIsOverMessage :: Text -> Message
gameIsOverMessage name = privateMessage [name] "The game is over!"

playerIsDeadMessage :: Text -> Message
playerIsDeadMessage name = privateMessage [name] "Sshh, you're meant to be dead!"

playerHasAlreadySeenMessage :: Text -> Message
playerHasAlreadySeenMessage name = privateMessage [name] "You've already seen!"

playerHasAlreadyVotedMessage :: Text -> Message
playerHasAlreadyVotedMessage name = privateMessage [name] "You've already voted!"

targetIsDeadMessage :: Text -> Text -> Message
targetIsDeadMessage name targetName = privateMessage [name] $ T.unwords [targetName, "is already dead!"]
