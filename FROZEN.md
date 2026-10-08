# FROZEN — entrega delta 5a de la capa Strata

**Punto de entrega (ISO 10007):** el commit de código `04985f7de519f2c77b93acf4686d936d2a794df3` (árbol
`feef397af39b6f011ea6dd5ad62a3fb496cd9950`), sobre `layer/delta4-d7`
(`59929bef88771dea70b92e72e88edddc5ba16c85`). Fecha: 2026-10-08. **Revisión v1.0.2**: cierra C8 y O2 de la
auditoría neutral, y F1/F2/F3 del addendum de reauditoría (`07-correcciones/2026-10-08-auditoria-neutral-delta5a-addendum-reauditoria-v1.0.1.md`, 12/12 PASS).

**Naturaleza:** delta aditivo, **opt-in**, **apagado por defecto**. Con los flags ausentes el tier de disco es
**byte por byte idéntico** a `layer/delta4-d7`. No se tocó `D:\AI\servers\strata\delta3`; no se reinició ni relanzó
ningún server (`:5011` sirvió durante todo el trabajo); no hubo push a GitHub ni al fork.

## Qué se congela

| Pieza | Valor |
|---|---|
| Rama | `layer/delta5a` |
| Commit de código (la serie) | `04985f7de519f2c77b93acf4686d936d2a794df3` |
| Árbol del commit | `feef397af39b6f011ea6dd5ad62a3fb496cd9950` |
| Base | `layer/delta4-d7` @ `59929bef88771dea70b92e72e88edddc5ba16c85` |
| Serie de parches | `patches/delta5a/0001-disk-tier-archive-not-delete-the-parking-copy-in-the.patch` (sha256 `9a2ac88bcda3b9ca5bef84e3394bfaa38122d6772ac838d1cb26b4d26931664e`) |
| Tooling (NO va en la serie) | `upstream.lock`, `verify-layer.ps1`, `apply-layer.ps1`, `patches/`, `CHANGELOG.md`, `FROZEN.md` |

## Paridad de árbol (verificada)

`git am` de `patches/delta5a/0001-*.patch` sobre un worktree limpio de `layer/delta4-d7` produce **exactamente**
el árbol `feef397af39b6f011ea6dd5ad62a3fb496cd9950` (idéntico al commit de código), con el working tree limpio.
El worktree de verificación se retiró tras la comprobación.

## Verificación registrada

- **Host-only:** `conversation_spill_test` → **287 checks passed** (249 de la v1.0.0 + 28 de C8/O2 + 10 de F3). Los
  demás tests host-only del build siguen verdes (cache 4191, memory 25, file 188, prompt-cache 112, stage-plan 79,
  agenda 51).
- **Build CUDA:** `strata.exe` re-enlazado, exit 0, con `STRATA_NATIVE_EXPERTS=ON` y
  `CMAKE_CUDA_ARCHITECTURES=86;89`. sha256 del binario: `a09e5d85b0d4c9d499354c8bb8d61d42f9a53bdf0aa392db3135d4e5fdb28367`.
- **verify-layer.ps1:** 44 anclas OK y 22 flags presentes (incluidos los 5 del archivo). Exit 0.

## Cierre de la auditoría neutral (C8 / O2)

- **C8 (documentación + comportamiento):** riesgo y retención del archivo declarados (texto plano, **sin cifrado**
  ni borrado seguro, carpeta privada) en `docs/FLAGS.md`, `docs/SPILL_AND_PROMPT_CACHE.md` y `CHANGELOG.md`;
  retención = `-keep` + `-mib` + **`--conversation-cache-archive-max-age-days`** (nuevo, default 0 = sin borrado
  por tiempo); el tope **no puede superarse por una sola copia** (una copia mayor que `-mib` no se archiva; el GC
  del presupuesto es estricto). Tests: `D5a/oversized`, `D5a/age`.
- **O2 (robustez):** si el MOVE del `.sess` falla en modo `state`, `archive_entry` revierte lo alcanzado y **deja la
  entrada del tier intacta**; `relocate_file` falla si la remoción de origen falla. Test: `D5a/relocate`
  (fallo forzado con `_sopen_s`/`_SH_DENYRW`).
- **Premisa falsa del plan §4-b** registrada en el informe §9: la base ya saltaba el directorio; la línea es
  defensiva/redundante.

## Cierre del addendum de reauditoría (F1 / F2 / F3)

- **F1:** `CHANGELOG.md` corregido a **277 checks / 5 flags** (era 249 / 4) y ahora **287 checks / 44 anclas**.
- **F2:** la fila de `--conversation-cache-archive-mode` en `docs/FLAGS.md` ahora **documenta** que la cancelación
  nunca guarda K/V (sólo los ids pre-revert), y la referencia cruzada en `docs/SPILL_AND_PROMPT_CACHE.md` se ajustó
  para que diga exactamente eso (sin sobreafirmar).
- **F3:** test `D5a/relocate-multi` que fuerza el fallo **después** de un MOVE exitoso (conversación de dos
  etapas: el `.sess` se mueve, el `.stage1.sess` está retenido ⇒ rollback). Verifica que el `.sess` vuelve al tier
  y la entrada queda intacta.

## No afirmado (para la auditoría neutral)

- El delta **no se midió end-to-end** con el modelo cargado: ni el archivo, ni la compactación, ni la cancelación.
  Lo verificado es host-only + enlace + verificador de capa.
- **No** acelera la lectura posterior a la compactación: recupera trabajo y permite restaurar en modo `state`.
- El modo `state` cuesta como un session file por copia (~30 KB/token medido en producción); acotarlo con
  `--conversation-cache-archive-mib`.
- El modo `ids` archiva el sidecar (ids como int64, ~8 B/token), no los ~4 B/token del presupuesto del diseño.
- La cancelación archiva sólo el sidecar del estado pre-revert (no el K/V), aun en modo `state`.
- `apply-layer.ps1` no se corrió contra un tag nuevo de upstream (no hay push; sin red): la paridad se verificó
  localmente contra `layer/delta4-d7`.
