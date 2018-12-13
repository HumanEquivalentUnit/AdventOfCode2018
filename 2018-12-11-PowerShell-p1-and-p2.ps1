$serialNumber = 1718

$squareSizes = 3    # Part 1
# $squareSizes = 2..300  # Part 2


# Setup a 300x300 reference array, 1-indexed,
# calculate power values for each cell,
# and clone it for storing the sums later on.
$startingGrid = [int[,]]::new(301,301)
    
foreach ($y in 1..300)
{
    foreach ($x in 1..300)
    {
        $rackId = ($x + 10)
        $powerLevel = (($rackId * $y) + $serialNumber) * $rackId
        $startingGrid[$x,$y] = [math]::Truncate(($powerLevel%1000/100))-5
    }
}

$sumGrid = $startingGrid.Clone()

# Setup the trackers for the largest value seen so far,
# loop over squares 2x2, 3x3, 4x4, 5x5 and roll them up into the sumGrid.
# approach is to take original value as
#
# 4
#
# then for a 2x2 square add just the new border cells:
#
#   3
# 1 4
#
# then for a 3x3 square, add
#
#     1
#     2
# 7 6 8
#
# etc. Save revisiting same squares over and over.

$storedSum  = -1
$storedX    = -1
$storedY    = -1
$storedSize = -1
foreach ($squareSize in $squareSizes)
{
    Write-verbose -verbose "starting squareSize: $squareSize"
    foreach ($startY in 1..(300 - $squareSize + 1))
    {
        foreach ($startX in 1..(300 - $squareSize + 1))
        {
            # get the the new border for this square size
            $borderX = $startX + $squareSize - 1
            $borderY = $startY + $squareSize - 1

            $numsx = foreach ($x in $startx..$borderX)     { $startingGrid[$x, $borderY] }
            $numsy = foreach ($y in $starty..($borderY-1)) { $startingGrid[$borderX, $y] }
            
            # sum them, check against the stored sizes
            $extraSum = [system.linq.enumerable]::Sum([int[]]$numsx) + [system.linq.enumerable]::Sum([int[]]$numsy)
            $sumGrid[$startX, $startY] += $extraSum

            $localSum = $sumGrid[$startX, $startY]
            if ($localSum -gt $storedSum)
            {
                Write-Verbose -Verbose "NEW: x: $startX y: $startY sum: $localSum squaresize: $squareSize"
                $storedSum = $localSum
                $storedX = $startX
                $storedY = $startY
                $storedSize = $squareSize
            }
        }
    }
}
