{-# LANGUAGE NoImplicitPrelude #-}

module Sixteen where

import Prelude
       (Bool(..), Maybe(Nothing), (&&), (+), (-), (||), concat, const,
        drop, map, not, take)

myId :: a -> a
myId a = a

myPlusPlus :: [a] -> [a] -> [a]
myPlusPlus (a:as) bs = a : myPlusPlus as bs
myPlusPlus [] bs = bs

myReverse :: [a] -> [a]
myReverse [] = []
myReverse (a:as) = as `myPlusPlus` [a]
