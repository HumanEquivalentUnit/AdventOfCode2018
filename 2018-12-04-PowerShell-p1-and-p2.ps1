$guards = @{}


Get-Content .\data.txt  | sort-object | foreach { 

    [void]($_ -match '\[(.*)\] (.*)')
    $date = get-date $matches[1]
    $message = $matches[2]

    switch -regex ($message)
    {
        
        # For a Guard identifier line, get the ID, set them up with 60 blank minutes.
        'Guard #(\d+)' { 
        
            $script:guard = $matches[1]
            if (-not $guards.ContainsKey($script:guard)){ $guards[$script:guard] = @(0) * 60 }
        }

        # If they fell asleep, store the date for use when they wake.
        'sleep' { $script:sleep = $date }
        
        # If they wake, loop over the minutes from sleep..wake and increment their array
        'wakes' {
            $script:sleep.Minute..($date.Minute-1)|%{
                $guards[$script:guard][$_]++
            }
        }
    }
}

# Part 1, most minutes asleep, which minute is highest
$mostSleepy = $guards.GetEnumerator() | sort-object { $_.Value | measure -sum | % sum } | select -Last 1
$minute = $mostSleepy.Value.IndexOf(($mostSleepy.Value | sort)[-1])
"Part 1: Guard $($mostSleepy.Name), minute $minute"
$minute * $mostSleepy.Name

# Part 2, guard with most same-minute asleep
$mostSame = $guards.GetEnumerator() | sort-object { ($_.Value | sort)[-1] } | select -Last 1
$minute = $mostSame.Value.IndexOf(($mostSame.Value | sort)[-1])
"Part 2: Guard $($mostSame.Name), minute: $minute"
    $minute * $mostSame.Name
