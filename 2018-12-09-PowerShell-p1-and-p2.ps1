# Input was: 418 players; last marble is worth 71339 points

$board = [System.Collections.Generic.LinkedList[int]]::new()
$currentMarbleNode = $board.AddFirst(0)

#--
$numPlayers = 418
$finalMarbleValue = 7133900
#--

$nextMultipleOf23 = 23
$currentMarbleValue = 1

$playerScores = @{}
$currentPlayer = 1

do {
    if ($currentMarbleValue -eq $nextMultipleOf23)
    {
        $playerScores[$currentPlayer] += $currentMarbleValue

        # Find marble 7 counterclockwise with wraparound, add it to score.
        foreach($count in 0..6)
        {
            $currentMarbleNode = if ($null -eq ($tmp = $currentMarbleNode.Previous)) { $board.Last } else { $tmp }
        }
        $playerScores[$currentPlayer] += $currentMarbleNode.Value


        # store next marble node now, because we won't be able to get it after removing the current one.
        # Remove current one, then use the stored one, with a check for clockwise wraparound.
        $tmp = $currentMarbleNode.Next
        [void]$board.Remove($currentMarbleNode)
        if ($null -ne $tmp) { $currentMarbleNode = $tmp } else { $currentMarbleNode = $board.First }


        $nextMultipleOf23 += 23
    }
    else
    {
        # place marble on board, with clockwise wraparound
        $currentMarbleNode = $currentMarbleNode.Next
        if ($null -eq $currentMarbleNode) { $currentMarbleNode = $board.First }

        $currentMarbleNode = $board.AddAfter($currentMarbleNode, $currentMarbleValue) 
    }


    # pick next available marble, and next player.
    $currentMarbleValue++
    $currentPlayer = ($currentPlayer + 1) % $numPlayers


    # show progress for part 2
    if ($currentMarbleValue % 100kb -eq 0)
    {
        Write-Verbose -Verbose "marble: $currentMarbleValue" 
    }

} until ($currentMarbleValue -gt $finalMarbleValue)


# Display highest score
$playerScores.GetEnumerator() | sort value | select -last 1
