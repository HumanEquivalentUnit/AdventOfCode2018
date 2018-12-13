# NB. This code doesn't run and generate an answer,
# but it was the code I used interactively in ISE -
# break at a cutoff, run some of the commented code to render an image.

add-type -AssemblyName system.drawing

$data = Get-Content .\data.txt | foreach {
    $x,$y,$dx,$dy = [int[]]($_ -split '[^-\d]+' -ne '')

    @{x = $x;  y = $y;  dx= $dx;  dy = $dy}
}

$time=0
do {
    $farleft   = [int32]::MaxValue
    $farRight  = [int32]::MinValue
    $farTop    = [int32]::MaxValue
    $farBottom = [int32]::MinValue

    foreach ($p in $data) {
        $p.x += $p.dx
        $p.y += $p.dy

        if ($p.x -lt $farleft) { $farleft = $p.x }
        if ($p.x -gt $farRight) { $farRight = $p.x }
        if ($p.y -lt $farTop ) { $farTop = $p.y }
        if ($p.y -gt $farBottom ) { $farBottom = $p.y }
    }
    $time++

    # Drawing code, run in ISE with dot sourcing . .\script.ps1 
    # and when it finishes, uncomment some of this and select and F8 it, 
    # adjust to taste as necessary.
    # $xoffset = 0 - $farleft
    # $yoffset = 0 - $farTop
    # $bmp = [System.Drawing.Bitmap]::new(1005,1005)
    # 
    # foreach ($p in $data) {
    #     $bmp.SetPixel($xoffset+$p.x, $yoffset+$p.y, 'blue')
    # }
    # [Windows.Forms.Clipboard]::SetImage($bmp)
    # $bmp.Save("d:\aoc\2018\10\img\$($time.ToString().padleft(5,'0')).png")

} until ((($farRight - $farleft) -lt 64) -and (($farBottom - $farTop) -lt 12))
