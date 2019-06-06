module Language.Haskell.LSP.Test.Server (withServer) where

import Control.Concurrent.Async
import Control.Monad
import Language.Haskell.LSP.Test.Compat
import System.IO
import System.Process

withServer :: String -> Bool -> (Handle -> Handle -> Int -> IO a) -> IO a
withServer serverExe logStdErr f = do
  -- TODO Probably should just change runServer to accept
  -- separate command and arguments
  let cmd:args = words serverExe
      createProc = (proc cmd args) { std_in = CreatePipe, std_out = CreatePipe, std_err = CreatePipe }
  withCreateProcess createProc $ \(Just serverIn) (Just serverOut) (Just serverErr) serverProc -> do
    -- Need to continuously consume to stderr else it gets blocked
    -- Can't pass NoStream either to std_err
    hSetBuffering serverErr NoBuffering
    hSetBinaryMode serverErr True
    let errSinkThread = forever $ hGetLine serverErr >>= when logStdErr . putStrLn
    withAsync errSinkThread $ \_ -> do
      pid <- getProcessID serverProc
      f serverIn serverOut pid
