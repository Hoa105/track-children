$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$mobileRoot = Split-Path $PSScriptRoot -Parent
$source = [System.Drawing.Bitmap]::new((Join-Path $mobileRoot 'assets/images/scenery/icons/logo/track children logo.png'))
$background = [System.Drawing.ColorTranslator]::FromHtml('#78A963')

function Write-LauncherImage($path, $size, $logoFraction, $opaque) {
    $bitmap = [System.Drawing.Bitmap]::new($size, $size)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        if ($opaque) { $graphics.Clear($background) }
        else { $graphics.Clear([System.Drawing.Color]::Transparent) }
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $scale = $size * $logoFraction / [Math]::Max($source.Width, $source.Height)
        $width = [single]($source.Width * $scale)
        $height = [single]($source.Height * $scale)
        $graphics.DrawImage($source, [single](($size - $width) / 2), [single](($size - $height) / 2), $width, $height)
        $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}

try {
    foreach ($density in @(
        @{ Name = 'mdpi'; Size = 48; Foreground = 108 },
        @{ Name = 'hdpi'; Size = 72; Foreground = 162 },
        @{ Name = 'xhdpi'; Size = 96; Foreground = 216 },
        @{ Name = 'xxhdpi'; Size = 144; Foreground = 324 },
        @{ Name = 'xxxhdpi'; Size = 192; Foreground = 432 }
    )) {
        $folder = Join-Path $mobileRoot "android/app/src/main/res/mipmap-$($density.Name)"
        Write-LauncherImage (Join-Path $folder 'ic_launcher_foreground.png') $density.Foreground 0.60 $false
        Write-LauncherImage (Join-Path $folder 'ic_launcher.png') $density.Size 0.80 $true
    }
} finally {
    $source.Dispose()
}
