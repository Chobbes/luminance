{-# LANGUAGE CPP #-}

-----------------------------------------------------------------------------
-- |
-- Copyright   : (C) 2015 Dimitri Sabadie
-- License     : BSD3
--
-- Maintainer  : Dimitri Sabadie <dimitri.sabadie@gmail.com>
-- Stability   : experimental
-- Portability : portable
-----------------------------------------------------------------------------

module Graphics.Luminance.Debug where

import Control.Monad ( unless )
import Control.Monad.IO.Class ( MonadIO(..) )
#if DEBUG_GL
import Data.Foldable ( traverse_ )
#endif
import Graphics.GL

--------------------------------------------------------------------------------
-- Clearing errors -------------------------------------------------------------

clearGLError :: (MonadIO m) => m ()
clearGLError = do
  e <- liftIO glGetError
  unless (e == GL_NO_ERROR) clearGLError

--------------------------------------------------------------------------------
-- OpenGL errors ---------------------------------------------------------------

data GLError
  = InvalidEnum
  | InvalidValue
  | InvalidOperation
  | InvalidFramebufferOperation
  | OutOfMemory
  | StackUnderflow
  | StackOverflow
    deriving (Eq,Show)

fromGLError :: GLError -> GLenum
fromGLError e = case e of
  InvalidEnum                 -> GL_INVALID_ENUM
  InvalidValue                -> GL_INVALID_VALUE
  InvalidOperation            -> GL_INVALID_OPERATION
  InvalidFramebufferOperation -> GL_INVALID_FRAMEBUFFER_OPERATION
  OutOfMemory                 -> GL_OUT_OF_MEMORY
  StackUnderflow              -> GL_STACK_UNDERFLOW
  StackOverflow               -> GL_STACK_OVERFLOW

toGLError :: GLenum -> Maybe GLError
toGLError e = case e of
  GL_INVALID_ENUM                  -> Just InvalidEnum
  GL_INVALID_VALUE                 -> Just InvalidValue
  GL_INVALID_OPERATION             -> Just InvalidOperation
  GL_INVALID_FRAMEBUFFER_OPERATION -> Just InvalidFramebufferOperation
  GL_OUT_OF_MEMORY                 -> Just OutOfMemory
  GL_STACK_UNDERFLOW               -> Just StackUnderflow
  GL_STACK_OVERFLOW                -> Just StackOverflow
  _                                -> Nothing

debugGL :: (MonadIO m) => String -> m a -> m a
#if DEBUG_GL
debugGL ctx gl = do
  clearGLError
  a <- gl
  liftIO $ fmap toGLError glGetError >>= traverse_ (\e -> putStrLn ctx >> print e)
  pure a
#else
debugGL = id
#endif