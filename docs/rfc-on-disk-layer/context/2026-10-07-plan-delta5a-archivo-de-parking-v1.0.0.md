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
  - Source: <local-path>/01-axiomatico/2026-10-07-plan-delta5a-archivo-de-parking-v1.0.0.md
  - Source version: v1.0.0
  - Copied: 2026-10-09
-->

# Plan Delta 5a — capa Strata: archivar la copia de parking en vez de borrarla (gate axiomático)

- **Nodo:** GATE AXIOMÁTICO del diseño del delta 5a de la capa Strata (no implementación de código).
- **Fecha:** 2026-10-07 · **Versión:** v1.0.0 · **Estado CDE (ISO 19650-1):** Shared (pendiente de aprobación humana = Published).
- **Autor:** agente axiomático (Grok Build) vía toolport · **Sesión:** Akasha S898 · `session_id` motor `delta5a-gate`.
- **Dominio:** `software` · **Pipeline:** `axiomatic_v3` · **Salida canónica:** `axiomatic_canonical_v3`.
- **Proyección JSON:** `2026-10-07-plan-delta5a-archivo-de-parking-v1.0.0.json` · **MD del gate G-H:** `2026-10-07-gate-GH-delta5a-archivo-de-parking-v1.0.0.md` (escrito por el motor, `out_path`).
- **Base del delta (verificada):** worktree de PRODUCCIÓN `<local-path>` (rama `layer/delta4-d7`). El delta NACE de ahí, no de `layer/delta1`.
- **Naturaleza:** DISEÑO + GATE. No se editó código; no se tocó `<local-path>`; no se reinició/relanzó ningún server (`:5011` sigue sirviendo); no hubo push.

---

## 0. Veredicto del gate (`axiomatico_evaluate_v3`, plan C2 inline)

| Campo | Valor devuelto por el motor |
|---|---|
| `pipeline` / `output_schema` | `axiomatic_v3` / `axiomatic_canonical_v3` |
| **`confidence_score`** | **0.936** (crudo, no forzado) |
| `confidence_emitido` | **true** |
| `umbral` / `supera_umbral` / `gap` | 0.95 / **false** / **0.014** |
| **`plan_validado` / `plan_approval_score`** | **1 / 1.0** (umbral 0.95) |
| `plan_incompleto` / `auto_creado` | `[]` / `false` |
| `axiomas` / `euclidianos` | `[]` / `[]` (el motor NO emitió axiomas; coherencia por ISOs+BPs) |
| `bps_mandatorias` | `[]` |
| `escalation_required` | **false** |
| `dr_handoff_required` | **sí** (`gap_tipo: bp`, `final_confidence 0.936`) |
| `next_action` | `deep-research` → LDR 4-3 auto-disparado en background (`task_id 20261007-233927-a12b78`, `pid 61608`, log `<local-path>`) |
| `score_discriminador` | `discriminacion_suficiente` (0.556; 4/9 señales saturadas) |

### 0.1 Señales (`confidence_signals`)

| Señal | Valor | Peso | Contribución |
|---|---:|---:|---:|
| S1 (disciplina) | 1.0 | 0.25 | 0.25 |
| **S2 (tipo_tarea)** | **0.7** | 0.20 | 0.14 |
| **S3 (coseno)** | **0.847** | 0.20 | 0.1694 |
| S4 | 1.0 | 0.10 | 0.10 |
| **S5 (madurez×evidencia)** | **0.752** | 0.10 | 0.0752 |
| **S6 (dimensión)** | **0.697** | 0.05 | 0.0348 |
| claridad | 0.863 | 0.10 | 0.0863 |
| segmentación | 1.0 | 0.05 | 0.05 |
| fit_akasha | 1.0 | 0.03 | 0.03 |
| ind_silo | 0.0 | −0.03 | 0.0 |
| ctx_rico | 0.0 | 0.02 | 0.0 |

`tipo_tarea = diseno` con `tipo_tarea_origen = new_needed` · `dimension = 13_Optimizacion_Arranque_Tokens` · `pool_size 18` · `ratio_v3 0.4`.

### 0.2 Nota por ítem (`axiomatico_evaluate_waves`, P6, `research=false`)

| Métrica | Valor |
|---|---|
| `n_waves` | 13 |
| `plan_score` | **1.0** |
| `min_confidence` | **1.0** |
| `all_above_threshold` | false |
| `grade` | **B** |
| waves con confidence 1.0 | w1, w2, w4, w5, w7, w8, w13 |
| waves sin score (fail-open del pipeline) | w3, w6, w9, w10, w11, w12 |
| `ceiling_waves` | `[]` (no se aplicó techo) |

El motor marca `grade B` porque 6 waves quedaron **sin score por fallo del pipeline (fail-open)**, no por falta de plan: el `plan_score` global es 1.0 y todas las waves scoreadas dieron 1.0. Se reitera el criterio honesto: **reintentar la evaluación** de esas 6 waves (defecto de motor, no del plan). No se inventó un score para las no emitidas.

