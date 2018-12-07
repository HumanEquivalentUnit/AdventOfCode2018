#
# Part 1 add the numbers
#
get-content .\data.txt |% { [int] $_ } | measure -sum


#
# Part 2, add the numbers repeatedly until any frequency repeats
#
$nums = [int[]](get-content .\data.txt)
$lookup=@{}
$current=0
while ($true) { 
    $nums.foreach{ $current += $_;   if ($lookup.ContainsKey($current)) {break}; $lookup[$current]++; } 
}
$current
