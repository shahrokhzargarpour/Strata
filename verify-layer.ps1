# verify-layer.ps1 — verificador de deriva de la capa (agnostico a version)
#
# Que hace: comprueba que TODAS las anclas declaradas en upstream.lock siguen existiendo
# en el arbol y que el motor compilado conoce TODOS los flags de la capa. Si algo se movio,
# FALLA RUIDOSAMENTE en lugar de dejar un parche aplicado a medias.
#
# Uso:
#   pwsh -File verify-layer.ps1                      # solo anclas (rapido, no necesita binario)
#   pwsh -File verify-layer.ps1 -Exe <ruta strata.exe>   # ademas verifica los flags con --help
#
# Salida: exit 0 = capa sana; exit 1 = deriva detectada (lista de anclas/flags faltantes).

param(
  [string]$Lock = (Join-Path $PSScriptRoot 'upstream.lock'),
  [string]$Exe  = '',
  [string]$Tree = $PSScriptRoot
)

$ErrorActionPreference = 'Stop'
$fallas = @()

if (-not (Test-Path $Lock)) { Write-Host "NO existe upstream.lock: $Lock"; exit 1 }
$lk = Get-Content $Lock -Raw | ConvertFrom-Json

Write-Host "=== verify-layer: base $($lk.base.tag) ($($lk.base.commit.Substring(0,8))) | serie $($lk.base.rama_serie) (trabajo: $($lk.base.rama_de_trabajo)) ==="
Write-Host ""
Write-Host "--- Anclas ($($lk.anclas.Count)) ---"
foreach ($a in $lk.anclas) {
  $p = Join-Path $Tree $a.archivo
  if (-not (Test-Path $p)) { Write-Host ("  [FALLA] {0,-6} no existe el archivo {1}" -f $a.id, $a.archivo); $fallas += "$($a.id): archivo ausente ($($a.archivo))"; continue }
  $hit = Select-String -Path $p -Pattern $a.patron -SimpleMatch -List -ErrorAction SilentlyContinue
  if ($hit) { Write-Host ("  [ok]    {0,-6} {1}  ::  '{2}'" -f $a.id, $a.archivo, $a.patron) }
  else { Write-Host ("  [FALLA] {0,-6} {1} ya no contiene '{2}'  ({3})" -f $a.id, $a.archivo, $a.patron, $a.que_protege); $fallas += "$($a.id): ancla movida ($($a.archivo) :: $($a.patron))" }
}

if ($Exe) {
  Write-Host ""
  Write-Host "--- Flags que el motor debe conocer ($Exe) ---"
  if (-not (Test-Path $Exe)) { Write-Host "  [FALLA] no existe el binario: $Exe"; $fallas += "binario ausente" }
  else {
    $help = & $Exe --help 2>&1 | Out-String
    $todos = @($lk.flags.tier_de_disco) + @($lk.flags.system_prompt)
    foreach ($f in $todos) {
      if ($help -match [regex]::Escape($f)) { Write-Host ("  [ok]    {0}" -f $f) }
      else { Write-Host ("  [FALLA] el motor NO conoce {0}" -f $f); $fallas += "flag ausente: $f" }
    }
    # invariante critica: un flag desconocido debe seguir siendo error fatal
    if ($help -notmatch 'usage') { Write-Host "  [aviso] el --help no muestra 'usage': revisar que el parser siga rechazando flags desconocidos" }
  }
}

Write-Host ""
if ($fallas.Count -eq 0) { Write-Host "=== CAPA SANA: $($lk.anclas.Count) anclas OK$(if($Exe){' y todos los flags presentes'}) ==="; exit 0 }
Write-Host "=== DERIVA DETECTADA — NO aplicar/confiar en la capa hasta resolver: ==="
$fallas | ForEach-Object { Write-Host "  - $_" }
Write-Host ""
Write-Host "Que hacer: ver la seccion 'anclas' de upstream.lock, ubicar el punto equivalente en la version nueva,"
Write-Host "actualizar el ancla (y el parche que la usa) y volver a correr este verificador."
exit 1
