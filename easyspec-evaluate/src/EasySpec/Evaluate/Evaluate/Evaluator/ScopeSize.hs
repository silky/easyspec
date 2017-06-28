{-# LANGUAGE CPP #-}
{-# LANGUAGE TemplateHaskell #-}

module EasySpec.Evaluate.Evaluate.Evaluator.ScopeSize
    ( scopeSizeEvaluator
    ) where

import Import

import EasySpec.Evaluate.Evaluate.Evaluator.Types

scopeSizeEvaluator :: Evaluator
scopeSizeEvaluator =
    Evaluator
    { evaluatorName = "scope-size"
    , evaluatorGather = Just . genericLength . eiScope
    , evaluatorPretty = show . length . eiScope
    , evaluatorUnit = "#"
    , evaluatorQuantity = "function"
    , evaluatorIndication = Input
    , evaluatorRelevantFiles = [$(mkRelFile __FILE__)]
    }