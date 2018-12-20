# Demo inputs
#$data = '^ENWWW(NEEE|SSE(EE|N))$'                                           # => 10, 0
#$data = '^ENNWSWW(NEWS|)SSSEEN(WNSE|)EE(SWEN|)NNN$'                         # => 18, 0
#$data = '^ESSWWN(E|NNENN(EESS(WNSE|)SSS|WWWSSSSE(SW|NNNE)))$'               # => 23, 0
#$data = '^WSSEESWWWNW(S|NENNEEEENN(ESSSSW(NWSW|SSEN)|WSWWN(E|WWS(E|SS))))$' # => 31, 0

$data = Get-Content -Path data.txt -Raw
$data = [string[]][char[]]$data.trim("`r`n^$")

# A nested lookup of [$y][$x] for speed
$visitedRooms = [System.Collections.Generic.Dictionary[int, System.Collections.Generic.Dictionary[int,psobject]]]::new()
$choicePoints = [System.Collections.Generic.Stack[System.Tuple[int,int]]]::new()

# Starting positions
$x, $y = 0,0
$stepCounter = 0

# Process all input characters from the regex
for ($i = 0; $i -lt $data.Count; $i++)
{
    $c = $data[$i]

    # If it's a movement one, process movement
    if ($c -in 'N', 'E', 'S', 'W')
    {
        # Move in a direction, and count the step
        if     ($c -eq 'N') { $y-- }
        elseif ($c -eq 'E') { $x++ }
        elseif ($c -eq 'S') { $y++ }
        elseif ($c -eq 'W') { $x-- }
        $stepCounter++

        # If we end up in a room we've seen already,
        # then add how we got there into that room's door list,
        # otherwise it's a new room so store the details.
        # NB. the door list ends up inverted - 
        # entering by moving E adds E to that room's doors when the door is really on side W.
        if (-not $visitedRooms.ContainsKey($y))
        {
            $visitedRooms[$y] = [System.Collections.Generic.Dictionary[int,psobject]]::new()
        }
        if ($visitedRooms[$y].ContainsKey($x))
        {
            $visitedRooms[$y][$x].doors += $c
        }
        else
        {
            $visitedRooms[$y].Add($x, @{ y=$y; x=$x; steps = $stepCounter; doors = @($c)})
        }
    }
    # start of a choicepoint
    elseif ($c -eq '(') {
        $choicePoints.Push([tuple[int,int]]::new($x,$y))
    }
    # choicepoint no longer needed
    elseif ($c -eq ')') {
        [void]$choicePoints.Pop()
    }
    # trigger backtracking to last choicepoint, 
    # but keep it around for (EE|ES|EN) multiple resets.
    elseif ($c -eq '|') {
        $point = $choicePoints.Peek()
        $x, $y = $point.Item1, $point.Item2
        $stepCounter = $visitedRooms[$y][$x].steps
    }
}


# Now each room is visited,
# revisit them closest to farthest,
# check all the neigbours NESW.
# If we got here with 23 steps, 
# but a connected neigbour room is reachable in 4, 
# then here is reachable in 5.
# NB. we're checking the inverse doors.
foreach ($room in $visitedRooms.Values.Values | Sort-Object -Property Steps)
{
    # Check room to the E
    if ($visitedRooms[$room.y].ContainsKey($room.x+1))
    {
        $nextDoor = $visitedRooms[$room.y][$room.x+1]
        if ($nextDoor.steps -lt ($room.steps-1) -and $nextDoor.doors -contains 'E')
        { 
            $room.steps = $nextDoor.steps + 1
        }
    }
    
    # Check room to the W   
    if ($visitedRooms[$room.y].ContainsKey($room.x-1))
    {
        $nextDoor = $visitedRooms[$room.y][$room.x-1]
        if ($nextDoor.steps -lt ($room.steps-1) -and $nextDoor.doors -contains 'W')
        { 
            $room.steps = $nextDoor.steps + 1
        }
    }
 
    # Check room to the N
    if ($visitedRooms.ContainsKey($room.y-1) -and $visitedRooms[$room.y-1].ContainsKey($room.x))
    {
        $nextDoor = $visitedRooms[$room.y-1][$room.x]
        if ($nextDoor.steps -lt ($room.steps-1) -and $nextDoor.doors -contains 'N')
        { 
            $room.steps = $nextDoor.steps + 1
        }
    }
    
    # Check room to the S
    if ($visitedRooms.ContainsKey($room.y+1) -and $visitedRooms[$room.y+1].ContainsKey($room.x))
    {
        $nextDoor = $visitedRooms[$room.y+1][$room.x]
        if ($nextDoor.steps -lt ($room.steps-1) -and $nextDoor.doors -contains 'S')
        { 
            $room.steps = $nextDoor.steps + 1
        }
    }
}

# Sort the farthest room for part 1,
# and number of rooms with 1000+ stepcount for part 2.
$part1 = $visitedRooms.values.values.steps | Sort-Object | select-object -last 1
Write-Host "Part 1: $part1"

$part2 = $visitedRooms.values.values.where{$_.steps -ge 1000}.count
Write-Host "Part 2: $part2"

# 3739
# 8409
