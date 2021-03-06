{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE OverloadedStrings #-}

module EasySpec.Evaluate.Analyse.Plots.CorrelatingPoints
    ( correlatingPointsPlotterAll
    , correlatingPointsPlotterPerGroup
    , correlatingPointsPlotterPerGroupExample
    , correlatingPointsPlotterPerGroupStrategy
    ) where

import Import

import Development.Shake
import Development.Shake.Path

import qualified EasySpec.Discover.Types as ES

import EasySpec.Evaluate.Types

import EasySpec.Evaluate.Evaluate.Evaluator.Types

import EasySpec.Evaluate.Analyse.Plots.Files
import EasySpec.Evaluate.Analyse.Plots.Plotter
import EasySpec.Evaluate.Analyse.R

{-# ANN module ("HLint: ignore Reduce duplication" :: String) #-}

correlatingPointsPlotterPerGroup ::
       EvaluatedCartPlotter (GroupName, OrderedDistinct Evaluator)
correlatingPointsPlotterPerGroup =
    CartPlotter
    { cartPlotterName = "correlating-points"
    , cartPlotterFunc = plotsRulesForPointsPlotsWithGroupsOfExamples
    }

plotsRulesForPointsPlotWithEvaluatorsPerExample ::
       Path Abs File
    -> Action (Path Abs File)
    -> (GroupAndExample, OrderedDistinct Evaluator)
    -> Rules ()
plotsRulesForPointsPlotWithEvaluatorsPerExample plotF genDataF (GE _ is, OrderedDistinct (Pair e1 e2)) =
    plotF $%> do
        dataF <- genDataF
        needP [dataF]
        scriptF <- pointsPlotAnalysisScript
        rscript
            scriptF
            [ toFilePath dataF
            , toFilePath plotF
            , evaluatorName e1
            , evaluatorName e2
            , toFilePath $ ES.inputSpecFile is
            , prettyIndication $ evaluatorIndication e1
            , prettyIndication $ evaluatorIndication e2
            ]

correlatingPointsPlotterPerGroupExample ::
       EvaluatedCartPlotter (GroupAndExample, OrderedDistinct Evaluator)
correlatingPointsPlotterPerGroupExample =
    CartPlotter
    { cartPlotterName = "correlating-points"
    , cartPlotterFunc = plotsRulesForPointsPlotWithEvaluatorsPerExample
    }

plotsRulesForPointsPlotsWithGroupsOfExamples ::
       Path Abs File
    -> Action (Path Abs File)
    -> (GroupName, OrderedDistinct Evaluator)
    -> Rules ()
plotsRulesForPointsPlotsWithGroupsOfExamples plotF genDataF (GroupName groupName, OrderedDistinct (Pair e1 e2)) =
    plotF $%> do
        dataF <- genDataF
        needP [dataF]
        scriptF <- pointsPlotAnalysisScript
        rscript
            scriptF
            [ toFilePath dataF
            , toFilePath plotF
            , evaluatorName e1
            , evaluatorName e2
            , "Per Group: " <> groupName
            , prettyIndication $ evaluatorIndication e1
            , prettyIndication $ evaluatorIndication e2
            ]

correlatingPointsPlotterPerGroupStrategy ::
       EvaluatedCartPlotter ( GroupName
                            , SignatureInferenceStrategy
                            , OrderedDistinct Evaluator)
correlatingPointsPlotterPerGroupStrategy =
    CartPlotter
    { cartPlotterName = "correlating-points"
    , cartPlotterFunc = plotsRulesForPointsPlotsWithGroupsOfExamplesPerStrategy
    }

plotsRulesForPointsPlotsWithGroupsOfExamplesPerStrategy ::
       Path Abs File
    -> Action (Path Abs File)
    -> (GroupName, SignatureInferenceStrategy, OrderedDistinct Evaluator)
    -> Rules ()
plotsRulesForPointsPlotsWithGroupsOfExamplesPerStrategy plotF genDataF (GroupName groupName, s, OrderedDistinct (Pair e1 e2)) =
    plotF $%> do
        dataF <- genDataF
        needP [dataF]
        scriptF <- pointsPlotAnalysisScript
        rscript
            scriptF
            [ toFilePath dataF
            , toFilePath plotF
            , evaluatorName e1
            , evaluatorName e2
            , "Per Group: " <> groupName <> " with strategy: " <>
              ES.sigInfStratName s
            , prettyIndication $ evaluatorIndication e1
            , prettyIndication $ evaluatorIndication e2
            ]

correlatingPointsPlotterAll :: EvaluatedCartPlotter (OrderedDistinct Evaluator)
correlatingPointsPlotterAll =
    CartPlotter
    { cartPlotterName = "correlating-points"
    , cartPlotterFunc = plotsRulesForPointsPlotWithEvaluators
    }

plotsRulesForPointsPlotWithEvaluators ::
       Path Abs File
    -> Action (Path Abs File)
    -> OrderedDistinct Evaluator
    -> Rules ()
plotsRulesForPointsPlotWithEvaluators plotF genDataF (OrderedDistinct (Pair e1 e2)) =
    plotF $%> do
        dataF <- genDataF
        needP [dataF]
        scriptF <- pointsPlotAnalysisScript
        rscript
            scriptF
            [ toFilePath dataF
            , toFilePath plotF
            , evaluatorName e1
            , evaluatorName e2
            , "Global"
            , prettyIndication $ evaluatorIndication e1
            , prettyIndication $ evaluatorIndication e2
            ]

pointsPlotAnalysisScript :: MonadIO m => m (Path Abs File)
pointsPlotAnalysisScript = scriptFile "points.r"
