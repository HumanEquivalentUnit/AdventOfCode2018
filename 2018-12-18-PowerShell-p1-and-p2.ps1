# Part 1 - prints an answer
$goalMinutes = 10
# Part 2 - prints when cycles happen, scan/calculate rest by hand
# $goalMinutes = 1000000000


$lines = Get-Content -Path .\data.txt
$size = $lines[0].Length

$board = [char[,]]::new(($size+2), ($size+2))
foreach ($y in 0..($lines.count - 1))
{
    $line = $lines[$y]
    foreach ($x in 0..($line.Length - 1))
    {
        $char = $line[$x]

        $board[($x+1), ($y+1)] = $char
    }
}

# Keep track for part 2
$seenBoards = [System.Collections.Generic.HashSet[psobject]]::new()

$origBoard = -join $board.clone()
[void]$seenBoards.Add($origBoard)
$lastMinute = 0

foreach ($minute in 1..$goalMinutes)
{  
    $newBoard = $board.Clone()

    foreach ($y in 1..$size)
    {
        foreach ($x in 1..$size)
        {
            $curChar = $board[$x, $y]

            [array]$adj = $board[($x-1), ($y-1)], $board[$x, ($y-1)], $board[($x+1), ($y-1)], 
                          $board[($x-1), ($y  )],                     $board[($x+1), ($y  )], 
                          $board[($x-1), ($y+1)], $board[$x, ($y+1)], $board[($x+1), ($y+1)]

            $adj = $adj -ne 0

            #if ($adj.count -ne 8) { write-verbose -verbose $adj.count }

            if ($curChar -eq '.') #open
            {
                if (($adj -eq '|').Count -ge 3)
                {
                    $newBoard[$x, $y] = '|'
                }
            }
            elseif ($curChar -eq '|') #tree
            {
                if (($adj -eq '#').Count -ge 3)
                {
                    $newBoard[$x, $y] = '#' #lumber
                }
            }
            elseif ($curChar -eq '#') #lumber
            {
                if ((($adj -eq '#').Count -ge 1) -and (($adj -eq '|').Count -ge 1))
                {
                    $newBoard[$x, $y] = '#' #lumber
                }
                else
                {
                    $newBoard[$x, $y] = '.' #open
                }
            }
        }
    }

    # Part 2 tracking
    $board = $newBoard
    $vNow = -join $board
    if ($seenBoards.Contains($vNow))
    {
        $x = (([char[]]$vnow) -eq '#' | measure).Count * (([char[]]$vnow) -eq '|' | measure).Count
        
        Write-Verbose -Verbose "cycle: $x after $minute minutes"
    }
    [void]$seenBoards.Add($vNow)
    
}

# Part 1 output
Write-Host "Part 1: Resources: $(($board -eq '#' | measure).Count * ($board -eq '|' | measure).Count)"

