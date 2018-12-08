$lines     = Get-Content .\data.txt -raw
$inputNums = [int[]]($lines.Split(" `r`n"))
$i         = 0
$stack     = [System.Collections.Generic.Stack[PSObject]]::new(20kb)

$numRemainingChildNodes = 1

$metaSum = 0      # quick hack global running sum of metadata values, to avoid walking the result tree.

while ($i -lt $inputNums.Count)
{
    if ($numRemainingChildNodes -eq 0)
    {

        # no more childnodes, Slice out this node's metadata numbers, and jump $i past it.
        $currentNode = $stack.pop()
        $currentNode.metaData = $inputNums[$i..($i+$currentNode.numMetadataEntries-1)]
        $i += $currentNode.numMetadataEntries


        # Part 1, update global sum of metadata (much faster than | measure-object -sum)
        $localSum = 0; foreach ($m in $currentNode.metaData) { $localSum+=$m }
        $metaSum += $localSum
            

        # part 2
        if ($currentNode.numChildNodes -eq 0)
        {
            $currentNode.value = $localSum
        }
        else
        {
            # 1-indexed, so push everything right with a temp insert and do a fast multi-index instead of a loop.
            $currentnode.childNodes.Insert(0, 0)
            foreach ($v in $currentNode.childNodes[$currentNode.metaData].value) { $currentNode.value += $v }
            $currentNode.childNodes.RemoveAt(0)
        }
        # End Part 2


        # empty stack means $current is the finished root node and we're done.
        if ($stack.count -gt 0)
        {
            $parent = $stack.Peek()
            $parent.childNodes.Add($currentNode)
                
            $numRemainingChildNodes = $parent.childNodes.Count - $parent.numChildNodes
        }
    }
    else
    {
        # any number of nodes still at this level, launch the start of a node into the stack.
        $stack.Push(@{
                numChildNodes      = ($numRemainingChildNodes = $inputNums[$i++])
                numMetadataEntries = $inputNums[$i++]
                childNodes         = [System.Collections.Generic.List[psobject]]::new()
                metaData           = $null
                value              = 0
            })
    }
}

"Part 1: $metaSum (45618 for me)"
"Part 2: $($currentNode.Value) (22306 for me)"
