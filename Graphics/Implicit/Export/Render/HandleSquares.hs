-- Implicit CAD. Copyright (C) 2011, Christopher Olah (chris@colah.ca)
-- Copyright (C) 2016, Julia Longtin (julial@turinglace.com)
-- Released under the GNU AGPLV3+, see LICENSE

module Graphics.Implicit.Export.Render.HandleSquares (mergedSquareTris) where

import Prelude(foldMap, (<>), ($), fmap, concat, (.), (==), compare, error)

import Graphics.Implicit.Definitions (TriangleMesh(TriangleMesh), Triangle(Triangle))

import Graphics.Implicit.Export.Render.Definitions (TriSquare(Tris, Sq))

import Data.VectorSpace ((^*), (*^), (^+^))

import GHC.Exts (groupWith)
import Data.List (sortBy)

-- We want small meshes. Essential to this, is getting rid of triangles.
-- We specifically mark quads in tesselation (refer to Graphics.Implicit.
-- Export.Render.Definitions, Graphics.Implicit.Export.Render.TesselateLoops)
-- So that we can try and merge them together.

{- Core idea of mergedSquareTris:

  Many Quads on Plane
   ____________
  |    |    |  |
  |____|____|  |
  |____|____|__|

   | joinXaligned
   v
   ____________
  |         |  |
  |_________|__|
  |_________|__|

   | joinYaligned
   v
   ____________
  |         |  |
  |         |  |
  |_________|__|

   | joinXaligned
   v
   ____________
  |            |
  |            |
  |____________|

   | squareToTri
   v
   ____________
  |\           |
  | ---------- |
  |___________\|

-}

mergedSquareTris :: [TriSquare] -> TriangleMesh
mergedSquareTris sqTris =
    let
        -- We don't need to do any work on triangles. They'll just be part of
        -- the list of triangles we give back. So, the triangles coming from
        -- triangles...
        triTriangles :: [Triangle]
        triTriangles = [tri | Tris tris <- sqTris, tri <- unmesh tris ]
        --concat $ fmap (\(Tris a) -> a) $ filter isTris sqTris
        -- We actually want to work on the quads, so we find those
        squaresFromTris :: [TriSquare]
        squaresFromTris = [ Sq x y z q | Sq x y z q <- sqTris ]

        unmesh (TriangleMesh m) = m

        -- Collect squares that are on the same plane.
        planeAligned = groupWith (\(Sq basis z _ _) -> (basis,z)) squaresFromTris
        -- For each plane:
        -- Select for being the same range on X and then merge them on Y
        -- Then vice versa.
        joined = fmap
            ( concat . (fmap joinXaligned) . groupWith (\(Sq _ _ xS _) -> xS)
            . concat . (fmap joinYaligned) . groupWith (\(Sq _ _ _ yS) -> yS)
            . concat . (fmap joinXaligned) . groupWith (\(Sq _ _ xS _) -> xS))
            planeAligned
        -- Merge them back together, and we have the desired reult!
        finishedSquares = concat joined

    in
        -- merge them to triangles, and combine with the original triangles.
        TriangleMesh $ triTriangles <> foldMap squareToTri finishedSquares

-- And now for the helper functions that do the heavy lifting...

joinXaligned :: [TriSquare] -> [TriSquare]
joinXaligned quads@((Sq b z xS _):_) =
    let
        orderedQuads = sortBy
            (\(Sq _ _ _ (ya,_)) (Sq _ _ _ (yb,_)) -> compare ya yb)
            quads
        mergeAdjacent (pres@(Sq _ _ _ (y1a,y2a)) : next@(Sq _ _ _ (y1b,y2b)) : others) =
            if y2a == y1b
            then mergeAdjacent ((Sq b z xS (y1a,y2b)): others)
            else if y1a == y2b
            then mergeAdjacent ((Sq b z xS (y1b,y2a)): others)
            else pres : mergeAdjacent (next : others)
        mergeAdjacent a = a
    in
        mergeAdjacent orderedQuads
joinXaligned (Tris _:_) = error "Tried to join y aligned triangles."
joinXaligned [] = []

joinYaligned :: [TriSquare] -> [TriSquare]
joinYaligned quads@((Sq b z _ yS):_) =
    let
        orderedQuads = sortBy
            (\(Sq _ _ (xa,_) _) (Sq _ _ (xb,_) _) -> compare xa xb)
            quads
        mergeAdjacent (pres@(Sq _ _ (x1a,x2a) _) : next@(Sq _ _ (x1b,x2b) _) : others) =
            if x2a == x1b
            then mergeAdjacent ((Sq b z (x1a,x2b) yS): others)
            else if x1a == x2b
            then mergeAdjacent ((Sq b z (x1b,x2a) yS): others)
            else pres : mergeAdjacent (next : others)
        mergeAdjacent a = a
    in
        mergeAdjacent orderedQuads
joinYaligned (Tris _:_) = error "Tried to join y aligned triangles."
joinYaligned [] = []

-- Deconstruct a square into two triangles.
squareToTri :: TriSquare -> [Triangle]
squareToTri (Sq (b1,b2,b3) z (x1,x2) (y1,y2)) =
    let
        zV = b3 ^* z
        (x1V, x2V) = (x1 *^ b1, x2 *^ b1)
        (y1V, y2V) = (y1 *^ b2, y2 *^ b2)
        a = zV ^+^ x1V ^+^ y1V
        b = zV ^+^ x2V ^+^ y1V
        c = zV ^+^ x1V ^+^ y2V
        d = zV ^+^ x2V ^+^ y2V
    in
        [Triangle (a,b,c), Triangle (c,b,d)]
squareToTri (Tris t) = unmesh t
  where
    unmesh (TriangleMesh a) = a