### 0.3 Mecanismo de 3 vías (confianza bajo umbral → aplicado antes de devolver)

| Vía | Rol | Qué se hizo | Resultado |
|---|---|---|---|
| **Principal** | agente axiomático | Recon `archivo:línea` sobre `strata-d4r7` (spill hpp/cpp/test, generate.cpp, docs, lock, verify-layer) + redacción del árbol C2 + riesgos + verificaciones | Plan C2 completo (13 nodos, DAG sin ciclos) |
| **Motor** | `axiomatico_evaluate_v3` + `evaluate_waves` + RAG | Evaluación v3 (confidence 0.936), P6 por waves, `rag_consultar` (BPs/ISOs), C3/akasha_fit_check (fit 1.0) y dispatch LDR 4-3 | Gate emitido; LDR de BP en background |
| **Asistente** | `axiomatico_profundizar` (K2-Horizon 7B, `:19006`) | Profundización del árbol (max_depth 2) | `ok:true`, `completo:true`, `iteraciones:0`, **nada que profundizar** (todos los nodos ya atómicos: `deliverable`+`verify`) |

**BP research:** el motor disparó el LDR 4-3 (`task_id 20261007-233927-a12b78`); además se consultó el RAG local (BP#976/977/978/980/964/967/981/974/979/946/923/921/925/420/512) y las fichas ISO. No se inventaron BPs.

### 0.4 Camino para superar 0.95 (asesor del motor, NO aplicado)

`plan_mejora_score`: `alcanzable=true`, `gap=0.014`. La mejora de mayor impacto es **S2** (tipo_tarea `diseno` `new_needed`, 0.7): *"reclasificar el `tipo_tarea` (proveniencia) o curar BPs del `tipo_tarea` correcto"* ⇒ `score_acumulado 0.996 ≥ 0.95`. Secundarias: S3 (0.847), S5 (0.752), S6 (0.697), claridad (0.863), `ctx_rico` (0.0).

**No se aplicó** porque la directiva prohíbe forzar el número sin evidencia: la brecha es de **curación de BPs/clasificación** (trabajo de `actualizar-best-practices`), no del plan. El plan **pasó el gate C2 con 1.0**; la confidence 0.936 es la nota honesta de un dominio cuyo pool de BPs aún no está madurado para este tipo de tarea (mismo orden que Delta 4 = 0.944 y D4-7.3.a = 0.927).

---

## 1. Qué se aprobaría (gate G-H)

El **MD tabulado del gate G-H** quedó escrito por el motor en
`2026-10-07-gate-GH-delta5a-archivo-de-parking-v1.0.0.md` (7 tablas, CDE ISO 19650-1; `valid=True`, 13 nodos, `max_depth=1`).
El humano decide UNA de las tres opciones (APROBAR / RECHAZAR / MODIFICAR). Lo que se somete a aprobación:

- **(a) El DISEÑO del delta 5a** tal como se refina en §3–§4 (archivar en vez de borrar en los tres caminos; opt-in; apagado byte-idéntico).
- **(b) El PLAN de ejecución** (§5, 13 nodos con entregable y verificación por nodo).
- **(c) Las verificaciones con criterio de aceptación** (§8).

**Veredicto técnico del gate:** *plan C2 válido (1.0), coherente con axiomas/ISOs/BPs, ejecutable; confidence 0.936 < 0.95 por causa de curación de BPs (S2/S3/S5/S6), documentada.* El paso a `Published` (aprobación y ejecución) es decisión humana.

---

## 2. Base verificada (evidencia dura `archivo:línea`, `strata-d4r7`)

> Regla de consistencia con la realidad: cada archivo citado EXISTE en `<local-path>` (leído en esta corrida). Las líneas son del árbol d4r7.

**El tier de disco y sus tres borrados/omisiones:**

- `include/strata/core/conversation_spill.hpp:96` — comentario normativo: *"Removal happens only in the GC (enforce_budget and enforce_age)"* → **hoy el único borrador del tier es su GC**.
- `src/core/conversation_spill.cpp:465-486` — `discard_diverged_impl(...)`: si `header==0 || common<header` → otra conversación; si `common>=divergence_tokens` → edición pequeña; si no → `remove_entry(i)` + `++compacted_`. **Es el borrado de compactación.**
- `src/core/conversation_spill.cpp:425-462` — `drop_superseded(...)`: `remove_entry(i)` cuando la copia queda superseded por otra de la misma conversación. **Es el descarte del superseded.**
- `src/core/conversation_spill.cpp:382-396` — `remove_entry(...)`: remueve `.sess` + `.stage<k>.sess` + `.meta` y ajusta `bytes_`/`entries_`. **Es la primitiva de borrado que el archivo debe reemplazar por "mover+archivar".**
- `src/core/conversation_spill.cpp:488-499` — `enforce_budget()` (GC por presupuesto, más viejo primero) y `:501-512` `enforce_age()` (GC por edad, OFF por defecto). **Único borrador legítimo.**
- `src/core/conversation_spill.hpp:44-50` — `conversation_header_length(...)`; `:54-62` `conversation_key(...)`; `:69-80` `revert_to_turn_boundary(...)` (**revierte los ids vivos al último límite de turno en la cancelación**).

**Los tres caminos en el motor (`src/program/generate.cpp`):**

- `:8757-8766` — `spill_on_park` → `conversation_spill.discard_diverged(ids, want_cvec, o.conversation_cache_spill_divergence_tokens, o.turn_token)`; log *"discarded %zu compacted disk conversation(s) …"*. **Camino 1 (compactación).**
- `:8749` — `auto parked = conversations.best(...)`; `:8768-8770` — `disk_match = conversation_spill.best(...)` (el archivo NO debe entrar aquí).
- `:6740-6749` — `park_current_body`: `provisional = spill_on_park && park_provisional` → log *"provisional park (cancelled request); no disk copy"*. **Camino 2 (cancelación): hoy NO publica copia.**
- `:6753-6759` — modo `evict`: `conversation_spill.drop_superseded(live, live_imgs, checks, cvec_cached)`. **Camino 3 (superseded).**
- `:6715-6734` — `spill_evicted` (eviction RAM→disco; en `park` hace `drop_superseded(...)` post-escritura).
- `:6861-6874` — espejo del park: `if (spill_on_park && !provisional) { key=conversation_key(live,o.turn_token); if (park_writer.wants(key, live.size())) { mirrored = image; park_writer.post(key, std::move(mirrored)); } }`.
- `:6676-6680` — `const bool spill_on_park = conversation_spill.enabled() && o.conversation_cache_spill_on == "park"; park_writer.start(&conversation_spill, o.conversation_cache_spill_park_throttle_s);`.

**Flags/parser/documentación/anclas:**

- `src/program/generate.cpp:598-620` (doc de campos), `:765-788` (texto `--help`), `:1803/1816/1824/1835/1843` (parser: `--conversation-cache-spill-dir/-when-full/-max-age-days/-on/-divergence-tokens...`).
- `docs/FLAGS.md:44-54` (tabla de flags del tier) · `docs/SPILL_AND_PROMPT_CACHE.md:15-75` (modos, compactación, cancelación) y `:126-131`.
- `upstream.lock` de d4r7: `layer_version 0.3.2`, base `v0.1.40.1`/`82f46a8`, **33 anclas (A1–A33)**, `flags.tier_de_disco` (9 flags), invariantes (`"Una copia por conversación"`, `"Una petición cancelada deja un estado provisional"`, `"Una copia … prefijo común < divergence-tokens se descarta (compactación)"`).
- `verify-layer.ps1`: verifica anclas (por patrón) y flags con `-Exe` sobre `--help`; el `-Lock` por defecto es el `upstream.lock` del árbol.
- `build-cuda/CMakeCache.txt` (d4r7): configure de producción (`STRATA_NATIVE_EXPERTS=ON`, `CMAKE_CUDA_ARCHITECTURES=86;89`, `STRATA_GGML_DIR=.../third_party/llama.cpp`, `STRATA_BUILD_CONVERSATION_TESTS=ON`, `STRATA_ENABLE_CUDA=ON`).

**Cifras (aportadas por el orquestador; NO re-medidas en esta corrida — ver §7):** `spilled 45455 tokens (1333 MiB)` ⇒ **≈30 743 B/token ≈ 30 KB/token** en modo `state`; modo `ids` ≈ **4 B/token** (id `int32`). Test del tier: **169 checks** actuales.

---

## 3. El problema y el diseño del delta 5a (refinado por el gate)

**Problema.** El tier parkea el estado al terminar cada turno (`parked` crece turno a turno), pero ese estado se **destruye en tres caminos**: compactación (`discard_diverged` → `remove_entry`), cancelación (provisional: no publica copia) y superseded (`drop_superseded` → `remove_entry`).

**Diseño propuesto (a calificar) y resultado del gate: VIABLE, con 3 refinamientos (§4).**

- **Subdirectorio propio** para el archivo (default `<spill-dir>\archive`), con **presupuesto propio** (`--conversation-cache-archive-mib`) y **GC propio** (más viejo primero). El archivo queda **fuera** de `enforce_budget`/`enforce_age` del tier.
- **Modos:** `ids` (solo `.meta`: ids de tokens + imágenes, ≈4 B/token), `state` (`.sess` + `.stage<k>.sess` + `.meta`, ≈30 KB/token), `off` (default de fábrica).
- **Flags** (estilo de la capa, opt-in, default apagado): `--conversation-cache-archive-dir <path>`, `--conversation-cache-archive-mode ids|state|off`, `--conversation-cache-archive-mib N`, `--conversation-cache-archive-keep N`.
- **Contadores:** `archived=N`, `archived_bytes=` en la línea periódica del tier junto a las de park.
- **Reemplazo de la primitiva:** en los tres caminos, `remove_entry` se sustituye por **`archive_entry`** = *mover* los archivos (`.sess`/`.stage<k>.sess`/`.meta`) al subdirectorio de archivo (rename en el mismo volumen = barato) + quitarlo del índice del tier + contar. El `.sess` archivado sigue siendo un **session file de la API** (mismo formato/identidad; BP#976 R4/R5: reemplazo atómico, un solo formato).
- **Cancelación (refinamiento, ver §4-a):** archivar el estado **tal como se leyó (pre-revert)** — no el reverted — para que el archivo capture el trabajo generado; en modo `ids` es barato (~4 B/token).

**Invariantes preservados (y su verificación):** (i) *una copia por conversación* en el **tier vivo** (el archivo, por diseño, puede retener hasta `keep` copias históricas por conversación); (ii) la **cabecera/identidad** (modelo+config, `SessionFileIdentity`) sigue mandando; (iii) el **archivo nunca es candidato de reuso** (su cola no puede ser un acierto: atención causal, BP#977); (iv) **solo el GC borra** — el GC del tier para el tier vivo, el GC del archivo para el archivo; (v) **apagado = byte por byte idéntico** al comportamiento actual (BP#980 R6, BP#978 R1).

**Alcance del valor (no prometer de más):** (a) **recuperabilidad** del trabajo generado (compactación/cancelación/superseded); (b) si el cliente revierte la compactación y reenvía el prompt previo, en modo `state` se puede restaurar sin releer. **NO** acelera la lectura posterior a la compactación.

---

## 4. Refinamientos que introduce el gate (hallazgos del diseño)

Estos tres puntos NO estaban cerrados en el diseño recibido; el gate los eleva a **decisiones de diseño a confirmar** antes de implementar:

- **(a) Cancelación: ¿qué se archiva?** Hoy el park provisional **revierte los ids al último límite de turno** (`revert_to_turn_boundary`, hpp:69-80) *antes* de cualquier copia, y luego suprime la copia durable (`generate.cpp:6865`, `spill_on_park && !provisional`). Archivar *después* del revert guardaría una copia **idéntica a la anterior** (valor nulo). Para capturar el **trabajo generado**, el archivo debe tomar **snapshot del estado tal como se leyó (pre-revert)**. Como el archivo **nunca es candidato de reuso**, esto es seguro (aunque el estado provisional sea inconsistente como prefijo). **Modo `ids`** es el natural aquí (barato; recupera los tokens generados). *Criterio de aceptación:* test que, tras cancelar, el archivo contiene ≥ los tokens del último límite de turno y NO es ofrecido por `best()`.

- **(b) El subdirectorio de archivo NO debe ser contado por el escaneo del tier.** `ConversationSpillCache::open` recorre `directory_` **no recursivamente** (`conversation_spill.cpp:219-229`) y clasifica por extensión: un subdirectorio `archive` cae en la rama `else ++stale_files_kept_` (no es `.meta`/`.sess`). Es inofensivo (no borra, no indexa) pero **contamina el contador `stale`** y confunde el diagnóstico. **Decisión:** o el escaneo **salta explícitamente los directorios** (`if (!is_regular_file(status)) { if (is_directory) continue; ... }`), o el default del archivo es un **directorio hermano**, no anidado. *Criterio de aceptación:* test que la existencia del subdirectorio de archivo deja `stale_files_kept()` sin cambios inesperados.

- **(c) Semántica del tope y de `keep` vs. el GC del tier.** El tope `--conversation-cache-archive-mib` y el por-conversación `--conversation-cache-archive-keep` son **del archivo**; `enforce_budget`/`enforce_age` del tier **no** los aplican y el archivo **cuenta en su propio `archive_bytes`**, no en `bytes_` del tier. La línea periódica debe reportar `archived_bytes` con presupuesto propio para no confundir el presupuesto del tier con el del archivo. *Criterio de aceptación:* test que el archivo no altera `bytes()`/`disk_evictions()` del tier.

> Estos tres hallazgos son la sustancia del gate: sin ellos el delta implementaría un archivo que (a) no guarda lo valioso en la cancelación, (b) ensucia el diagnóstico del tier y (c) mezcla dos presupuestos.

---

## 5. Task tree calificado (C2 v2)

Aristas (D1, `dep` por nodo) · 13 nodos · sin ciclos (BP#953).

| ID | Título | Tipo | ISO | Dep | Entregable | Verificación (criterio) |
|---|---|---|---|---|---|---|
| **D5a0** | Recon: punto de borrado e invariantes en el árbol real | `investigacion` | 12207, 15489-1 | — | Tabla `archivo:línea` del borrado exacto por camino | cada ruta/símbolo existe (grep); `divergence=4096` |
| **D5a1** | Diseño del archivo: modos, formato y GC propio | `diseno` | 12207, 25010, 15489-1 | D5a0 | Diseño con modos `ids`/`state`, formato session file, atomicidad, política de espacio | GC respeta MiB y conserva los más nuevos; formato = session file único |
| **D5a2** | Flags, contadores y ancla de capa | `diseno` | 12207, 10007 | D5a1 | Flags `-dir/-mode/-mib/-keep`, contadores, fila FLAGS.md, ancla en lock | flag desconocido = fatal; sin flags no hay carpeta ni byte |
| **D5a3** | Invariantes y semántica de apagado | `calculo_verificacion` | 25010, 12207 | D5a1 | Lista de invariantes con criterio | el archivo no matchea; apagado no cambia bytes |
| **D5a4** | Instrumentación de los tres caminos y contadores | `diseno` | 25010 | D5a2, D5a3 | Enganche en compactación/cancelación/superseded + `archived=`/`archived_bytes=` | contadores consistentes con los archivos en disco |
| **D5a5** | Tests host-only del archivo | `calculo_verificacion` | 12207, 25010 | D5a4 | Casos en `conversation_spill_test.cpp` | los 169 checks actuales siguen pasando; los nuevos pasan sin GPU |
| **D5a6** | Build CUDA que enlace | `calculo_verificacion` | 12207 | D5a4 | `strata.exe` enlazado | enlace exit 0; tests host-only corren |
| **D5a7** | verify-layer y documentación del delta | `cumplimiento_normativa` | 10007, 12207 | D5a2, D5a5, D5a6 | Verificador verde + FLAGS.md/SPILL_AND_PROMPT_CACHE.md/CHANGELOG con "apagado = idéntico" | `verify-layer.ps1 -Exe` exit 0; todos los flags presentes |
| **D5a8** | Riesgos: espacio, seguridad, concurrencia, alcance | `calculo_verificacion` | 27040, 14721, 27001 | D5a1 | Sección de riesgos con mitigación y no-afirmaciones | cada riesgo cita mecanismo (línea) y mitigación |
| **D5a9** | Confirmar costos y contadores con evidencia de producción | `calculo_verificacion` | 12207 | D5a4 | Tabla medido vs declarado + default de `-mib` | cifra del log citada textual; lo no medido, declarado |
| **D5a10** | Worktree nuevo y no tocar producción | `planificacion_gestion` | 10007, 12207 | D5a0 | Worktree `layer/delta5a` desde `layer/delta4-d7` | rama de producción intacta; sin push |
| **D5a11** | Serie: parches contiguos, paridad de árbol, freeze | `cumplimiento_normativa` | 10007, 12207, 25010 | D5a7, D5a8, D5a9, D5a10 | `patches/`, `FROZEN.md`, verificación previa | árbol byte-idéntico por hash; sin tooling en la serie |
| **D5a12** | Gate axiomático, mermaid e informe | `documentacion` | 15489-1, 23081-1 | D5a11 | Informe `.md`/`.json` + MD del gate G-H | metadatos mínimos, fuentes y mermaid |

**Aristas:** `D5a0→D5a1, D5a10` · `D5a1→D5a2, D5a3, D5a8` · `{D5a2,D5a3}→D5a4` · `D5a4→D5a5, D5a6, D5a9` · `{D5a2,D5a5,D5a6}→D5a7` · `{D5a7,D5a8,D5a9,D5a10}→D5a11` · `D5a11→D5a12`.

Profundización (asistente K2-Horizon): `completo:true`, nada que descomponer — todos los nodos son atómicos (`deliverable`+`verify`).

---

## 6. BPs e ISOs aplicables y fidelidad

**ISOs (catálogo verificado por el motor):** ISO/IEC 25010:2023 · ISO/IEC/IEEE 12207 · ISO/IEC 27001:2022 · ISO 15489-1:2016 · ISO 23081-1:2017 · ISO/IEC 27040:2024 · ISO 14721:2025 · ISO 30300. (En los nodos de compatibilidad/serie y en `almacenamiento_iso` se añade **ISO 10007**.)

**BPs relevantes (por relevancia del motor; ninguna mandatoria dura):**

| BP | Título (res.) | Dim | relevance | Cómo la cumple el delta |
|---|---|---:|---|---|
| **976** | Persistencia tier frío (spill en evicción, session file único, presupuesto y ciclo de vida) | 14 | 0.9152 (cos) | R4 temp+rename; R5 un solo formato (reusa el session file); R6 presupuesto+GC más viejo primero; R2 match por sidecar |
| **980** | Entrega de serie que integra limpia (paridad de árbol, freeze, compare) | 19 | 0.8394 | D5a11: parches contiguos, paridad por hash, FROZEN, sin tooling; R6 "un modo reproduce el previo byte a byte" (= `off`) |
| **978** | Mantenimiento de fork/capa vs upstream (pin, anclas, verificador fail-loud) | 19 | 0.8372 | Ancla propia en `upstream.lock`; `verify-layer.ps1` verde; R5 flag nuevo = default apagado |
| **977** | Prefill del system prompt persistido / estabilidad del prefijo | 14 | 0.837 | No-afirmación de atención causal: el archivo **nunca** es candidato de reuso |
| **967** | Mantenimiento operacional de servers LLM locales | 14 | 0.9385 | Regla dura: no se toca `delta3` ni se reinicia `:5011` (D5a10) |
| **964** | Verificación SOTA antes de implementar | 19 | 0.808 | Este gate (RAG + LDR 4-3 disparado) |
| **974** | Parametrización SSOT / config versionado | 12 | ~0.70 | Flags nuevos con default apagado; nada se hardcodea; no van a configs viejos (flag desconocido = fatal) |
| **979** | Entrega de aporte a terceros (estado explícito, no-afirmaciones) | 19 | ~0.71 | §7 no-afirmaciones; §8 lo no medido |
| **946** | Control de documentos ISO 9001 cl.7.5 | 15 | ~0.49 | Nombre `YYYY-MM-DD-<tema>-v1.0.0`, metadatos, versionado |
| **981** | Lazo plan→agenda (pendientes en Akasha) | 01 | ~0.69 | Pendiente de materializar las hojas del árbol como pendientes (acción post-aprobación) |
| **923/921/925** | ISO/IEC 27040 storage security · ISO 15489 records · ISO 14721/23081 (aplicación) | 17/15/18 | 0.58/0.57/0.56 | Archivo = registro con metadatos; carpeta privada y borrado seguro (riesgo §7); retención con política (GC) |
| **420** | Forense Zero-Trust / registros inmutables | 17 | 0.52 | El archivo preserva evidencia en vez de destruirla |
| **512** | Casos de fallo conocidos (Replit: `DROP TABLE` en prod) | 19 | 0.74 | Antecedente directo: **archivar en vez de borrar** reduce el borrado destructivo |

**`bps_mandatorias = []`.** La rúbrica marca 7 como `BP_MANDATORIA_RECHAZADA` (980, 967, 667, 782, 941, 837, 264): **brecha de curación** (relevance < 0.95 y/o fuente/título fuera de norma), no ausencia de BPs. **No se inventaron BPs.**

**Fidelidad a axiomas:** el motor devolvió `axiomas: []` y `euclidianos: []` — no emitió axiomas explícitos para esta tarea. La coherencia lógica la sostienen las **ISOs** (estructura) y las **BPs** (práctica). Se declara así, sin fabricar axiomas.

---

## 7. Riesgos y no-afirmaciones

**Riesgos (con mitigación):**

| # | Riesgo | Mecanismo real | Mitigación |
|---|---|---|---|
| R1 | **Explosión de disco en modo `state`** (~30 KB/token; 45 455 tok = 1 333 MiB) | `conversation_spill.cpp:310-377` (tamaño real por `.sess`) | Tope propio `--conversation-cache-archive-mib` + GC más viejo primero; default de fábrica `off`; `ids` como modo barato |
| R2 | **El subdirectorio de archivo ensucia el escaneo del tier** | `open()` `:219-229` cuenta el no-`.sess/.meta` como `stale` | §4-b: saltar directorios en el escaneo o archivo como hermano |
| R3 | **Cancelación archiva algo sin valor** | `revert_to_turn_boundary` (hpp:69-80) + `generate.cpp:6865` | §4-a: snapshot pre-revert; test de aceptación |
| R4 | **Seguridad/privacidad del archivo** (contiene tokens e imágenes) | el `.sess`/`.meta` es el mismo formato del tier | Carpeta privada (misma regla que el spill), borrado por GC con contador; declarar no-cifrado; ISO/IEC 27040 |
| R5 | **Concurrencia**: el `ConversationSpillWriter` corre en su hilo | `conversation_spill.hpp:210-374` | El archivo reusa el mismo `mu_`/writer; mover es `rename` atómico; no hay ventana sin copia (patrón supersede: nuevo antes de quitar viejo) |
| R6 | **Apagado no idéntico** (rompe la regla de la capa) | BP#978 R1 / BP#980 R6 | `off` = default; test "apagado no cambia nada"; `verify-layer` con flags |

**No-afirmaciones (obligatorias):**

- El delta **NO acelera** la lectura posterior a la compactación; solo **recupera** trabajo y permite **restaurar** si el cliente revierte la compactación (modo `state`).
- **No** se promete que el archivo sea reutilizable: por atención causal (BP#977) su cola **no puede ser un acierto**; es evidencia/reuperación, no caché.
- **No** está medido end-to-end en esta caja: ni el archivo, ni la compactación, ni la cancelación. Las cifras (30 KB/token, 4 B/token, 169 checks) son **aportadas por el orquestador**, no re-medidas aquí.
- **No** se afirma que los 169 checks sigan pasando: es un **criterio de aceptación**, no un resultado de esta corrida (no se compiló ni corrió código).
- **No** hay compatibilidad binaria entre builds; el archivo nace de `layer/delta4-d7` (no de `layer/delta1`).
- El `grade B` de `evaluate_waves` es **fail-open del motor** (6 waves sin score), no falta de plan: `plan_score` global 1.0. Reintentar la evaluación.

---

## 8. Verificaciones y criterio de aceptación

| # | Verificación (comando/artefacto) | Criterio de aceptación (PASS) |
|---|---|---|
| V1 | `conversation_spill_test` host-only (`-DSTRATA_BUILD_CONVERSATION_TESTS=ON`, sin GPU) | Los **169 checks actuales** siguen pasando **y** pasan los nuevos casos |
| V2 | Caso "divergencia archiva en vez de borrar" (modo `state`) | El `.sess`+`.meta` se **mueven** al archivo; el tier no conserva copia; `archived=1` |
| V3 | Caso "modo `ids` escribe solo `.meta`" | Existe el `.meta` archivado; **no** hay `.sess` en el archivo; `archived_bytes` ≈ 4 B/token |
| V4 | Caso "apagado no cambia nada" | Con `--conversation-cache-archive-mode off` (o sin flags): **ningún** byte nuevo, ningún directorio, contadores en 0 |
| V5 | Caso "tope del archivo" | Con `-mib` excedido: se borran los **más viejos**; se conservan los más nuevos; `archived_bytes ≤ mib` |
| V6 | Caso "contadores consistentes" | `archived` = nº de archivos del archivo; `archived_bytes` = Σ tamaños; consistente con el FS |
| V7 | Caso "una copia por conversación" | En el **tier vivo** no hay dos copias tras un re-park; el archivo respeta `-keep` |
| V8 | Caso "el archivo no participa del matching" | `conversation_spill.best()` / `conversations.best()` **nunca** devuelven un path del archivo |
| V9 | Caso "cancelación archiva pre-revert" (§4-a) | Tras cancelar, el archivo contiene ≥ los tokens del último límite de turno; `best()` no lo ofrece |
| V10 | Caso "el subdirectorio de archivo no altera `stale`" (§4-b) | `stale_files_kept()` no cambia por la mera existencia de `<spill-dir>\archive` |
| V11 | Build CUDA que enlace | `strata.exe` construido, **exit 0**, con `NATIVE_EXPERTS=ON` + `arch 86;89` (evita `bf16_rows_dot_multi`) |
| V12 | `pwsh -File verify-layer.ps1 -Exe <strata.exe>` (lock del árbol d4r7) | **Todas** las anclas OK **y** todos los flags presentes (incluidos los 4 nuevos) |
| V13 | `docs/FLAGS.md` + `docs/SPILL_AND_PROMPT_CACHE.md` + CHANGELOG | Filas de los 4 flags; sección de compactación actualizada con "apagado = idéntico"; ancla en `upstream.lock` |
| V14 | Serie/entrega (D5a11) | Paridad de **árbol por hash**; `patches/` sin tooling; `FROZEN.md` |

---

## 9. Nota sobre el 95 % (leer antes de interpretar el score)

1. El número del motor (**0.936**) se reporta **tal cual**; no se retocó.
2. **`supera_umbral=false`** (gap **0.014**), con plan de mejora **alcanzable** (0.936 → **0.996** vía S2).
3. **Causa conocida y honesta:** S2 (tipo_tarea `diseno` `new_needed`, 0.7) + S3 (coseno 0.847) + S5 (madurez×evidencia 0.752) + S6 (dimensión 0.697): **BPs del tipo de tarea sin `maturity_state`/`evidencia_empírica` y clasificación nueva pendiente**. Curarlas (no inventarlas) es trabajo de `actualizar-best-practices`.
4. El plan **pasó el C2** (`plan_validado=1`, `plan_approval_score=1.0`); la brecha es de **curación de BPs**, no del plan ni del diseño.
5. Consistente con Delta 4 (0.944) y D4-7.3.a (0.927): **mismo orden de magnitud, misma causa**.

---

## 10. Mermaid (flujo del archivado)

```mermaid
flowchart TD
    subgraph HOY["HOY (el estado se destruye)"]
      P["Park al fin del turno: parked crece"] --> C1{"Cliente reescribio la cola? (compactacion)"}
      C1 -->|si, header ok y prefix < divergence| X1["discard_diverged -> remove_entry (BORRA)"]
      C1 -->|no| C2{"Pedido cancelado? (provisional)"}
      C2 -->|si| X2["provisional: NO publica copia (pierde el trabajo)"]
      C2 -->|no| C3["re-park misma conversacion"]
      C3 --> X3["drop_superseded -> remove_entry (BORRA la anterior)"]
    end
    subgraph D5A["DELTA 5a (archivar en vez de borrar; opt-in)"]
      M{"--conversation-cache-archive-mode"}
      M -->|off (default)| O["Identico a HOY, byte por byte"]
      M -->|ids| I["Archiva solo .meta (~4 B/token): recupera tokens/imagenes"]
      M -->|state| S["Archiva .sess + .stage + .meta (~30 KB/token): recupera + restaura si el cliente revierte"]
      X1 -.->|mueve, no borra| A["<spill-dir>\\archive: presupuesto propio + GC mas viejo primero"]
      X2 -.->|snapshot PRE-revert| A
      X3 -.->|mueve, no borra| A
      A --> NB["NUNCA candidato de reuso (atencion causal)"]
      A --> CNT["archived=N, archived_bytes= en la linea periodica"]
    end
    ID["session_identity (modelo+config): el archivo conserva el formato/identidad del session file"] --- A
    GC["enforce_budget/enforce_age: borran SOLO el tier vivo"] --- A
```

---

## 11. Fuentes

- **Código (verificado en esta corrida, `<local-path>`):** `include/strata/core/conversation_spill.hpp` (`:44-50`, `:54-62`, `:69-80`, `:96`, `:210-374`) · `src/core/conversation_spill.cpp` (`:219-229`, `:310-377`, `:382-396`, `:425-462`, `:465-486`, `:488-512`) · `src/core/conversation_spill_test.cpp` (169 checks) · `src/program/generate.cpp` (`:598-620`, `:765-788`, `:1803/1816/1824/1835/1843`, `:6676-6680`, `:6715-6734`, `:6740-6759`, `:6861-6874`, `:8749`, `:8757-8770`) · `docs/FLAGS.md:44-54` · `docs/SPILL_AND_PROMPT_CACHE.md:15-75,126-131` · `upstream.lock` (v0.3.2, 33 anclas) · `verify-layer.ps1` · `build-cuda/CMakeCache.txt`.
- **Motor axiomático (toolport):** `axiomatico_evaluate_v3` (confidence 0.936; C2 1.0; LDR `task_id 20261007-233927-a12b78`), `axiomatico_evaluate_waves` (P6; plan_score 1.0; grade B), `axiomatico_gate_gh` (MD G-H en `out_path`), `axiomatico_profundizar` (K2-Horizon 7B; `completo:true`), `axiomatico_rag_consultar` (BPs/ISOs), `akasha_akasha_query`.
- **BPs primarias:** `02-informes/…/01-axiomatico/2026-10-07-bp-entrega-que-fusiona-limpio-v1.0.0.md` (BP#980) · BP#978 (upstream.lock/verify-layer) · BP#976 (llm.cpp#20697) · BP#977 (llama.cpp#8947) · `09-implementacion/2026-10-07-delta3-batch-mtp-y-head-v1.0.0.md` (lección "un flag no tumba el motor").
- **Producción (regla dura):** `<local-path>` — **NO tocado**; `:5011` sirviendo.
- **Cifras aportadas por el orquestador (no re-medidas):** `spilled 45455 tokens (1333 MiB)`; 169 checks; configure CUDA del `CMakeCache.txt`.

**Supuestos declarados:** (i) esta corrida es el **gate axiomático** del diseño; **no** se compiló, **no** se corrió test, **no** se midió; (ii) las líneas citadas son de `strata-d4r7` a la fecha; (iii) los 3 refinamientos de §4 son **propuestas del gate** a confirmar antes de implementar.

## Almacenamiento ISO

- `02-informes/auditoria-sistema-2026-08-15/01-axiomatico/` — este `.md`, su `.json` y el MD del gate G-H (CDE ISO 19650-1; ISO 15489-1/23081-1; ISO 9001 cl.7.5).
- `asistentes/_tmp/strata-d4r7/` — árbol de base (evidencia de código; `docs/`, `upstream.lock`, `verify-layer.ps1`).
- (futuro, post-aprobación) `asistentes/_tmp/strata-d5a/` — worktree del delta; `09-implementacion/` — informe de implementación.

**Normas:** ISO 10007 · ISO/IEC/IEEE 12207 · ISO/IEC 25010:2023 · ISO 15489-1:2016 · ISO 23081-1:2017 · ISO/IEC 27040:2024 · ISO 14721:2025 · ISO 30300 · ISO 19650-1 (CDE).

## Registro de cumplimiento (síntesis)

| Requisito de la doctrina | Cumplido | Evidencia |
|---|---|---|
| Gate axiomático antes de implementar | **SÍ** | §0; sin código tocado |
| Plan C2 completo (grafo+ubicación+ISO) | **SÍ** | `plan_approval_score=1.0`, `plan_incompleto=[]` |
| BPs e ISOs aplicadas | **SÍ** | §6 (15 BPs, 8 ISOs) |
| >95% | **NO (0.936)** | causa y camino documentados (§0.4, §9); **no forzado** |
| 3 vías (principal/motor/asistente) | **SÍ** | §0.3 |
| LDR de BPs (sin fallback) | **SÍ** | `task_id 20261007-233927-a12b78` |
| Mermaid | **SÍ** | §10 |
| Informe en disco versionado | **SÍ** | este `.md` + `.json` + MD G-H |
| Consistencia con la realidad (rutas existen) | **SÍ** | §2 |
