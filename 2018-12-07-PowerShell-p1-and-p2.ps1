$workers = @{}
    
# EDIT HERE
# EDIT HERE
# I didn't keep the part 1 script, so this is edited to do both, but you have to run it twice.
# for Part 1
0..0|%{$workers[$_]='free'}  
    
# for Part 2
#0..4|%{$workers[$_]='free'}

$clockTime = 0
    
$lines = get-content .\data.txt
$allWorkItems = @{}
    
####
# Setup the work items
####
$lines | ForEach-Object {

    [void]($_ -match 'Step (.) must be finished before step (.) can begin')
    $matches[1,2]
        
} | sort -Unique | ForEach-Object {

    $tmpWorkItem = [pscustomobject]@{
        name              = $_
        isStarted         = $false
        isDone            = $false
        willbedoneat      = -1
        precededBy        = [system.collections.generic.list[object]]::new()
        workItemDuration  = 60 + $_[0]-64
    }

    $allWorkItems[$_] = $tmpWorkItem
}

####
# Setup the precedence rules
####

$lines | ForEach-Object {

    $null = $_ -match 'Step (.) must be finished before step (.) can begin'
    $first, $second = $matches[1,2]

    $allWorkItems[$second].precededBy.Add($allWorkItems[$first])

} 


####
# Start the processing
####
$canDo = [system.collections.generic.list[object]]::new()
while ($allWorkItems.values.where{-not $_.isDone}.Count -gt 0)
{

    # identify any work which is finished, and free up the worker
    $busyWorkers = $workers.keys.where{$workers[$_] -ne 'free'}
    $busyWorkers.foreach{
        $workItem = $workers[$_]
        if ($clockTime -gt $workItem.willbedoneat)
        {
            # item is done
            $workitem.isDone = $true
            $workers[$_] = 'free'
        }
    }


    # identify any items which can be worked on (all preceding items are done)
    $canDoTmp = [system.collections.generic.list[object]]::new()
    foreach ($item in $($allWorkItems.values))
    {
        if ($item.precededBy.where{$_.isDone -eq $false}.count -gt 0)
        {
            # preceded by something not yet finished, so can't do this one.
        } else
        {
            # can do this one - but only if it's not done. Don't repeat finished work.
            if (-not $item.isStarted -and -not $item.isDone)
            {
                $canDoTmp.Add($item)
            }
        }
    }

        
    # Assign work to workers,
    # only if there are free workers and work waiting
    [array]$canDoTmp2 = $candotmp | sort -property name
    $workers.Keys.where{$workers[$_] -eq 'free'}.foreach{
        
        if ($canDoTmp2.count -gt 0)
        {
            $workItem = $canDoTmp2[0]
            $workItem.isStarted = $true
            $workItem.willbedoneat = $clockTime + $workitem.workItemDuration - 1
            $canDoTmp2 = $canDoTmp2[1..($canDoTmp2.Count)]
            $workers[$_] = $workItem
            $cando.Add($workitem.name)
        }
    }

    Write-Verbose -Verbose "clocktime: $clocktime, tasks being worked on: $($workers.Values.Name -join ', ')"
    $clockTime++
}

# tidy-ish output.
if ($workers.Count -eq 1){
    "part1: $($canDo -join '')"
}
elseif ($workers.Count -eq 5)
{
    "part2: $($clocktime-1)"
}
else
{
    "Run it with 0..0 workers or 0..4 workers (for my input, anyway)"
}
