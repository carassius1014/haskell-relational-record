{-# LANGUAGE DeriveFunctor, DeriveFoldable, DeriveTraversable #-}

-- |
-- Module      : Database.Relational.Query.Internal.Sub
-- Copyright   : 2015-2016 Kei Hibino
-- License     : BSD3
--
-- Maintainer  : ex8k.hibino@gmail.com
-- Stability   : experimental
-- Portability : unknown
--
-- This module defines sub-query structure used in query products.
module Database.Relational.Query.Internal.Sub
       ( SubQuery (..), UntypedProjection, ProjectionUnit (..)
       , SetOp (..), BinOp (..), Qualifier (..), Qualified (..)

         -- * Product tree type
       , NodeAttr (..), ProductTree (..), Node (..)
       , JoinProduct, QueryProductTree
       , ProductTreeBuilder, ProductBuilder

       , Projection, untypeProjection, typedProjection

         -- * Query restriction
       , QueryRestriction
       )  where

import Prelude hiding (and, product)
import Data.DList (DList)
import Data.Foldable (Foldable)
import Data.Traversable (Traversable)

import Database.Relational.Query.Context (Flat, Aggregated)
import Database.Relational.Query.Component
  (ColumnSQL, Config, Duplication (..),
   AggregateElem, OrderingTerms)
import qualified Database.Relational.Query.Table as Table


-- | Set operators
data SetOp = Union | Except | Intersect  deriving Show

-- | Set binary operators
newtype BinOp = BinOp (SetOp, Duplication) deriving Show

-- | Sub-query type
data SubQuery = Table Table.Untyped
              | Flat Config
                UntypedProjection Duplication JoinProduct (QueryRestriction Flat)
                OrderingTerms
              | Aggregated Config
                UntypedProjection Duplication JoinProduct (QueryRestriction Flat)
                [AggregateElem] (QueryRestriction Aggregated) OrderingTerms
              | Bin BinOp SubQuery SubQuery
              deriving Show

-- | Qualifier type.
newtype Qualifier = Qualifier Int  deriving Show

-- | Qualified query.
data Qualified a =
  Qualified Qualifier a
  deriving (Show, Functor, Foldable, Traversable)


-- | node attribute for product.
data NodeAttr = Just' | Maybe deriving Show

type QS = Qualified SubQuery

type QueryRestrictionBuilder = DList (Projection Flat (Maybe Bool))

-- | Product tree type. Product tree is constructed by left node and right node.
data ProductTree rs
  = Leaf QS
  | Join !(Node rs) !(Node rs) !rs
  deriving (Show, Functor)

-- | Product node. node attribute and product tree.
data Node rs = Node !NodeAttr !(ProductTree rs)  deriving (Show, Functor)

-- | Product tree with join restriction.
type QueryProductTree = ProductTree (QueryRestriction Flat)

-- | Product tree with join restriction builder.
type ProductTreeBuilder = ProductTree QueryRestrictionBuilder

-- | Product noe with join restriction builder.
type ProductBuilder = Node QueryRestrictionBuilder

-- | Type for join product of query.
type JoinProduct = Maybe QueryProductTree


-- | Projection structure unit with single column width
data ProjectionUnit
  = RawColumn ColumnSQL            -- ^ used in immediate value or unsafe operations
  | SubQueryRef (Qualified Int)    -- ^ normalized sub-query reference T<n> with Int index
  | Scalar SubQuery                -- ^ scalar sub-query
  deriving Show

-- | Untyped projection. Forgot record type.
type UntypedProjection = [ProjectionUnit]

-- | Phantom typed projection. Projected into Haskell record type 't'.
newtype Projection c t =
  Projection
  { untypeProjection :: UntypedProjection {- ^ Discard projection value type -} }  deriving Show

-- | Unsafely type projection value.
typedProjection :: UntypedProjection -> Projection c t
typedProjection =  Projection


-- | Type for restriction of query.
type QueryRestriction c = [Projection c (Maybe Bool)]
