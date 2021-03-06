{-|
Module      : Werewolf.Commands.Quit
Description : Handler for the quit subcommand.

Copyright   : (c) Henry J. Wylde, 2015
License     : BSD3
Maintainer  : public@hjwylde.com

Handler for the quit subcommand.
-}

{-# LANGUAGE OverloadedStrings #-}

module Werewolf.Commands.Quit (
    -- * Handle
    handle,
) where

import Control.Monad.Except
import Control.Monad.Extra
import Control.Monad.State
import Control.Monad.Writer

import Data.Text (Text)

import Game.Werewolf.Command
import Game.Werewolf.Engine   hiding (isVillagersTurn)
import Game.Werewolf.Response

-- | Handle.
handle :: MonadIO m => Text -> m ()
handle callerName = do
    unlessM doesGameExist $ exitWith failure {
        messages = [privateMessage [callerName] "No game is running."]
        }

    game <- readGame

    let command = quitCommand callerName

    case runExcept (runWriterT $ execStateT (apply command >> checkTurn >> checkGameOver) game) of
        Left errorMessages      -> exitWith failure { messages = errorMessages }
        Right (game', messages) -> writeGame game' >> exitWith success { messages = messages }
