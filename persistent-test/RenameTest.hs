{-# OPTIONS_GHC -fno-warn-unused-binds #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

{-# LANGUAGE GADTs #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE EmptyDataDecls #-}
module RenameTest (specs) where

import Test.Hspec.Monadic
import Test.Hspec.HUnit ()
import Test.HUnit
import Database.Persist.Sqlite
import Database.Persist.TH
import Database.Persist.EntityDef
import Database.Persist.GenericSql.Raw
#ifndef WITH_MONGODB
import qualified Data.Conduit as C
import qualified Data.Conduit.List as CL
#endif
#if WITH_POSTGRESQL
import Database.Persist.Postgresql
#endif
import qualified Data.Map as Map
import qualified Data.Text as T

import Init

-- Test lower case names
#if WITH_MONGODB
mkPersist persistSettings [persistLowerCase|
#else
share [mkPersist sqlSettings, mkMigrate "lowerCaseMigrate"] [persistLowerCase|
#endif
LowerCaseTable id=my_id
    fullName String
    ExtraBlock
        foo bar
        baz
        bin
    ExtraBlock2
        something
RefTable
    someVal Int sql=something_else
    lct LowerCaseTableId
    UniqueRefTable someVal
|]

specs :: Specs
specs = describe "rename specs" $ do
#ifndef WITH_MONGODB
    it "handles lower casing" $ asIO $ do
        runConn $ do
            _ <- runMigrationSilent lowerCaseMigrate
            C.runResourceT $ withStmt "SELECT full_name from lower_case_table WHERE my_id=5" [] C.$$ CL.sinkNull
            C.runResourceT $ withStmt "SELECT something_else from ref_table WHERE id=4" [] C.$$ CL.sinkNull
#endif
    it "extra blocks" $ do
        entityExtra (entityDef (undefined :: LowerCaseTable)) @?=
            Map.fromList
                [ ("ExtraBlock", map T.words ["foo bar", "baz", "bin"])
                , ("ExtraBlock2", map T.words ["something"])
                ]

asIO :: IO a -> IO a
asIO = id
