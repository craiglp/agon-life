# Game of Life

Conway's Game of Life for Agon Light
-------------------------------------

 Based on the Amstrad CPC version written by Brian Chiha
 brian.chiha@gmail.com  -- Mar 2021

 Game of Life is a cellular automation simulation.  Each cell evolves based on the number
 of cells that surround it.  The basic cell rules are:

    * Any live cell with two or three live neighbours survives.
    * Any dead cell with three live neighbours becomes a live cell.
    * All other live cells die in the next generation. Similarly, all other dead cells stay dead.


Calcuation for next cells are done from memory starting at _MATRIC_START.  Current Base is 
what is displayed
on the screen, Next Base is used to place the next life cycle.  Once all cells are check
Next Base will be copied to Current Base

To Work out top/bottom cells, I place a zero row one above and below the 1000 cell table.  To
handle left/right cells, I place one zero column on the left.  And for the bottom right cell
I have one extra byte.

If Cell is alive it will be set to 1, if it is dead, it will be zero.

 Memory Map With Upper/Lower/Left/Right buffer.  Total of 1108 Bytes for a 40x25 matrix
 X = potential cell position, 0 = always zero

   000102030405060708090A0B0C0D0E0F101112131415161718191A1B1C1D1E1F202122232425262728
00  0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
01  0 X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X
02  0 X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X
03  0 X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X
04  0 X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X
05  0 X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X
06  0 X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X
07  0 X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X
08  0 X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X
09  0 X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X
0A  0 X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X
0B  0 X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X
0C  0 X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X
0D  0 X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X
0E  0 X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X
0F  0 X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X
10  0 X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X
11  0 X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X
12  0 X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X
13  0 X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X
14  0 X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X
15  0 X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X
16  0 X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X
17  0 X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X
18  0 X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X
19  0 X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X
1A  0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
1B  0  <= needed for last bottom right check

Requires: 
MOS 1.03
VDP 1.03


