{-# LANGUAGE FlexibleContexts #-}

module EasySpec.Discover.Utils where

import Import

import System.FilePath

import Class
import DynFlags hiding (Settings)
import GHC
import GHC.LanguageExtensions
import Name
import Outputable
import TyCoRep
import TyCon
import Type
import Var

import EasySpec.OptParse

setDFlagsNoLinking
    :: GhcMonad m
    => DynFlags -> m ()
setDFlagsNoLinking = void . setSessionDynFlags

loadSuccessfully
    :: GhcMonad m
    => LoadHowMuch -> m ()
loadSuccessfully hm = do
    r <- load hm
    case r of
        Succeeded -> pure ()
        Failed -> fail "Loading failed. No idea why."

prepareFlags :: DynFlags -> DynFlags
prepareFlags dflags = foldl xopt_set dflags [Cpp, ImplicitPrelude, MagicHash]

getTargetModName :: DiscoverSettings -> ModuleName
getTargetModName =
    mkModuleName . dropExtension . toFilePath . filename . setDiscFile

createQuickspecSig
    :: GhcMonad m
    => [GHC.Id] -> m String
createQuickspecSig ids = do
    componentExprs <- mapM idSigComponent ids
    let componentList = intercalate ", " componentExprs
    pure $ "signature { constants = [ " ++ componentList ++ " ] }"

idSigComponent
    :: GhcMonad m
    => GHC.Id -> m String
idSigComponent i = do
    name <- showGHC $ Var.varName i
    typs <- showGHC $ Var.varType i
    let typ = Var.varType i
    let tvs = typeVars typ
    let tyS =
            typeStr
                (zip
                     tvs
                     [ "A"
                     , "B"
                     , "C"
                     , "D"
                     , "E"
                     , error "Not enough type variables in quickspec."
                     ])
                typ
    liftIO $ print (name, tyS, typs)
    pure $
        unwords
            [ "constant"
            , show name
            , "((" ++
              (if "Dict" `isInfixOf` tyS
                   then "typeclass "
                   else "") ++
              name ++ ")"
            , "::"
            , tyS ++ ")"
            ]

typeStr :: [(GHC.Id, String)] -> GHC.Type -> String
typeStr env = go
  where
    go t =
        case t of
            TyVarTy i -> fromMaybe (showName $ Var.varName i) (lookup i env)
            AppTy t1 t2 ->
                let vn1 = go t1
                    vn2 = go t2
                in unwords [vn1, vn2]
            TyConApp tc kots ->
                let cs = map go kots
                    pars c = "(" ++ c ++ ")"
                in case tyConClass_maybe tc of
                       Just cls ->
                           concat
                               [ "Dict ("
                               , unwords $
                                 showName (Class.className cls) : map pars cs
                               , ")"
                               ]
                       Nothing ->
                           case showName (tyConName tc) of
                               "[]" -> "[" ++ unwords cs ++ "]"
                               tcn -> unwords $ tcn : map pars cs
            ForAllTy _ t'
                    -- No idea why this is necessary here...
             ->
                case splitFunTy_maybe t of
                    Nothing -> go t'
                    Just (tf, tt) ->
                        let vn1 = go tf
                            vn2 = go tt
                        in unwords ["(" ++ vn1, "->", vn2 ++ ")"]
            _ -> error "not implemented yet."

typeVars :: GHC.Type -> [GHC.Id]
typeVars t =
    nub $
    case t of
        TyVarTy v -> [v]
        AppTy t1 t2 -> typeVars t1 ++ typeVars t2
        TyConApp _ kots -> concatMap typeVars kots
        ForAllTy _ t' ->
            case splitFunTy_maybe t of
                Nothing -> typeVars t'
                Just (tf, tt) -> typeVars tf ++ typeVars tt
        _ -> error "not implemented yet."

showName :: Name -> String
showName = occNameString . Name.nameOccName

showGHC
    :: (GhcMonad m, Outputable a)
    => a -> m String
showGHC a = do
    dfs <- getProgramDynFlags
    pure $ showPpr dfs a

printO
    :: (GhcMonad m, Outputable a)
    => a -> m ()
printO a = showGHC a >>= (liftIO . putStrLn)
