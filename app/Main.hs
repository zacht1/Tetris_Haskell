module Main where

import Graphics.Gloss
import Graphics.Gloss.Interface.Pure.Game
import System.Random
import Data.List (transpose)

-- Board grid is 20x10, each cell has a size of 40
-- Constants
width, height, cellSize :: Int
width = 10
height = 20
cellSize = 40

data GameState = GameState
  { 
    grid :: [[Bool]],       -- Tettris game grid represented by 2d array of Bools, True if square is occupied, False otherwise
    currPiece :: Piece,
    seed :: StdGen,
    tick :: Float,          -- Time measurement for falling piece
    gameOver :: Bool        -- True if the game has ended
  }

data Piece = Piece 
  { 
    shape :: [[Bool]],
    positionX :: Int,
    positionY :: Int,
    pieceDir :: Direction
  }

data Direction = MoveWest | MoveEast | MoveSouth | None   -- Possible movement directions

-- Possible shapes
shapeI, shapeJ, shapeL, shapeO, shapeS, shapeT, shapeZ :: [[Bool]]
shapeI = [[True], [True], [True], [True]]
shapeJ = [[False, True], [False, True], [True, True]]
shapeL = [[True, False], [True, False], [True, True]]
shapeO = [[True, True], [True, True]]
shapeS = [[True, False], [True, True], [False, True]]
shapeT = [[False, True], [True, True], [False, True]]
shapeZ = [[False, True], [True, True], [True, False]]

allShapes :: [[[Bool]]]
allShapes = [shapeI, shapeJ, shapeL, shapeO, shapeS, shapeT, shapeZ]

-- generates a random tetromino in starting position x=4 and y=15
randomPiece :: StdGen -> (Piece, StdGen)
randomPiece s = (Piece { shape = newShape, positionX = 4, positionY = 15, pieceDir = None }, gen)
   where newShape = allShapes !! rand
         (rand, gen) = randomR (0,6) s

-- return initial state of game, given a seed for random tetromino generation
initialState :: StdGen -> GameState
initialState s = GameState 
   { 
    grid = replicate height (replicate width False), 
    currPiece = piece,
    seed = gen,
    tick = 0,
    gameOver = False
   }
   where (piece, gen) = randomPiece s

-- render a single cell
renderCell :: (Int, Int) -> Color -> Picture
renderCell (x, y) c = translate (fromIntegral (x * cellSize - 180)) (fromIntegral (y * cellSize - 380))
                      $ color c
                      $ rectangleSolid (fromIntegral cellSize) (fromIntegral cellSize)

render :: GameState -> Picture
render state = 
   if (gameOver state) 
   then pictures $
      [translate (-100) 0 $ scale 0.3 0.3 $ color black $ text "Game Over"] ++ 
      [translate (-65) (-25) $ scale 0.1 0.1 $ color black $ text "Press ' R ' to Restart"]
   else pictures $
      [renderCell (x, y) red | (y, row) <- zip [0..] (grid state), (x, occupado) <- zip [0..] row, occupado] ++
      [renderCell (x + (positionX (currPiece state)), y + (positionY (currPiece state))) blue | 
      (y, row) <- zip [0..] (shape (currPiece state)), (x, occupado) <- zip [0..] row, occupado]

main :: IO ()
main = do
   s <- getStdGen
   play
      (InWindow "Tetris" (400, 800) (0, 0))
      white
      60
      (initialState s)
      render
      handleInput
      update

handleInput :: Event -> GameState -> GameState
handleInput (EventKey (SpecialKey KeyDown) Down _ _) state  = movePiece MoveSouth state -- state { currPiece = (currPiece state) { pieceDir = MoveSouth } }
handleInput (EventKey (SpecialKey KeyDown) Up _ _) state    = movePiece None state -- state { currPiece = (currPiece state) { pieceDir = None } }
handleInput (EventKey (SpecialKey KeyLeft) Down _ _) state  = movePiece MoveWest state -- state { currPiece = (currPiece state) { pieceDir = MoveWest } }
handleInput (EventKey (SpecialKey KeyLeft) Up _ _) state    = movePiece None state -- state { currPiece = (currPiece state) { pieceDir = None } }
handleInput (EventKey (SpecialKey KeyRight) Down _ _) state = movePiece MoveEast state -- state { currPiece = (currPiece state) { pieceDir = MoveEast } }
handleInput (EventKey (SpecialKey KeyRight) Up _ _) state   = movePiece None state -- state { currPiece = (currPiece state) { pieceDir = None } }
handleInput (EventKey (SpecialKey KeyUp) Down _ _) state    = rotatePiece state
handleInput (EventKey (SpecialKey KeySpace) Down _ _) state = dropPiece state
handleInput (EventKey (Char 'r') Down _ _) state            = if (gameOver state) then initialState (seed state) else state
handleInput _ state                                         = state

