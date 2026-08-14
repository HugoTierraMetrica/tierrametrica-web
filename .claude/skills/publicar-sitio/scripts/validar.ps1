# Validaciones previas al despliegue del sitio de Tierra Metrica.
# Sin acentos a proposito: PowerShell 5.1 lee los .ps1 como ANSI si el
# archivo no lleva BOM, y ahi los acentos rompen el parseo.
#
# Codigo de salida 0 = todo bien, 1 = hay algo que arreglar.

param([string]$Raiz = (Get-Location).Path)

$ErrorActionPreference = 'Stop'
Set-Location $Raiz

$fallos = @()
$avisos = @()

function Fallo($m) { $script:fallos += $m }
function Aviso($m) { $script:avisos += $m }

$paginas = @(Get-ChildItem -Path $Raiz -Filter *.html) +
           @(Get-ChildItem -Path (Join-Path $Raiz 'blog') -Filter *.html -ErrorAction SilentlyContinue)

Write-Host "Revisando $($paginas.Count) paginas HTML..." -ForegroundColor Cyan

# ── 1. JSON-LD: un bloque mal formado se ignora en silencio ────────────
$rxLd = [regex]'(?s)<script type="application/ld\+json">(.*?)</script>'
$idsDefinidos = @()
$idsUsados = @()

foreach ($p in $paginas) {
  $t = Get-Content $p.FullName -Raw -Encoding UTF8
  foreach ($m in $rxLd.Matches($t)) {
    $crudo = $m.Groups[1].Value
    try {
      $o = $crudo | ConvertFrom-Json
      $nodos = if ($o.'@graph') { $o.'@graph' } else { @($o) }
      foreach ($n in $nodos) { if ($n.'@id') { $idsDefinidos += $n.'@id' } }
      $idsUsados += ([regex]'"@id"\s*:\s*"([^"]+)"').Matches($crudo) |
                    ForEach-Object { $_.Groups[1].Value }
    } catch {
      # El mensaje del parser trae el bloque entero pegado detras, y son
      # cientos de lineas. Nos quedamos con la explicacion.
      $msg = ($_.Exception.Message -split "`n")[0].Trim()
      Fallo "JSON-LD invalido en $($p.Name): $msg"
    }
  }
}

foreach ($id in ($idsUsados | Sort-Object -Unique)) {
  if ($idsDefinidos -notcontains $id) {
    Fallo "JSON-LD: se referencia el @id '$id' pero no lo define ninguna pagina"
  }
}

# ── 2. Enlaces internos y archivos referenciados ───────────────────────
foreach ($p in $paginas) {
  $dir = $p.Directory.FullName
  $t = Get-Content $p.FullName -Raw -Encoding UTF8
  $rx = [regex]'(?:href|src)="(?!https?:|mailto:|tel:|data:|#)([^"#?]+)'
  foreach ($m in $rx.Matches($t)) {
    $rel = $m.Groups[1].Value
    if ($rel -eq '') { continue }
    $destino = Join-Path $dir $rel
    if (-not (Test-Path $destino)) {
      Fallo "Enlace roto en $($p.Name): $rel"
    }
  }
}

# ── 3. Metadatos minimos de las paginas indexables ─────────────────────
foreach ($p in $paginas) {
  $t = Get-Content $p.FullName -Raw -Encoding UTF8
  if ($t -match '<meta name="robots" content="[^"]*noindex') { continue }
  $n = $p.Name
  if ($t -notmatch '<title>(.+?)</title>')            { Fallo "$n no tiene title" }
  elseif ($Matches[1].Length -gt 65)                  { Aviso "$n tiene un title de $($Matches[1].Length) caracteres; Google corta cerca de 60" }
  if ($t -notmatch '<meta name="description"')        { Fallo "$n no tiene meta description" }
  if ($t -notmatch 'rel="canonical"')                 { Fallo "$n no tiene canonical" }
  if ($t -notmatch '<html lang="es-MX">')             { Aviso "$n no declara lang=es-MX" }
  $h1 = ([regex]'<h1').Matches($t).Count
  if ($h1 -ne 1)                                      { Fallo "$n tiene $h1 elementos h1; debe haber exactamente uno" }
}

# ── 4. Sitemap contra canonicas ────────────────────────────────────────
$rutaSitemap = Join-Path $Raiz 'sitemap.xml'
if (-not (Test-Path $rutaSitemap)) {
  Fallo "Falta sitemap.xml"
} else {
  try {
    $x = [xml](Get-Content $rutaSitemap -Raw -Encoding UTF8)
    $enSitemap = @($x.urlset.url.loc)
    $canonicas = @()
    foreach ($p in $paginas) {
      $t = Get-Content $p.FullName -Raw -Encoding UTF8
      if ($t -match '<meta name="robots" content="[^"]*noindex') { continue }
      if ($t -match '<link rel="canonical" href="([^"]+)"') { $canonicas += $Matches[1] }
    }
    foreach ($c in $canonicas) {
      if ($enSitemap -notcontains $c) { Fallo "El sitemap no incluye $c" }
    }
    foreach ($u in $enSitemap) {
      if ($canonicas -notcontains $u) { Aviso "El sitemap lista $u pero ninguna pagina la declara como canonica" }
    }
  } catch {
    Fallo "sitemap.xml no es XML valido: $($_.Exception.Message)"
  }
}

# ── 5. El repositorio es publico ───────────────────────────────────────
# Cualquier documento de cliente que entre aqui queda en el historial de
# GitHub de forma permanente, y borrarlo despues no lo quita del historial.
$sospechosos = Get-ChildItem -Path $Raiz -Recurse -File -Include *.pdf,*.docx,*.xlsx,*.doc,*.xls,*.pptx,*.csv `
               -ErrorAction SilentlyContinue |
               Where-Object { $_.FullName -notmatch '\\\.git\\' }
foreach ($s in $sospechosos) {
  $rel = $s.FullName.Substring($Raiz.Length).TrimStart('\')
  # check-ignore sale con 0 si el archivo esta ignorado, con 1 si no lo esta.
  git check-ignore -q $rel 2>$null
  if ($LASTEXITCODE -ne 0) {
    Fallo "Documento en un repositorio publico: $rel  (revisa si debe estar ahi)"
  }
}

# ── Resultado ──────────────────────────────────────────────────────────
Write-Host ""
if ($avisos.Count -gt 0) {
  Write-Host "AVISOS (no bloquean la publicacion):" -ForegroundColor Yellow
  $avisos | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
  Write-Host ""
}
if ($fallos.Count -gt 0) {
  Write-Host "FALLOS ($($fallos.Count)):" -ForegroundColor Red
  $fallos | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
  Write-Host ""
  Write-Host "No publiques hasta resolverlos." -ForegroundColor Red
  exit 1
}
Write-Host "Todo en orden. Listo para publicar." -ForegroundColor Green
exit 0
