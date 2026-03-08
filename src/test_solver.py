puzzle = [
    [0,0,0,0,0,1],
    [0,5,0,0,0,5],
    [0,2,0,0,0,2],
    [0,3,0,0,0,3],
    [0,4,0,0,0,4],
    [0,0,1,6,0,6]
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
    if not currHeads:
        if cellsFilled == N**2:
            for row in grid: print(row)
            return True
        return False
    color = list(currHeads.keys())[0]
    currMove = currHeads[color]
    target = targetMap[color]
    
    allNextMove = getNextMove(currMove)
    
    for nextMove in allNextMove:
        if not checkBound(nextMove): continue
        
        if grid[nextMove.i][nextMove.j].isTerminal:
            if grid[nextMove.i][nextMove.j].color == color and nextMove.i == target.i and nextMove.j == target.j:
                
                currHeadsCopy = currHeads.copy()
                del currHeadsCopy[color]
                if solver(grid, currHeadsCopy, mapPath, cellsFilled):
                    return True
            continue
        if not allowMove(grid, nextMove): continue
        grid[nextMove.i][nextMove.j].color = color
        currHeadsCopy = currHeads.copy()
        currHeadsCopy[color] = nextMove
        if solver(grid, currHeadsCopy, mapPath, cellsFilled + 1): return True
        grid[nextMove.i][nextMove.j].color = -1

    return False
solver(grid, currHeads, mapPath, 2 * K)
