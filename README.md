# Game of Life

Conway's Game of Life for the Agon Light

https://en.wikipedia.org/wiki/Conway%27s_Game_of_Life

---


Based on the Amstrad CPC version written by Brian Chiha -- Mar 2021<br>
https://github.com/bchiha/Ready-Z80/blob/main/03-Game_of_life/game_of_life.z80

Also, got inspiration from:<br>
Conway's game of life by Joe Helmick (c)2019<br>
https://gitlab.com/joe_helmick/life-rom

Uses a CMWC (Complimentary-Multiply-With-Carry) random number generator based on:
https://worldofspectrum.org/forums/discussion/39632/cmwc-random-number-generator-for-z80

 Game of Life is a cellular automation simulation.  Each cell evolves based on the number
 of cells that surround it, it's neighborhood.  
 
 The Conway Game of Life cell rules are:

    * Any live cell with two or three live neighbours survives.
    * Any dead cell with three live neighbours becomes a live cell.
    * All other live cells die in the next generation. Similarly, all other dead cells stay dead.

These rules can be written in a form, S/B. Where S is the counts of surrounding neighbors necessary 
for a cell to survive, and B is the counts of alive neighbors necessary for a cell to be born. Using
this notation Conway's Life rule is 23/3

There are a number of other rulesets that define other members of the "Life" family of cellular
automata. 

Calcuation for next cells are done from memory starting at _MATRIX_START.  Current Base is 
what is displayed
on the screen, Next Base is used to place the next life cycle.  Once all cells are check
Next Base will be copied to Current Base

To Work out top/bottom cells, I place a zero row one above and below the 1000 cell table.  To
handle left/right cells, I place one zero column on the left.  And for the bottom right cell
I have one extra byte.

If Cell is alive it will be set to 1, if it is dead, it will be zero.
```
 Memory Map With Upper/Lower/Left/Right buffer.
 X = potential cell position, 0 = always zero

    0 0 0 0 0 0 0 0 0 0  
    0 1 2 3 4 5 6 7 8 9  
    
00  0 0 0 0 0 0 0 0 0 0  
01  0 X X X X X X X X X  
02  0 X X X X X X X X X  
03  0 X X X X X X X X X  
04  0 X X X X X X X X X  
05  0 X X X X X X X X X  
06  0 X X X X X X X X X  
07  0 X X X X X X X X X  
08  0 X X X X X X X X X  
09  0 X X X X X X X X X  
0A  0 <= needed for last bottom right check
```

Requires: <br>
MOS 1.03 <br>
VDP 1.03

(Tested successfully with MOS 1.04RC2, and VDP 1.04RC2)

Each generation is evaluated until you press Escape to exit.

# <<< Road Map >>>

* ~~Custom icon/image for 'live' cells~~
* ~~Make matrix 'infinite', full wrap-around in all directions~~ (Not doing)
* ~~Plot matrix properly, rather than clear screen, print row by row~~
* ~~Generation counter~~
* ~~Full run, with keyboard scan. Run until stopped, rather than one generation per keystroke~~
* ~~Need a more 'random' random number generator~~
* User config of matrix start state
* Allow user to select Cellular Automata Ruleset to run other variations of Life
* http://www.mirekw.com/ca/rullex_life.html



# License

Copyright 2023 Craig L. Patterson

Permission is hereby granted, free of charge, to any person obtaining a copy of this software
and associated documentation files (the “Software”), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial
portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT 
LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN 
NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, 
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE 
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.





