$opcodes = @{
    addr = { param($A, $B, $C) $registers[$C] = $registers[$A] + $registers[$B] }
    addi = { param($A, $B, $C) $registers[$C] = $registers[$A] + $B }

    mulr = { param($A, $B, $C) $registers[$C] = $registers[$A] * $registers[$B] }
    muli = { param($A, $B, $C) $registers[$C] = $registers[$A] * $B }

    banr = { param($A, $B, $C) $registers[$C] = $registers[$A] -band $registers[$B] }
    bani = { param($A, $B, $C) $registers[$C] = $registers[$A] -band $B }

    borr = { param($A, $B, $C) $registers[$C] = $registers[$A] -bor $registers[$B] }
    bori = { param($A, $B, $C) $registers[$C] = $registers[$A] -bor $B }

    setr = { param($A, $B, $C) $registers[$C] = $registers[$A] }
    seti = { param($A, $B, $C) $registers[$C] = $A }

    gtir = { param($A, $B, $C) $registers[$C] = if ($A -gt $registers[$B]) { 1 } else { 0 } }
    gtri = { param($A, $B, $C) $registers[$C] = if ($registers[$A] -gt $B) { 1 } else { 0 } }
    gtrr = { param($A, $B, $C) $registers[$C] = if ($registers[$A] -gt $registers[$B]) { 1 } else { 0 } }

    eqir = { param($A, $B, $C) $registers[$C] = if ($A -eq $registers[$B]) { 1 } else { 0 } }
    eqri = { param($A, $B, $C) $registers[$C] = if ($registers[$A] -eq $B) { 1 } else { 0 } }
    eqrr = { param($A, $B, $C) $registers[$C] = if ($registers[$A] -eq $registers[$B]) { 1 } else { 0 } }   
}

$blocks = (Get-Content -Path .\data.txt -raw) -split "`r?`n`r?`n"

$possibles = @{}


# Pick out the blocks for part 1
$results = foreach ($block in $blocks -match 'before')
{


    # Split into three lines, get the digits out for the instruction
    $before, $instruction, $after = $block -split "`r?`n"
    
    $instruction = [int[]]@($instruction -split "\D+" -ne '')
    $afterTxt = $after.Substring(9, 10)
    

    
    # Setup for part 2, track which op-codes this could possibly be
    if (-not $possibles.ContainsKey($instruction[0]))
    {
        $possibles[$instruction[0]] = [system.collections.generic.HashSet[string]]::new()
    }



    # Evalute each instruction, count and store the ones which it could be
    $matchingOpCount = 0
    foreach ($op in $opcodes.Keys)
    {
        $registers = [int[]]@($before -split "\D+" -ne '')

        & $opcodes[$op] $instruction[1] $instruction[2] $instruction[3]

        if (([string]::Join(', ', $registers)) -eq $afterTxt)
        {
            [void]$possibles[$instruction[0]].Add($op)
            $matchingOpCount++
        }
    }
    $matchingOpCount
}

Write-Host "Part 1: Number of inputs which could be 3 or more opcodes: $(($results -ge 3).Count)"



# Winnow down the availble op-code for each value
$opLookup = @{}

while ($possibles.Count -gt 0)
{
    $known = ($possibles.getenumerator().where{$_.Value.Count -eq 1})[0]
    $opCode = $known.Value.GetEnumerator().foreach{$_}[0]
    $opLookup[$known.Name] = $opCode
    $possibles.Remove($known.Name)
    $possibles.values.foreach{ [void]$_.Remove($opCode) }
}



# Part 2 - execute the script
$registers = @(0,0,0,0)
foreach ($block in $blocks -notmatch 'before' -split "`r?`n" -ne '')
{
    $parts = [int[]]@($block -split "\D+" -ne '')
    
    & $opcodes[$opLookup[$parts[0]]] $parts[1] $parts[2] $parts[3]
}

Write-Host "Part 2: Result in register 0: $($registers[0])"
