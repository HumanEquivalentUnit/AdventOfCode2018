$nums = [int[]][system.io.file]::ReadAllLines('d:\aoc\2018\1\data.txt')

# Part 1
[System.Linq.Enumerable]::Sum($nums)

# Part 2
$lookup  = [System.Collections.Generic.HashSet[int]]::new()
$runningSum = 0
$running = $true
while ($running)
{
    foreach ($n in $nums)
    {
        $runningSum += $n
        if ($lookup.Contains($runningSum)) {$running = $false; $runningSum; break}
        [void]$lookup.Add($runningSum)
    }
}
