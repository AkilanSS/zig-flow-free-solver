puzzle = [
    [0,0,0,0,0,0,0,1],
    [0,0,0,3,5,0,0,2],
    [0,0,0,0,0,6,0,0],
    [0,0,6,0,0,0,0,0],
    [0,3,5,0,4,0,0,0],
    [0,4,0,0,0,0,0,1],
    [0,2,0,0,0,0,0,0],
    [0,0,0,0,0,0,0,0],
]


class Cell:
    def __init__(self):
        self.isTerminal = False
        self.color = -1
        self.hasPipe = False
        self.id = -1
    
    def __str__(self) -> str:
        return str(self.color) if self.color > 0 else "."
    
    def __repr__(self) -> str:
        return str(self.color) if self.color > 0 else "."

class CellIndex:
    def __init__(self, i, j) -> None:
        self.i = i
        self.j = j

    def __repr__(self) -> str:
        return str(f"({self.i}, {self.j})")

grid : list[list[Cell]]= []
N = len(puzzle)
K = 0

for i in range(N):
    row = []
    for j in range(N):
        newCell = Cell()
        if puzzle[i][j] > 0:
            K = max(K, puzzle[i][j])
            newCell.color = puzzle[i][j]
            newCell.isTerminal = True
            row.append(newCell)
        else:
            row.append(newCell)
    grid.append(row)

def getPosition(grid):
    positionMap = {}
    for i in range(N):
        for j in range(N):
            if grid[i][j].color == -1: continue
            if grid[i][j].color in positionMap:
                positionMap[grid[i][j].color].append(CellIndex(i, j))
            else:
                positionMap[grid[i][j].color] = [CellIndex(i, j)]
    return positionMap

def getNextMove(curr_cell : CellIndex):
    x = curr_cell.i
    y = curr_cell.j
    return [
        CellIndex(x + 1, y),
        CellIndex(x - 1, y),
        CellIndex(x, y + 1),
        CellIndex(x, y - 1)
    ]

def checkBound(move) -> bool:
    if 0 <= move.i < N and 0 <= move.j < N: return True
    return False

def allowMove(grid, move) -> bool:
    if grid[move.i][move.j].color != -1: return False
    return True

#Here goes the actual solver
positionMap = getPosition(grid)
targetMap = {k: positionMap[k][1] for k in range(1, K + 1)}
currHeads = {k: positionMap[k][0] for k in range(1, K + 1)}
mapPath = {k: [] for k in range(1, K + 1)}

def solver(grid, currHeads, mapPath, cellsFilled):
    #if hasDeadEnd(grid, currHeads):
    #   return False
    if not currHeads:
        if cellsFilled == N**2:
            for row in grid: print(row)
            print(mapPath)
            return True
        return False
    color = list(currHeads.keys())[0]
    print(color)
    currMove = currHeads[color]
    target = targetMap[color]
    
    allNextMove = getNextMove(currMove)
    
    for nextMove in allNextMove:
        if not checkBound(nextMove): continue
        
        if grid[nextMove.i][nextMove.j].isTerminal:
            if grid[nextMove.i][nextMove.j].color == color and nextMove.i == target.i and nextMove.j == target.j:
                currHeadsCopy = currHeads.copy()
                newPath = mapPath[color] + [nextMove]
                mapPathCopy = mapPath.copy()
                mapPathCopy[color] = newPath
                del currHeadsCopy[color]
                if solver(grid, currHeadsCopy, mapPathCopy, cellsFilled):
                    return True
            continue
        if not allowMove(grid, nextMove): continue
        grid[nextMove.i][nextMove.j].color = color
        currHeadsCopy = currHeads.copy()
        newPath = mapPath[color] + [nextMove]
        mapPathCopy = mapPath.copy()
        mapPathCopy[color] = newPath
        currHeadsCopy[color] = nextMove
        # print(cellsFilled)
        # [print(row) for row in grid]
        # print()
        if solver(grid, currHeadsCopy, mapPathCopy, cellsFilled + 1): return True
        grid[nextMove.i][nextMove.j].color = -1

    return False
solver(grid, currHeads, mapPath, 2 * K)

def solver(grid, currHeads, mapPath, cellsFilled):
    # Base Case: All colors have reached their targets
    if not currHeads:
        # Check if the entire grid is filled (common requirement for Flow puzzles)
        if cellsFilled == N**2:
            return mapPath
        return None

    color = list(currHeads.keys())[0]
    currMove = currHeads[color]
    target = targetMap[color]
    
    allNextMove = getNextMove(currMove)
    
    for nextMove in allNextMove:
        if not checkBound(nextMove): 
            continue
        
        # Scenario A: The next move is a terminal (endpoint)
        if grid[nextMove.i][nextMove.j].isTerminal:
            if grid[nextMove.i][nextMove.j].color == color and nextMove.i == target.i and nextMove.j == target.j:
                currHeadsCopy = currHeads.copy()
                newPath = mapPath[color] + [nextMove]
                mapPathCopy = mapPath.copy()
                mapPathCopy[color] = newPath
                
                # Remove this color as it's finished and move to the next color
                del currHeadsCopy[color]
                
                result = solver(grid, currHeadsCopy, mapPathCopy, cellsFilled)
                if result is not None:
                    return result
            continue
        
        # Scenario B: The next move is an empty cell
        if not allowMove(grid, nextMove): 
            continue
            
        # Backtracking step: Mark the grid
        grid[nextMove.i][nextMove.j].color = color
        
        newPath = mapPath[color] + [nextMove]
        mapPathCopy = mapPath.copy()
        mapPathCopy[color] = newPath
        
        currHeadsCopy = currHeads.copy()
        currHeadsCopy[color] = nextMove
        
        result = solver(grid, currHeadsCopy, mapPathCopy, cellsFilled + 1)
        if result is not None:
            return result
            
        # Backtrack: Reset the grid cell
        grid[nextMove.i][nextMove.j].color = -1

    return None