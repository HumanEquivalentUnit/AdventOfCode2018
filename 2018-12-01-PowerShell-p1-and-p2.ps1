# Code after optimizing runtime from 3.1s to 0.063s
# Blog post about there is here: https://humanequivalentunit.github.io/AoC-Optimizing-Day-1/

$nums = [int[]][system.io.file]::ReadAllLines('d:\aoc\2018\1\data.txt')

# Part 1
[System.Console]::WriteLine([System.Linq.Enumerable]::Sum($nums))

# Part 2 - keep summing until a repeat is seen.
$lookup = [System.Collections.Generic.HashSet[int]]::new()
$runningTotal = 0
:outerLoop while ($true) { 
    foreach ($n in $nums) { $runningTotal += $n; if (-not $lookup.Add($runningTotal)) { break outerLoop } } 
}
[System.Console]::WriteLine($runningTotal)
