{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE ExistentialQuantification #-}

module EasySpec.Evaluate.Evaluate where

import Import

import System.TimeIt
import Text.Printf

import Data.Csv

import qualified Data.ByteString.Lazy.Char8 as LB8

import Language.Haskell.Exts.Pretty (prettyPrint)

import qualified EasySpec.Discover as ES
import qualified EasySpec.Discover.CodeUtils as ES
import qualified EasySpec.Discover.Types as ES
import qualified EasySpec.OptParse as ES

import EasySpec.Evaluate.Types

runEvaluate :: [Path Abs File] -> IO ()
runEvaluate fs = do
    epointss <- mapM getEvaluationInputPointsFor fs
    LB8.putStrLn $
        encodeDefaultOrderedByName $
        concatMap evaluationInputPointCsvLines $ concat epointss

namesInSource :: MonadIO m => Path Abs File -> m [ES.EasyName]
namesInSource f =
    map ES.idName <$> runReaderT (ES.getEasyIds f) evaluationSettings

getEvaluationInputPointsFor :: Path Abs File -> IO [EvaluationInputPoint]
getEvaluationInputPointsFor f = do
    names <- namesInSource f
    fmap concat $ forM names $ getEvaluationInputPointsForName f

signatureInferenceStrategies :: [ES.SignatureInferenceStrategy]
signatureInferenceStrategies = ES.inferenceStrategies

getEvaluationInputPointsForName ::
       Path Abs File -> ES.EasyName -> IO [EvaluationInputPoint]
getEvaluationInputPointsForName f funcname =
    forM signatureInferenceStrategies $ getEvaluationInputPoint f funcname

evaluationSettings :: ES.Settings
evaluationSettings = ES.Settings {ES.setsDebugLevel = 0}

getEvaluationInputPoint ::
       Path Abs File
    -> ES.EasyName
    -> ES.SignatureInferenceStrategy
    -> IO EvaluationInputPoint
getEvaluationInputPoint f funcname strat = do
    let ds =
            ES.DiscoverSettings
            { ES.setDiscFile = f
            , ES.setDiscFun = Just funcname
            , ES.setDiscInfStrat = strat
            }
    (runtime, eqs) <-
        timeItT $ runReaderT (ES.discoverEquations ds) evaluationSettings
    pure
        EvaluationInputPoint
        { eipFile = f
        , eipFunc = funcname
        , eipStrat = strat
        , eipDiscoveredEqs = eqs
        , eipRuntime = runtime
        }

data AnyEvaluator =
    forall a. AnyEvaluator (Evaluator a)

evaluators :: [AnyEvaluator]
evaluators =
    [ AnyEvaluator lengthEvaluator
    , AnyEvaluator runtimeEvaluator
    , AnyEvaluator relevantEquationsEvaluator
    , AnyEvaluator irrelevantEquationsEvaluator
    , AnyEvaluator relativeRelevantEquationsEvaluator
    ]

showEvaluationReport :: [[EvaluationInputPoint]] -> String
showEvaluationReport pointss = showTable $ concatMap go $ concat pointss
  where
    go :: EvaluationInputPoint -> [[String]]
    go eip = map line evaluators
      where
        ip = pointToInput eip
        line (AnyEvaluator ev) =
            [ toFilePath $ eipFile eip
            , ES.sigInfStratName $ eipStrat eip
            , prettyPrint $ eipFunc eip
            , evaluatorName ev
            , evaluate ip ev
            ]

evaluationInputPointCsvLines :: EvaluationInputPoint -> [EvaluatorCsvLine]
evaluationInputPointCsvLines eip = map line evaluators
  where
    ip = pointToInput eip
    line (AnyEvaluator ev) =
        EvaluatorCsvLine
        { eclPath = toFilePath $ eipFile eip
        , eclStratName = ES.sigInfStratName $ eipStrat eip
        , eclFocusFuncName = prettyPrint $ eipFunc eip
        , eclEvaluatorName = evaluatorName ev
        , eclEvaluatorOutput = evaluate ip ev
        }

showTable :: [[String]] -> String
showTable = unlines . map unwords . formatTable

formatTable :: [[String]] -> [[String]]
formatTable sss =
    transpose $
    flip map (transpose sss) $ \ss ->
        let padL = maximum $ map length ss
        in map (pad ' ' $ padL + 1) ss

pad :: Char -> Int -> String -> String
pad c i s
    | length s < i = s ++ replicate (i - length s) c
    | otherwise = s

evaluate :: EvaluationInput -> Evaluator a -> String
evaluate ei e = evaluatorPretty e $ evaluatorGather e ei

pointToInput :: EvaluationInputPoint -> EvaluationInput
pointToInput EvaluationInputPoint {..} =
    EvaluationInput
    { eiDiscoveredEqs = eipDiscoveredEqs
    , eiRuntime = eipRuntime
    , eiFocusFuncName = eipFunc
    }

lengthEvaluator :: Evaluator Int
lengthEvaluator = Evaluator "length" (length . eiDiscoveredEqs) show

runtimeEvaluator :: Evaluator Double
runtimeEvaluator = Evaluator "runtime" eiRuntime (printf "%.3f")

relativeRelevantEquationsEvaluator :: Evaluator Double
relativeRelevantEquationsEvaluator =
    Evaluator "relative-relevant-equations" go (printf "%.2f")
  where
    go ei =
        genericLength
            (filter (mentionsEq $ eiFocusFuncName ei) (eiDiscoveredEqs ei)) /
        genericLength (eiDiscoveredEqs ei)

relevantEquationsEvaluator :: Evaluator Int
relevantEquationsEvaluator = Evaluator "relevant-equations" go show
  where
    go ei =
        length $ filter (mentionsEq $ eiFocusFuncName ei) (eiDiscoveredEqs ei)

irrelevantEquationsEvaluator :: Evaluator Int
irrelevantEquationsEvaluator = Evaluator "irrelevant-equations" go show
  where
    go ei =
        length $
        filter (not . mentionsEq (eiFocusFuncName ei)) (eiDiscoveredEqs ei)

mentionsEq :: ES.EasyName -> ES.EasyEq -> Bool
mentionsEq n (ES.EasyEq e1 e2) = ES.mentions n e1 || ES.mentions n e2