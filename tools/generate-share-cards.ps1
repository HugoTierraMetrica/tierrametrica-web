# Genera las imágenes de vista previa (og:image) para compartir en LinkedIn,
# WhatsApp y demás. 1200x630 es el tamaño que LinkedIn recorta mejor.
#
# Uso:  powershell -ExecutionPolicy Bypass -File tools\generate-share-cards.ps1
#
# Para añadir un artículo nuevo, agrega una entrada a $cards y vuelve a correrlo.

Add-Type -AssemblyName System.Drawing

$root   = Split-Path $PSScriptRoot -Parent
$assets = Join-Path $root "assets"
$outDir = Join-Path $assets "share"
New-Item -ItemType Directory -Force $outDir | Out-Null

$W = 1200; $H = 630
$indigo = [System.Drawing.ColorTranslator]::FromHtml("#464991")
$green  = [System.Drawing.ColorTranslator]::FromHtml("#5E9877")
$cream  = [System.Drawing.ColorTranslator]::FromHtml("#F7F5F0")
$ink    = [System.Drawing.ColorTranslator]::FromHtml("#1A1A1A")
$muted  = [System.Drawing.ColorTranslator]::FromHtml("#5A5A5A")

$cards = @(
  @{ file="home.png";      stat="";       label="";
     title="Conoce el valor real de tu patrimonio inmobiliario";
     kicker="AVALÚOS · FACTIBILIDAD · ASESORÍA" }

  @{ file="plusvalia-zmg.png"; stat="11.3%";
     label="apreciación anual de la vivienda en la ZMG durante 2025";
     title="Las zonas con mayor plusvalía en la ZMG";
     kicker="ANÁLISIS · PLUSVALÍA" }

  @{ file="vallarta-bahia.png"; stat="1.6×";
     label="más vivienda instalada en Puerto Vallarta que en Bahía de Banderas";
     title="Puerto Vallarta o Bahía de Banderas: ¿quién tiene más oferta?";
     kicker="ANÁLISIS · MERCADO COSTERO" }

  @{ file="zapopan-predial.png"; stat="`$2,100M";
     label="recaudados por predial en Zapopan durante 2025";
     title="Zapopan y su recaudación de predial";
     kicker="ANÁLISIS · FISCAL" }
)

# Parte el texto en líneas que quepan en $maxW
function Get-WrappedLines($graphics, $text, $font, $maxW) {
  $lines = @(); $current = ""
  foreach ($word in $text.Split(' ')) {
    $try = if ($current) { "$current $word" } else { $word }
    if ($graphics.MeasureString($try, $font).Width -le $maxW) {
      $current = $try
    } else {
      if ($current) { $lines += $current }
      $current = $word
    }
  }
  if ($current) { $lines += $current }
  return $lines
}

$mark = [System.Drawing.Bitmap]::FromFile((Join-Path $assets "logo-mark.png"))

foreach ($c in $cards) {
  $bmp = New-Object System.Drawing.Bitmap $W, $H
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic

  $g.Clear($cream)

  # Franja índigo a la izquierda
  $g.FillRectangle((New-Object System.Drawing.SolidBrush $indigo), 0, 0, 18, $H)

  # Isotipo + nombre
  $mh = 58; $mw = [int][Math]::Round(187.0/136.0*$mh)
  $g.DrawImage($mark, (New-Object System.Drawing.Rectangle 82, 64, $mw, $mh))

  $fName = New-Object System.Drawing.Font "Segoe UI", 26, ([System.Drawing.FontStyle]::Bold)
  $fSub  = New-Object System.Drawing.Font "Segoe UI", 11, ([System.Drawing.FontStyle]::Regular)
  $g.DrawString("Tierra métrica", $fName, (New-Object System.Drawing.SolidBrush $green), (82+$mw+16), 64)
  $g.DrawString("V A L U A C I Ó N", $fSub, (New-Object System.Drawing.SolidBrush $muted), (82+$mw+20), 103)

  $y = 196

  # Kicker
  $fKick = New-Object System.Drawing.Font "Segoe UI", 13, ([System.Drawing.FontStyle]::Bold)
  $g.DrawString($c.kicker, $fKick, (New-Object System.Drawing.SolidBrush $green), 82, $y)
  $y += 44

  # Cifra destacada
  if ($c.stat) {
    $fStat = New-Object System.Drawing.Font "Georgia", 78, ([System.Drawing.FontStyle]::Bold)
    $g.DrawString($c.stat, $fStat, (New-Object System.Drawing.SolidBrush $indigo), 76, $y)
    $y += 132

    $fLabel = New-Object System.Drawing.Font "Segoe UI", 16, ([System.Drawing.FontStyle]::Regular)
    foreach ($ln in (Get-WrappedLines $g $c.label $fLabel 900)) {
      $g.DrawString($ln, $fLabel, (New-Object System.Drawing.SolidBrush $muted), 82, $y)
      $y += 28
    }
    $y += 22
  }

  # Título
  $fTitle = New-Object System.Drawing.Font "Segoe UI", 30, ([System.Drawing.FontStyle]::Bold)
  foreach ($ln in (Get-WrappedLines $g $c.title $fTitle 1000)) {
    $g.DrawString($ln, $fTitle, (New-Object System.Drawing.SolidBrush $ink), 82, $y)
    $y += 50
  }

  # Regla verde al pie
  $g.FillRectangle((New-Object System.Drawing.SolidBrush $green), 82, ($H-72), 76, 5)
  $fFoot = New-Object System.Drawing.Font "Segoe UI", 13, ([System.Drawing.FontStyle]::Regular)
  $g.DrawString("tierrametrica.com", $fFoot, (New-Object System.Drawing.SolidBrush $muted), 176, ($H-80))

  $g.Dispose()
  $bmp.Save((Join-Path $outDir $c.file), [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
  "generado: assets/share/$($c.file)"
}

$mark.Dispose()
