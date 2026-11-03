$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$sourcePath = Join-Path $root 'wayday-logo-rmbg.png'
$source = [Drawing.Bitmap]::FromFile($sourcePath)
try {
    # Fit the visible artwork, preserving its alpha, colors and aspect ratio.
    $left = $source.Width; $top = $source.Height; $right = 0; $bottom = 0
    for ($y = 0; $y -lt $source.Height; $y++) {
        for ($x = 0; $x -lt $source.Width; $x++) {
            if ($source.GetPixel($x, $y).A -gt 0) {
                $left = [Math]::Min($left, $x); $top = [Math]::Min($top, $y)
                $right = [Math]::Max($right, $x + 1); $bottom = [Math]::Max($bottom, $y + 1)
            }
        }
    }
    if ($right -le $left -or $bottom -le $top) { throw 'The logo is empty.' }
    $bounds = [Drawing.Rectangle]::new($left, $top, $right - $left, $bottom - $top)

    function Write-Logo([string]$relativePath, [int]$size, [double]$fraction, [bool]$opaque) {
        $path = Join-Path $root $relativePath
        [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($path)) | Out-Null
        $bitmap = [Drawing.Bitmap]::new($size, $size)
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        try {
            $background = if ($opaque) { [Drawing.ColorTranslator]::FromHtml('#FBFBF8') } else { [Drawing.Color]::Transparent }
            $graphics.Clear($background)
            $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $scale = $size * $fraction / [Math]::Max($bounds.Width, $bounds.Height)
            $width = [int][Math]::Round($bounds.Width * $scale)
            $height = [int][Math]::Round($bounds.Height * $scale)
            $target = [Drawing.Rectangle]::new([int](($size - $width) / 2), [int](($size - $height) / 2), $width, $height)
            $graphics.DrawImage($source, $target, $bounds, [Drawing.GraphicsUnit]::Pixel)
            $bitmap.Save($path, [Drawing.Imaging.ImageFormat]::Png)
        } finally { $graphics.Dispose(); $bitmap.Dispose() }
    }

    foreach ($path in @('apps/website/public/assets/wayday-logo.png', 'apps/mobile/assets/branding/wayday-logo.png')) {
        $destination = Join-Path $root $path
        [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination)) | Out-Null
        Copy-Item -LiteralPath $sourcePath -Destination $destination
    }
    Write-Logo 'apps/website/public/favicon.png' 64 0.9 $false
    Write-Logo 'apps/mobile/web/wayday-icon.png' 512 0.76 $true
    foreach ($entry in @{ mdpi = 48; hdpi = 72; xhdpi = 96; xxhdpi = 144; xxxhdpi = 192 }.GetEnumerator()) {
        Write-Logo "apps/mobile/android/app/src/main/res/mipmap-$($entry.Key)/wayday_icon.png" $entry.Value 0.76 $true
    }
    # 54 dp artwork on a 108 dp layer stays within Android's 66 dp safe area.
    Write-Logo 'apps/mobile/android/app/src/main/res/drawable-nodpi/wayday_icon_foreground.png' 432 0.5 $false
} finally { $source.Dispose() }
