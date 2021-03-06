{-# LANGUAGE TemplateHaskell #-}

module EasySpec.Evaluate.Analyse.Hackage.TH where

import Import

import Path.IO

import Development.Shake

import Language.Haskell.TH as TH
import Language.Haskell.TH.Syntax as TH

import qualified Distribution.ModuleName as Cabal
import Distribution.PackageDescription as Cabal
import Distribution.PackageDescription.Configuration as Cabal
import Distribution.PackageDescription.Parse as Cabal
import Distribution.Verbosity as Cabal

import EasySpec.Evaluate.Analyse.Common

type PackageName = String

-- Will be of type (String, [String], [String]) -- PackageName, [SourceDir], [ModulePath]
makePackageTup :: PackageName -> [[String]] -> Q Exp
makePackageTup pkg chosenModules = do
    res <-
        runIO $ do
            pd <- liftIO $ packageTmpDir pkg
            tarfile <- liftIO $ resolveFile pd $ pkg ++ ".tar.gz"
            exists <- Path.IO.doesFileExist tarfile
            unless exists $ do
                ensureDir pd
                cmd
                    (Cwd $ toFilePath $ parent tarfile)
                    "wget"
                    ("http://hackage.haskell.org/package/" ++ pkg ++ ".tar.gz")
                    "--output-document"
                    (toFilePath tarfile) :: IO ()
            cmd
                (Cwd $ toFilePath $ parent tarfile)
                "tar"
                "xvzf"
                (toFilePath tarfile) :: IO ()
            fs <- snd <$> listDirRecur (parent tarfile)
            (srcDirs, moduleNames) <-
                case find ((== ".cabal") . fileExtension) fs of
                    Nothing ->
                        fail $
                        unwords
                            [ "No cabal file found in"
                            , toFilePath $ parent tarfile
                            ]
                    Just cabalFile -> do
                        gpd <-
                            readPackageDescription
                                verbose
                                (toFilePath cabalFile)
                        pure $
                            case library $ flattenPackageDescription gpd of
                                Nothing -> ([], [])
                                Just lib ->
                                    ( hsSourceDirs $ libBuildInfo lib
                                    , filter
                                          ((`elem` chosenModules) .
                                           Cabal.components) $
                                      trace
                                          (unlines $
                                           map (show . Cabal.components) $
                                           exposedModules lib) $
                                      exposedModules lib)
            pure
                ((pkg, srcDirs, map Cabal.toFilePath moduleNames) :: ( String
                                                                     , [String]
                                                                     , [String]))
    TH.lift res

hackageDir :: MonadIO m => m (Path Abs Dir)
hackageDir = (</> $(mkRelDir ".hackage")) <$> tmpDir

packageTmpDir :: MonadIO m => PackageName -> m (Path Abs Dir)
packageTmpDir pkg = do
    td <- hackageDir
    liftIO $ resolveDir td pkg

packageDir :: MonadIO m => PackageName -> m (Path Abs Dir)
packageDir pkg = do
    td <- packageTmpDir pkg
    liftIO $ resolveDir td pkg
