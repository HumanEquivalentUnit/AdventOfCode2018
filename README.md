# AdventOfCode2018

[AdventOfCode.com](http://www.adventofcode.com) challenges for 2018.
I was trying to race for them,  preferring any code which will do the job.

#### Day 7, leaderboard rank #524 then #389
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

