{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE DefaultSignatures #-}

-- |
-- Module      : Database.Record.Persistable
-- Copyright   : 2013-2017 Kei Hibino
-- License     : BSD3
--
-- Maintainer  : ex8k.hibino@gmail.com
-- Stability   : experimental
-- Portability : unknown
--
-- This module defines interfaces
-- between Haskell type and list of SQL type.
module Database.Record.Persistable (
  -- * Specify SQL type
  PersistableSqlType, runPersistableNullValue, unsafePersistableSqlTypeFromNull,

  -- * Specify record width
  PersistableRecordWidth, runPersistableRecordWidth,
  unsafePersistableRecordWidth, unsafeValueWidth, (<&>), maybeWidth,

  -- * Inference rules for proof objects

  PersistableType(..), sqlNullValue,
  PersistableWidth (..), derivedWidth,
  ) where

import GHC.Generics (Generic, Rep, U1 (..), K1 (..), M1 (..), (:*:)(..), to)
import Control.Applicative ((<$>), (<*>), Const (..))
import Data.Monoid (mempty, Sum (..))


-- | Proof object to specify type 'q' is SQL type
newtype PersistableSqlType q = PersistableSqlType q

-- | Null value of SQL type 'q'.
runPersistableNullValue :: PersistableSqlType q -> q
runPersistableNullValue (PersistableSqlType q) = q

-- | Unsafely generate 'PersistableSqlType' proof object from specified SQL null value which type is 'q'.
unsafePersistableSqlTypeFromNull :: q                    -- ^ SQL null value of SQL type 'q'
                                 -> PersistableSqlType q -- ^ Result proof object
unsafePersistableSqlTypeFromNull =  PersistableSqlType


-- | Proof object to specify width of Haskell type 'a'
--   when converting to SQL type list.
newtype PersistableRecordWidth a =
  PersistableRecordWidth { unPRW :: Const (Sum Int) a }

-- unsafely map PersistableRecordWidth
wmap :: (a -> b) -> PersistableRecordWidth a -> PersistableRecordWidth b
f `wmap` prw = PersistableRecordWidth $ f <$> unPRW prw

-- unsafely ap PersistableRecordWidth
wap :: PersistableRecordWidth (a -> b) -> PersistableRecordWidth a -> PersistableRecordWidth b
wf `wap` prw = PersistableRecordWidth $ unPRW wf <*> unPRW prw


-- | Get width 'Int' value of record type 'a'.
runPersistableRecordWidth :: PersistableRecordWidth a -> Int
runPersistableRecordWidth = getSum . getConst . unPRW

instance Show (PersistableRecordWidth a) where
  show = ("PRW " ++) . show . runPersistableRecordWidth

-- | Unsafely generate 'PersistableRecordWidth' proof object from specified width of Haskell type 'a'.
unsafePersistableRecordWidth :: Int                      -- ^ Specify width of Haskell type 'a'
                             -> PersistableRecordWidth a -- ^ Result proof object
unsafePersistableRecordWidth =  PersistableRecordWidth . Const . Sum

-- | Unsafely generate 'PersistableRecordWidth' proof object for Haskell type 'a' which is single column type.
unsafeValueWidth :: PersistableRecordWidth a
unsafeValueWidth =  unsafePersistableRecordWidth 1

-- | Derivation rule of 'PersistableRecordWidth' for tuple (,) type.
(<&>) :: PersistableRecordWidth a -> PersistableRecordWidth b -> PersistableRecordWidth (a, b)
a <&> b = (,) `wmap` a `wap` b

-- | Derivation rule of 'PersistableRecordWidth' from from Haskell type 'a' into for Haskell type 'Maybe' 'a'.
maybeWidth :: PersistableRecordWidth a -> PersistableRecordWidth (Maybe a)
maybeWidth = wmap Just


-- | Interface of inference rule for 'PersistableSqlType' proof object
class Eq q => PersistableType q where
  persistableType :: PersistableSqlType q

-- | Inferred Null value of SQL type.
sqlNullValue :: PersistableType q => q
sqlNullValue =  runPersistableNullValue persistableType


-- | Interface of inference rule for 'PersistableRecordWidth' proof object
class PersistableWidth a where
  persistableWidth :: PersistableRecordWidth a

  default persistableWidth :: (Generic a, GPersistableWidth (Rep a)) => PersistableRecordWidth a
  persistableWidth = to `wmap` gPersistableWidth


class GPersistableWidth f where
  gPersistableWidth :: PersistableRecordWidth (f a)

instance GPersistableWidth U1 where
  gPersistableWidth = PersistableRecordWidth $ Const mempty

instance (GPersistableWidth a, GPersistableWidth b) => GPersistableWidth (a :*: b) where
  gPersistableWidth = (:*:) `wmap` gPersistableWidth `wap` gPersistableWidth

instance (GPersistableWidth a) => GPersistableWidth (M1 i c a) where
  gPersistableWidth = M1 `wmap` gPersistableWidth

instance PersistableWidth a => GPersistableWidth (K1 i a) where
  gPersistableWidth = K1 `wmap` persistableWidth


-- | Inference rule of 'PersistableRecordWidth' proof object for tuple ('a', 'b') type.
instance (PersistableWidth a, PersistableWidth b) => PersistableWidth (a, b)  -- default generic instance

-- | Inference rule of 'PersistableRecordWidth' proof object for 'Maybe' type.
instance PersistableWidth a => PersistableWidth (Maybe a) where
  persistableWidth = maybeWidth persistableWidth

-- | Inference rule of 'PersistableRecordWidth' for Haskell unit () type. Derive from axiom.
instance PersistableWidth ()  -- default generic instance

-- | Pass type parameter and inferred width value.
derivedWidth :: PersistableWidth a => (PersistableRecordWidth a, Int)
derivedWidth =  (pw, runPersistableRecordWidth pw) where
  pw = persistableWidth
