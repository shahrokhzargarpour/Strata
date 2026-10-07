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
  [string]$Patches = (Join-Path $PSScriptRoot 'patches')
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

Write-Host "--- verificando anclas sobre el arbol nuevo ---"
$verify = Join-Path $PSScriptRoot 'verify-layer.ps1'
if (Test-Path $verify) {
  & pwsh -File $verify -Tree $Dst -Lock (Join-Path $PSScriptRoot 'upstream.lock')
  if ($LASTEXITCODE -ne 0) { Write-Host "=== apply-layer: DERIVA. No uses este arbol hasta arreglar las anclas. ==="; exit 1 }
} else { Write-Host "aviso: no encontre verify-layer.ps1" }

Write-Host "=== apply-layer: OK. Arbol listo en $Dst (compilar y correr la bateria host-only antes de usar) ==="
Write-Host "Recorda: si el tag nuevo cambio el parser de args, actualizar upstream.lock (base.tag/commit) al cerrar."
