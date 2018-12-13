# Part 1

$lines = get-content data.txt
$val1 = $lines |? {[bool]($_.getenumerator() | group |? count -eq 2)} | measure | % count
$val2 = $lines |? {[bool]($_.getenumerator() | group |? count -eq 3)} | measure | % count
$val1 * $val2

# -> 246*20


# Part 2

$1st, $2nd = $lines | ForEach-Object {
    $cur = $_
    foreach ($L in $lines)
    {
        $numdiffs = 0
        for ($i = 0; $i -lt $l.length; $i++)
        {
          if ($cur[$i] -ne $L[$i]) { $numdiffs++ }
        }
        if ($numdiffs -eq 1) { $L, $cur }
    }
    
} | Sort-Object -Unique

# print only the identical characters from the two results
0..($1st.length - 1) | ForEach-Object { 
    if ($1st[$_] -eq $2nd[$_])
    {
        write-host $1st[$_] -NoNewline
    }
}
