{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE RankNTypes #-}
-- To declera MonadState instances
{-# LANGUAGE UndecidableInstances #-}

module Control.Monad.BP where

import Control.Applicative
import Control.Monad.ST
import Control.Monad.Trans
import Control.Monad.Fix
import Control.Monad.State
-- import Data.STRef
-- import Data.IORef
import Text.Printf

newtype BP m a = BP {
    unBP :: forall r . (a -> m r) -> (BP m a -> m r) -> m r
    }

instance (Monad m) => Monad (BP m) where
    return a = BP $ \done _ -> done a
    fail msg = BP $ \_ _ -> fail msg
    (>>=) = bindBP

bindBP :: (Monad m) => BP m a -> (a -> BP m b) -> BP m b
bindBP ma f = BP $ \done cont -> 
    let i_done a = unBP (f a) done cont
        i_cont k = cont (bindBP k f)
    in unBP ma i_done i_cont

-- cont :: BP m a -> BP m a
-- cont bp = BP $ \_ cont -> cont bp

runBP :: (Monad m) => BP m a -> m (Either (BP m a) a)
runBP bp = unBP bp i_done i_cont
    where i_done a = return (Right a)
          i_cont k = return (Left k)

-- run :: (Monad m) => Yteratee s m a -> m a
-- run i = runCheck i >>= either E.throw return

instance (MonadIO m) => MonadIO (BP m) where
    liftIO = lift . liftIO

instance MonadTrans BP where
    lift m = BP $ \done _ -> m >>= done

instance MonadState s m => MonadState s (BP m) where
    get = lift get
    put a = lift $ put a

instance (Functor m, Monad m) => Functor (BP m) where
  fmap f m = BP $ \done cont ->
    let i_done a = done (f a)
        i_cont k = cont (fmap f k)
    in unBP m i_done i_cont

data BPS s = BPS [Int] s
    deriving (Show)

bps :: (MonadState (BPS s) m) => m [Int]
bps = get >>= \(BPS l _) -> return l

get' :: (MonadState (BPS s) m) => m s
get' = get >>= \(BPS _ s) -> return s

put' :: (MonadState (BPS s) m) => s -> m ()
put' s' = get >>= \(BPS l s) -> put (BPS l s')

modify' :: (MonadState (BPS s) m) => (s->s) -> m ()
modify' f = get >>= \(BPS l s) -> put (BPS l (f s))

loc :: (MonadState (BPS s) m) => Int -> BP m ()
loc ln = BP $ \done cont -> do
    ba <- (elem ln) `liftM` bps
    case ba of
        False -> done ()
        True -> cont (return ())
            -- undefined -- cont (BP $ \_ _ -> done ())

jumpy :: BP (StateT (BPS Int) IO) ()
jumpy = do
    modify' (+ 1)
    s <- get'
    liftIO $ putStrLn (show s)
    loc 1
    if s < 5 then jumpy else return ()

runJumpy :: BP (StateT (BPS Int) IO) a -> BPS Int -> IO a
runJumpy j s = do
    let mjs = runStateT (runBP j) s
    (js, BPS l' i') <- mjs
    case js of
        Left k -> do
            putStrLn $ "break; s = " ++ show i'
            runJumpy k (BPS [1] i')
        Right x -> return x

