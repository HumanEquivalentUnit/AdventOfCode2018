# AdventOfCode2018

[AdventOfCode.com](http://www.adventofcode.com) challenges for 2018.
I was trying to race for them,  preferring any code which will do the job.

(They assume `data.txt` in the current working directory as the input).

### Day 16, leaderboard rank part 1: #62, part 2: 50
Identify op-codes for a small computer instruction set, 
and execute a program.
Surprisingly few problems with this.
Solved the "now match the op codes" part in Notepad.
Had more bugs and more trouble coding that and mrging p1 and p2 neatly, after answering.

[Day 16 code](https://github.com/HumanEquivalentUnit/AdventOfCode2018/blob/master/2018-12-16-PowerShell-p1-and-p2.ps1)

### Day 12 - 15 todo

### Day 11
300x300 grid of power cells, find the 3x3 sub-grid where the cells sum to the highest value.
(At this point, no longer competing; I can't code these fast enough to be competitive).
Part 1, a naive nested loops, which was fast enough. 
Predicting some exponential slowdown in part 2 but no idea what to expect.
It asks for checking all sub-grid sizes 1x1 through 300x300
(some cells have negative values so it's not automatically the largest size).
Naive search ran for 10+ hours while I was at work, 
until I came up with a way to roll-up changes from previous runs into a second grid.
Now runs in ~22 minutes. 
`[system.linq.enumerable]::Sum([int[]]$numsx)` approx. as fast as a `foreach(){+=}` summing loop.

[Day 11 Code](https://github.com/HumanEquivalentUnit/AdventOfCode2018/blob/master/2018-12-11-PowerShell-p1-and-p2.ps1)

### Day 10
Moving points in the sky, which converging to show some text.
I saw the trigger of "when the bounding box shrinks to below a threshhold", 
but didn't go far enough to identify when it was smallest. 
Spent too much time rendering to image files, instead of console output.
Part 1 Rank #217, Part 2 rank #385

[Day 10 Code](https://github.com/HumanEquivalentUnit/AdventOfCode2018/blob/master/2018-12-10-PowerShell-p1-and-p2.ps1)

### Day 9, leaderboard rank part 1: #432, part 2: unranked
Elf-marble game, they place marbles on a circular buffer.
I saw it was a linked-list style problem, 
but used arrays to do part 1 to get a quicker answer; rank #432,
but had to rewrite with linked lists - and they have quite a bit of overhead code by comparison.

[Day 9 code](https://github.com/HumanEquivalentUnit/AdventOfCode2018/blob/master/2018-12-09-PowerShell-p1-and-p2.ps1)

### Day 8, no rank.
Parse a binary tree out of a flat list.
Seemed easy; tried to deal with the offsets by hand, got lost in the details.

In a hurry I scrapped it and pushed the input onto a stack,
wrote a tidy recursive function, ~~but PS can't do tail-recursion optimisation.
StackOverflow~~ but I later found my mistake had put it into an infinite loop.
I think it can't to tail recursion, but can recurse plenty for this problem.
Still, had lost any chance of a scoreboard rank.

Rewrote it with a state machine and a switch, 
and then played to speed it up; ~1 second runtime tweaked down to ~220ms.
[Day 8 Code](https://github.com/HumanEquivalentUnit/AdventOfCode2018/blob/master/2018-12-08-PowerShell-p1-and-p2.ps1)

Click for a [1 min 40 second video of my undo/redo buffer from the start to the end of all of this](https://streamable.com/8lnzs).

Click for a [blog post about the details of speeding it up](https://humanequivalentunit.github.io/Speed-Tweaks-AoC-Day-8/)

### Day 7, leaderboard rank part 1: #524 part 2: #389
The task was scheduling work items, graph related. Not too bad.
I picked hashtables, and each job has a list of tasks which precede it.
Quite a lot of duplication, but all references to hashtables, and only ~100 items.

Part 1: The task wasn't so bad, but my implementation scheduled
the same job over and over. "*Everything before it is done, so do it now*". 
Then I missed the "pick the first alphabetically" condition, and tripped the delays.
Still not right .. I had the precedence rules backwards! Oops.

Part 2, my biggest trip was scheduling the same work item to multiple workers.
"If it's not done, do it now" - except, it is started. 
Next biggest trip was type errors with PowerShell Lists and Arrays,
and double-using the variable $workers by mistake.

Not thrilled with the design of counting clock seconds 1 by 1.
Could easily be more efficient by jumping time until the next workitem is done.
[Day 7 Code](https://github.com/HumanEquivalentUnit/AdventOfCode2018/blob/master/2018-12-07-PowerShell-p1-and-p2.ps1)

### Day 6 - missed at the time. Still todo.

### Day 5, leaderboard part 1: #509, part 2: #499
The polymer-reacter to reduce a large input string.

A regex replace loop, but tripped over leaving the newlines on the end of the input.

Part 2 a loop over the 26 different options when removing each alphabet letter.
I didn't spot that you can use the ~10k characters result of part 1,
instead of the ~50k characters original input here to speed things up.
(It ran in ~18 seconds, so I didn't need to push for it to run faster).

[Day 5 code](https://github.com/HumanEquivalentUnit/AdventOfCode2018/blob/master/2018-12-05-PowerShell-p1-and-p2.ps1)


### Day 4, leaderboard part 1: #37, part 2: #61
Watching the times guards sleep and wake, to find the best time to try getting past.

Missed a big trick on sorting the input quickly,
instead regexing out the date and converting to `[datetime]` 
but it worked out OK because I used that later anyway.

Hurrying at the time, I did some by-eye / interactive work to get the answers, 
code now added to do that bit.

[Day 4 code](https://github.com/HumanEquivalentUnit/AdventOfCode2018/blob/master/2018-12-04-PowerShell-p1-and-p2.ps1)

### Day 3, leaderboard part 1: #133, part 2: unranked.
Elves claiming squares of fabric to make Santa's suit, 
but their claims may overlap. How many squares are claimed multiple times,
and which Elf's claim overlaps no others.

Regex to load the data, loops over it.
Slowed by trying to use PowerShell arrays and avoid automatic enumeration
down the pipeline, then a change of tack to a proper `[int[,]]` 2D array.

Part 2 was a rewrite with hashtables tracking lists of claims for each cell.

[Day 3 code](https://github.com/HumanEquivalentUnit/AdventOfCode2018/blob/master/2018-12-03-PowerShell-p1-and-p2.ps1)

### Day 2, leaderboard part 1: #78, part 2: #133
Box identifiers numbers, how many have the any letter twice, then three times.
Then identify the two that differ by a single letter.
Didn't directly go to Edit distance, just loops and grouping

[Day 2 code](https://github.com/HumanEquivalentUnit/AdventOfCode2018/blob/master/2018-12-02-PowerShell-p1-and-p2.ps1)

### Day 1, leaderboard rank part 1: #57 part 2: #180
Add the numbers, easy. 
Then find when the numbers will repeat if you keep adding them.
I used a loop. It's not the most efficient, but it is fast to implement.
[Day 1 code](https://github.com/HumanEquivalentUnit/AdventOfCode2018/blob/master/2018-12-01-PowerShell-p1-and-p2.ps1)
