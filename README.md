# Tron Light Cycles Game - Nexys A7-100T FPGA

## OVERVIEW
This is a two player Tron Light Cycles game implemented in Verilog for the 
Nexys A7-100T FPGA board. Players control light cycles that leave permanent 
trails behind them. The objective is to avoid crashing into any trail.

## GAME FEATURES
- Player 1 (Blue): Controlled by arrow buttons on the board
- Player 2 (Orange): Moves automatically in a straight line (left), will change this HELP PLEASE BRUH
- 640x480 VGA display at 60Hz refresh rate
- Grid-based movement: 64x48 grid with 10x10 pixel cells
- Collision detection: Game ends when either player hits any trail
- Trail persistence: Both players leave permanent colored trails
- Screen wrapping: Players wrap around screen edges
- Reset functionality: Center button clears game and restarts
- 7-segment display: Shows game over status (0 = playing, 1 = game over)

## CONTROLS
BtnU (Up) - Move Player 1 up
BtnD (Down) - Move Player 1 down
BtnL (Left) - Move Player 1 left
BtnR (Right) - Move Player 1 right
BtnC (Center) - Reset game

# TECHNICAL DETAILS

## Grid System
Screen: 640x480 pixels
Grid: 64 columns x 48 rows
Cell size: 10x10 pixels

## Coordinate conversion:
- Pixel (205, 155) maps to Grid cell (20, 15)
- Grid cell (20, 15) maps to Array index 980

## Memory Layout
2D Grid to 1D Array Mapping:
index = row x 64 + column

## Example:
Grid position (20, 15) gives index = 15 x 64 + 20 = 980

## Trail Memory:
- Each player has separate 1-bit trail grid
- Total memory: 2 x 3,072 bits = 6,144 bits

## Timing
- System Clock: 100 MHz
- Pixel Clock: 25 MHz (VGA standard)
- Movement Speed: approximately 6 moves per second, we could make this faster by tweaking clock speed
- Reset Clear Time: 3,072 cycles (approximately 30 microseconds)

## Direction Encoding
00 = RIGHT
01 = LEFT
10 = UP
11 = DOWN

# KEY DESIGN DECISIONS

## Why Separate Trail Grids?
Problem: Synthesis would hang when both players wrote to the same array, took ages to synthesize the project.
Solution: Use two separate 1-bit arrays for parallel writes.

## Why Grid-Based Movement?
- Reduces memory 100x (from 307,200 pixels to 3,072 cells)
- Simplifies collision detection

## Why Counter-Based Reset?
Problem: Clearing 3,072 cells in one cycle causes synthesis hang, same took ages.
Solution: Clear one cell per clock cycle over 3,072 cycles.

## FUTURE ENHANCEMENTS
- Keyboard control for Player 2 (WASD keys)
- Scoring system
- Adjustable speed and difficulty
- Power-ups