-- rotate current piece of game
rotatePiece :: GameState -> GameState
rotatePiece state =
    let oldPiece = currPiece state
        newShape = transpose . reverse $ shape oldPiece
        newPiece = oldPiece { shape = newShape }
    in if isValidRotation newPiece (grid state)
       then state { currPiece = newPiece }
       else state

-- check if the rotated piece is within bounds and not overlapping with other pieces
isValidRotation :: Piece -> [[Bool]] -> Bool
isValidRotation piece grid =
    all (\x -> withinBounds x && unoccupied x grid) 
        (map (\(x, y) -> (x + positionX piece, y + positionY piece)) (getOccupiedCells (shape piece)))

-- Helper function to get the occupied cells of a shape given the Piece.Shape property 
getOccupiedCells :: [[Bool]] -> [(Int, Int)]
getOccupiedCells shape =
    [(x, y) | (row, y) <- zip shape [0..], (True, x) <- zip row [0..]]


-- TODO: drop piece does not currently account for pieces already placed
-- drops piece to bottom of board (or furthest it can drop before landing on another piece)
dropPiece :: GameState -> GameState
dropPiece state =
   if validMove MoveSouth (currPiece state) state
   then dropPiece (movePiece MoveSouth state)
   else generateNewPiece state { tick = 0 }

-- dropPiece state = generateNewPiece state { currPiece = (currPiece state) { positionY = 0 } }
   -- where lastY = findIndex (\_ -> validMove MoveSouth piece state)
   --       numCells = [py, py-1..0] -- (positionY piece)
   --       py = (positionY piece) - 1
   --       piece = (currPiece state)

--  takes two integer arguments representing the x and y coordinates to be checked and returns a boolean value
withinBounds :: (Int, Int) -> Bool
withinBounds (x, y) = x < width && x >= 0 && y >= 0

-- determines if (x, y) is an unoccupied cell
unoccupied :: (Int, Int) -> [[Bool]] -> Bool
unoccupied (x, y) g = not $ (g !! y) !! x

-- determines if given move is a valid move
validMove :: Direction -> Piece -> GameState -> Bool
validMove dir piece state = all (\pt -> withinBounds pt && unoccupied pt (grid state)) pieceCells
   where pieceCells = [(x + pieceX, y + pieceY) | (y, row) <- zip [0..] (shape piece),
                               (x, occupado) <- zip [0..] row,
                               occupado]
         (pieceX, pieceY) = newPosition dir state

newPosition :: Direction -> GameState -> (Int, Int)
-- calculates new position of piece after move in given direction
newPosition dir state = 
   let x = positionX (currPiece state)
       y = positionY (currPiece state)
   in case dir of
      MoveEast  -> (x + 1, y)
      MoveWest  -> (x - 1, y)
      MoveSouth -> (x, y - 1)
      None      -> (x, y)

{- updated to pass the current state to validMove & only update the positionX and positionY of the current 
piece in currPiece if the move is valid according to the updated validMove function.-}
-- moves piece in given direction in given game
movePiece :: Direction -> GameState -> GameState
movePiece dir state =
  let (newX, newY) = newPosition dir state
  in if validMove dir (currPiece state) state -- (grid state) newX newY
     then state { currPiece = (currPiece state) { positionX = newX, positionY = newY } }
     else state

-- get cells occupied by current piece
occupiedCells :: Piece -> [(Int, Int)]
occupiedCells piece = [(x + (positionX piece), y + (positionY piece)) | 
                       (y, row) <- zip [0..] (shape piece), 
                       (x, occupado) <- zip [0..] row, occupado]

-- set values in grid where currPiece is to True
-- choose next piece to appear and set currPiece to that
generateNewPiece :: GameState -> GameState
generateNewPiece state = state { grid = newGrid, currPiece = newPiece, seed = newSeed, gameOver = isOver}
   where
      isOver = any (\x -> x) (newGrid !! 15)
      newGrid = foldl (\b (x, y) -> changeCell x y True b) (grid state) (occupiedCells (currPiece state))
      (newPiece, newSeed) = randomPiece (seed state)

-- change cell at (x,y) to occupy in given grid
changeCell :: Int -> Int -> Bool -> [[Bool]] -> [[Bool]]
changeCell x y occupy grid =
   take y grid ++ [take x (grid !! y) ++ [occupy] ++ drop (x + 1) (grid !! y)] ++ drop (y + 1) grid

clearFullRows :: GameState -> GameState
clearFullRows state = state { grid = newGrid }
  where
    filteredGrid = filter (not . all id) (grid state)
    newGrid = filteredGrid ++ replicate (height - length filteredGrid) (replicate width False)


{- updated to pass the current state (including currPiece and grid) to the validMove function when checking for a valid south move. -}
update :: Float -> GameState -> GameState
update dt state =
   if validMove MoveSouth (currPiece state) state
   then if (tick state) >= 1.0
        then clearFullRows $ movePiece MoveSouth state { tick = 0 }
        else state { tick = (tick state) + dt }
   else if (tick state) >= 1.0 then generateNewPiece state { tick = 0 } else state { tick = (tick state) + dt }
