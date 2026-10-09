<!--
SANITIZED COPY — provenance note

This document is a verbatim copy of an INTERNAL working document of StudioZ,
the project that built the on-disk conversation-cache layer published by this
branch. It is published here as technical context so a reader can see the
reasoning behind the code on this branch.

  - It is NOT a document of the destination repository and carries no
    authority over it.
  - It is written in Spanish (the working language of the producing project).
  - Local absolute paths were replaced with `<local-path>` before publishing.
  - Source: <local-path>/01-axiomatico/2026-10-07-plan-delta5a-curacion-bp-y-reevaluacion-v1.2.0.md
  - Source version: v1.2.0
  - Copied: 2026-10-09
-->

# Delta 5a — cierre del gap: confidence dura ≥ 0.95 con la BP curada (v1.2.0)

- **Fecha:** 2026-10-07 · **Versión:** v1.2.0 (actualiza `…-curacion-bp-y-reevaluacion-v1.1.0.md`).
- **Disparador:** re-sembrado #990 en la **BD canónica** `projects\studioz-ai-platform\axiomatico.db` (743 BPs; fila `id=990, vigente=1`). Sin código del motor · sin tocar `delta3` · sin reiniciar `:5011` · sin push.

## 1. Re-evaluación DURA (sin `ctx_rico`) — cruza 0.95

`axiomatico_evaluate_v3`, mismo task, mismo plan C2 (aprobado), **sin** `research_context` (`session_id delta5a-gate-hard2`):

| Corrida | `ctx_rico` | confidence | S2 | S3 | S5 | S6 | `supera_umbral` |
|---|---:|---:|---:|---:|---:|---:|---|
| Original (gate) | 0.0 | 0.936 | 0.7 | 0.847 | 0.752 | 0.697 | false |
| R7 (contexto) | 1.0 | 0.956 | 0.7 | 0.847 | 0.752 | 0.697 | true |
| Dura v1.1.0 (pre-seed) | 0.0 | 0.936 | 0.7 | 0.847 | 0.752 | 0.697 | false |
| **Dura v1.2.0 (post-seed)** | **0.0** | **0.958** | **0.8** | **0.87** | **0.724** | **0.714** | **true** |

`plan_validado=1`, `plan_approval_score=1.0`, `gap=0.0`, `confidence_emitido=true`.
Comparación: **0.936 → 0.956 (ctx_rico) → 0.958 (dura)**.

### 1.1 Movimiento de señales (y su causa)

| Señal | Antes | Ahora | Δ | Causa |
|---|---:|---:|---:|---|
| **S2** | 0.7 | **0.8** | **+0.100** | **BP #990 entró al top-5** con `tipo_tarea=diseno` ⇒ `_s2_tipo_tarea(=diseno, =diseno)=1.0` |
| **S3** | 0.847 | **0.87** | **+0.023** | #990 en el pool con coseno **0.9166** (la más alta) |
| **S6** | 0.697 | **0.714** | **+0.017** | #990 dim `14` alinea con el perfil |
| **S5** | 0.752 | **0.724** | **−0.028** | #990 nace `revisado` sin evidencia empírica (S5=0.42) y **baja** la media del pool |

Balance: **+0.02 (S2) + 0.0046 (S3) + 0.00085 (S6) − 0.0028 (S5) = +0.022 → 0.958**. La palanca dominante fue S2, como se diagnosticó. `pool_size` 18; #990 es `discoverer.best` (cosine 0.9166).

## 2. Brief de implementación

**No cambia.** El brief (`2026-10-07-brief-implementacion-delta5a-v1.0.0.md`) es de diseño; sus 3 refinamientos, flags, tests y verificaciones siguen válidos. La curación de BPs es gobernanza del motor axiomático, no del motor Strata. **Confirmado: queda igual** (la implementación en el worktree no se ve afectada).

## 3. Residuo en la BD `default` (id=990)

**Efecto real sobre el motor del proyecto: NINGUNO.** El server MCP resuelve por proyecto (`config.py::db_path()` con `AXIOMATICO_PROJECT=studioz-ai-platform`), así que lee `projects\studioz-ai-platform\axiomatico.db`. El residuo en `projects\default\axiomatico.db` (1 fila) **no entra** en las evaluaciones del proyecto.

Sí es una **inconsistencia**: `default` es la BD de fallback de cualquier corrida sin `AXIOMATICO_PROJECT` (p. ej. tests, ad-hoc, W3j), y ahí #990 aparecería como una BP de proyecto filtrada al proyecto `default`.

**Recomendación: limpiarlo por soft-archive** (no borrar), que es lo que exige la doctrina de la skill ("NUNCA archivar una BP sin razón documentada"; "no borrar sin política"):

```sql
-- BD: <local-path>
UPDATE best_practices_items SET vigente = 0 WHERE id = 990;
```
- **Por qué `vigente=0` y no `DELETE`:** las 3 vías del discoverer filtran `vigente=1` (FTS `… AND bp.vigente=1`; LIKE `WHERE vigente=1 …`; vector `WHERE vigente=1 AND embedding IS NOT NULL`), así que la fila deja de ser descubrible **sin** borrar el registro (trazabilidad) ni tocar FTS/embeddings a mano.
- Si preferís borrarlo del todo, **también es seguro**: hay trigger `bp_ad AFTER DELETE ON best_practices_items` que mantiene `best_practices_items_fts` sincronizada ⇒ `DELETE FROM best_practices_items WHERE id = 990;`. Queda una fila inocua en `cola_embeddings_pendientes` que el drenado resuelve.
- **Si no lo tocás, no pasa nada funcional**: el motor del proyecto no lo ve. Se puede dejar **documentado** así (opción válida; costo = ruido en `default` si algún día se corre ahí sin proyecto).

## 4. Fuentes

- `axiomatico_evaluate_v3` (0.958 dura; `discoverer.best` #990 cosine 0.9166).
- `storage.py`: triggers FTS (`bp_ai`/`bp_ad`/`bp_au`, líneas 139-152) y filtros `vigente=1` (líneas 672/683) · `semantic_discoverer.py` (líneas 427/441/472) · `config.py::db_path` (W3j) · `cli.py` (seed).
- BD: `projects\studioz-ai-platform\axiomatico.db` (743, canónica) y `projects\default\axiomatico.db` (386, residuo).

**No-afirmaciones:** el cruce 0.958 se obtuvo **sin** `ctx_rico` (0.0); el motor emitió `confidence_emitido=true` y `supera_umbral=true`. No se verificó en vivo el `AXIOMATICO_PROJECT` del proceso MCP (no legible), pero el movimiento de S2/S3 prueba que ahora lee la BD con #990.
