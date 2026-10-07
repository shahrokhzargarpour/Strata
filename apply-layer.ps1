# apply-layer.ps1 — aplica la capa sobre un arbol upstream limpio (agnostico a version)
#
# Para que sirve: actualizar Strata desde el repo oficial SIN perder la capa. Se baja el tag
# nuevo, se le aplican los parches de la capa y se verifica. Si un ancla se movio, verify-layer
# lo dice ANTES de que algo quede a medias.
#
# Requisitos: los parches exportados en patches\ (generarlos con:
#   git -C <arbol> format-patch v0.1.40.1..layer/series -o patches )
#
# Uso:
#   pwsh -File apply-layer.ps1 -Upstream https://github.com/Niko1221/Strata -Tag v0.1.41 -Dst D:\AI\repos\asistentes\_tmp\strata-0.1.41
#
# Que hace, en orden: clona el tag -> aplica patches\*.patch con git am (o --3way si hace falta)
# -> corre verify-layer.ps1 sobre el arbol resultante. Si verify falla, NO se sigue.

param(
  [string]$Upstream = 'https://github.com/Niko1221/Strata',
  [Parameter(Mandatory=$true)][string]$Tag,
  [Parameter(Mandatory=$true)][string]$Dst,
  [string]$Patches = (Join-Path $PSScriptRoot 'patches'),
  # Contra que se comprueba la paridad: la rama de la serie (default) o un punto CONGELADO
  # (p.ej. -Serie bea20c9 para la entrega del delta 2, que NO debe medirse contra la rama que siguio creciendo).
  [string]$Serie = 'layer/series',
  # Lock con el que se verifica el arbol resultante.  Para una entrega CONGELADA hay que pasar el lock de
  # esa entrega (el de su carpeta de tooling): el lock del arbol de trabajo ya tiene anclas posteriores.
  [string]$Lock = (Join-Path $PSScriptRoot 'upstream.lock'),
  [switch]$SkipParity
)

$ErrorActionPreference = 'Stop'
Write-Host "=== apply-layer: $Tag -> $Dst ==="

if (Test-Path $Dst) { Write-Host "El destino ya existe: $Dst  (borralo o elegi otro)"; exit 1 }
$patchFiles = if (Test-Path $Patches) { Get-ChildItem $Patches -Filter '*.patch' | Sort-Object Name } else { @() }
if (-not $patchFiles -or $patchFiles.Count -eq 0) {
  Write-Host "No hay parches en $Patches"
  Write-Host "Genera los con:  git -C <arbol-de-la-capa> format-patch $($Tag)..layer/series -o patches"
  exit 1
}
Write-Host "parches a aplicar: $($patchFiles.Count)"

Write-Host "--- clonando upstream en el tag ---"
git clone --depth 1 --branch $Tag $Upstream $Dst
if ($LASTEXITCODE -ne 0) { Write-Host "FALLO el clon"; exit 1 }
git -C $Dst config user.email 'layer@studioz.local'
git -C $Dst config user.name  'Strata layer'

Write-Host "--- aplicando parches ---"
Push-Location $Dst
foreach ($p in $patchFiles) {
  Write-Host "  -> $($p.Name)"
  git am --3way $p.FullName
  if ($LASTEXITCODE -ne 0) {
    Write-Host "  FALLO al aplicar $($p.Name). Resolve a mano: git am --show-current-patch=diff ; git am --continue"
    git am --abort | Out-Null
    Pop-Location
    exit 1
  }
}
Pop-Location

Write-Host "--- paridad de arbol exacta contra '$Serie' ---"
# Que el arbol aplicado sea EXACTAMENTE el punto que se entrega, no solo "las anclas siguen ahi": se comparan
# los HASHES DE ARBOL.  Una diferencia es fallo: significa que patches/ no reproduce ese punto (un commit sin
# exportar, un archivo de mas, o un parche que aplico distinto).  Con -Serie se mide contra un commit congelado,
# que es lo correcto para una entrega: la rama de trabajo sigue creciendo despues del congelado.
$serieOk = $false
$treeRef = git -C $PSScriptRoot rev-parse --verify --quiet "$Serie^{tree}"
if ($LASTEXITCODE -ne 0) {
  Write-Host "  [aviso] este repo no tiene la referencia '$Serie': no puedo comprobar paridad (corre -SkipParity para saltarla)"
} else {
  $treeDst = git -C $Dst rev-parse 'HEAD^{tree}'
  $dirty = git -C $Dst status --porcelain
  $serieOk = ($treeDst -eq $treeRef) -and (-not $dirty)
  if ($serieOk) { Write-Host "  [ok]    el arbol aplicado es IDENTICO a '$Serie' ($treeDst)" }
  else {
    Write-Host "  [FALLA] el arbol aplicado NO coincide con '$Serie':"
    Write-Host "     arbol aplicado : $treeDst"
    Write-Host "     arbol esperado : $treeRef"
    if ($dirty) { $dirty | ForEach-Object { Write-Host "     sin commitear: $_" } }
    git -C $Dst diff --stat $treeRef -- . | ForEach-Object { Write-Host "     $_" }
  }
}
if (-not $serieOk -and -not $SkipParity) {
  Write-Host ""
  Write-Host "=== apply-layer: PARIDAD DE ARBOL FALLIDA. No uses este arbol: regenera patches/ con"
  Write-Host "    git format-patch v<tag>..<la referencia que se entrega> -o patches y volve a correrlo."
  Write-Host "    Si estas midiendo una entrega CONGELADA, pasa -Serie <commit>: la rama de trabajo ya crecio. ==="
  exit 1
}

Write-Host "--- verificando anclas sobre el arbol nuevo ---"
$verify = Join-Path $PSScriptRoot 'verify-layer.ps1'
if (Test-Path $verify) {
  & pwsh -File $verify -Tree $Dst -Lock $Lock
  if ($LASTEXITCODE -ne 0) { Write-Host "=== apply-layer: DERIVA. No uses este arbol hasta arreglar las anclas. ==="; exit 1 }
} else { Write-Host "aviso: no encontre verify-layer.ps1" }

Write-Host "=== apply-layer: OK. Arbol listo en $Dst (compilar y correr la bateria host-only antes de usar) ==="
Write-Host "Recorda: si el tag nuevo cambio el parser de args, actualizar upstream.lock (base.tag/commit) al cerrar."
