# Part 1

$p = (get-content .\data.txt -Raw).Trim()
$pprev = ''
$letters = [string[]][char[]](97..122)
while ($pprev -ne $p)
{
    $pprev = $p
    foreach ($l in $letters)
    {
        $p = $p -creplace ($l.tolower() + $l.toupper()), ''
        $p = $p -creplace ($l.toupper() + $l.tolower()), ''            
    }
}
$p.Length


# Part 2

$p = (get-content .\data.txt -Raw).Trim()
$letters = [string[]][char[]](97..122)

function react-polymer ($p) {
    $pprev = ''

    while ($pprev -ne $p)
    {
        $pprev = $p
        foreach ($l in $letters)
        {
            $p = $p -creplace ($l.tolower() + $l.toupper()), ''
            $p = $p -creplace ($l.toupper() + $l.tolower()), ''
        }
    }
    return $p.Trim().Length
}

$r = foreach ($l in $letters) 
{
    $tmp = react-polymer ($p-replace$l)
    [pscustomobject]@{
        'leng'=[int]$tmp
        'letter'=$l
    }
}

$r | sort -Property leng -desc
