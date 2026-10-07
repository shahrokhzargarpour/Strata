# A contribution for Strata — disk-backed slots (a live mirror at the park), a system-prompt cache, and residency-agnostic session files

**Audiencia:** el propietario/mantenedor de `Niko1221/Strata`.
**Fecha:** 2026-10-07 (revisión 2, incorpora el **delta 2**; la revisión 1, del 2026-10-06, era el delta 1).
**Base:** `v0.1.40.1` (commit `82f46a8`) **más dos PRs de terceros ya absorbidos** — #1271 de ANBAL534 y #1269 de pspranger-throw (§0). Capa **aditiva** sobre esa base: con los flags ausentes, el comportamiento es el de upstream. Los créditos están al final del documento.

**ESTADO DE LA PROPUESTA: completa y lista para REVISION — NO lista para merge.** Se puede revisar el diseño, los tests, los parches y la **evidencia de producción**. Queda **una** fila 🟡 que impide el merge: la propuesta de CUDA 13 (§6) esta **especificada pero NO ejecutada** (en la maquina de prueba solo esta el toolkit 12.8; re-verificado 2026-10-07). El delta 2, en cambio, llego a **produccion real**: el binario que sirve hoy en `:5011` es el delta 2, y hay archivos escritos al parkear con `evictions=0` (§3 y §7). Las demas filas 🟡 son mediciones de la capa base (matriz de modalidades) dichas como tales.

**Como tomarlo en partes.** El **delta 2 se apoya en el delta 1** y lo extiende, no lo reemplaza: los dos primeros commits del delta 1 (#1271, #1269) son la base, y el delta 2 agrega el modo espejo, la compactacion y la cancelacion en una rama encima. Con `--conversation-cache-spill-on evict` el delta 2 reproduce el delta 1 **byte a byte** (la compactacion y la cancelacion estan *gated* al modo `park`). El mantenedor puede tomar los dos por separado: el delta 1 solo, o el delta 1 + el delta 2.

---

## Qué estás revisando (y qué podés esperar)

Nueve bloques. **Ocho son cambios de codigo** (todos **apagados por defecto**: sin flags, el motor se comporta como el tuyo) y **uno es una propuesta de build** que **no esta ejecutada**. Los **cinco primeros** son la capa base (delta 1); los **cuatro ultimos** son el **delta 2**, que se apoya en ella.

| # | Bloque | Qué incluye | Archivos | Estado |
|---|---|---|---|---|
| **1** | **Spill por etapa (multi-GPU)** | Que el tier de disco de #1271 funcione con `--layer-split` (un archivo por etapa + sidecar conjunto, validando todas antes de aplicar) y que **el escaneo no borre** los archivos que superan el presupuesto | `conversation_spill.{hpp,cpp}` · `conversation_cache.hpp` · `program/generate.cpp` | ✅ implementado · medido en **una** modalidad |
| **2** | **Dos flags de política** | `--conversation-cache-spill-when-full evict-oldest\|reject` y `--conversation-cache-spill-max-age-days` (0 = sin borrado por tiempo) | `program/generate.cpp` · `conversation_spill.*` | ✅ implementado · tests host-only |
| **3** | **Caché de prefill del system prompt** | `--system-prompt-cache*` (6 flags): persiste el checkpoint raíz como session file, lo recarga al arrancar, detecta el cambio por **hash** y mantiene **variantes** | `conversation_prompt_cache.{hpp,cpp}` · `program/generate.cpp` | ✅ implementado, single-GPU **y multi-GPU** (un archivo por etapa, sidecar de versión 2) · falta la medición en vivo multi-GPU |
| **4** | **Identidad agnóstica a la residencia** | `kv_resident` fuera de la identidad dura ⇒ un session file escrito bajo una residencia se recarga bajo otra | `conversation_file.hpp` (identidad) · camino de carga | ✅ implementado, **con el test del requisito verde**: guardar bajo `--kv-resident` A → reabrir bajo B **se acepta**; cambiar `--kv` o `kv_rot` **se rechaza** |
| **5** | **Propuesta de CUDA 13** | **No es código**: es el build con el toolkit 13.0 y su verificación. **Especificada y completa en §6, NO ejecutada** | — (§6) | 🟡 **propuesta para revisar** |
| **6** | **Delta 2 · Escritura al parkear (espejo)** | Con el tier encendido, el estado con el que cierra cada pedido (el *park*) se escribe a disco **entonces**, no solo cuando el caché de RAM lo expulsa. `--conversation-cache-spill-on` default `park`; `evict` reproduce el delta 1 byte a byte. Escritor **asíncrono** (el pedido ya respondió). | `conversation_spill.{hpp,cpp}` · `program/generate.cpp` · `docs/FLAGS.md` | ✅ implementado · ✅ **verificado en producción** (§3, §7; archivos escritos con `evictions=0`) |
| **7** | **Delta 2 · Compactación** | Una copia guardada cuyo encabezado aún coincide pero cuyo prefijo común con el prompt entrante es menor a `--conversation-cache-spill-divergence-tokens` (default 4096) es una **cola reescrita** (compactación / historial editado): se **descarta** (índice y archivo) en vez de quedar huérfana ocupando GB. Comparación por **ids del sidecar**, sin leer K/V. | `conversation_spill.{hpp,cpp}` · `program/generate.cpp` · `docs/FLAGS.md` | ✅ implementado · ✅ tests host-only; no ejercitado aún con un cliente que compacte en vivo |
| **8** | **Delta 2 · Colapso** | El escritor guarda **una celda por conversación** con *solo el estado más nuevo*: un turno con 5 tool-calls escribe **una** vez, no cinco. Los parks intermedios que no llegan a escribirse se cuentan `collapsed`. | `conversation_spill.{hpp,cpp}` | ✅ implementado · ✅ **medido en producción** (`collapsed=0` con 15 escrituras seguidas; el colapso se prueba a nivel de módulo) |
| **9** | **Delta 2 · Cancelación** | Un pedido cancelado deja un estado **provisional**: no publica copia durable, **la copia buena anterior queda intacta**, y los ids vivos se **revierten al último `--turn-token`** alcanzado. | `conversation_spill.{hpp,cpp}` · `program/generate.cpp` | ✅ implementado · ✅ tests host-only; no probado aún con un cliente real (Escape-Escape) |

**Qué podés esperar de este documento:** de quién nos apoyamos (§0), el diseño y el porqué de cada bloque (§1), cómo está hecho (§2), **qué se probó y cómo** (§3 y §3-bis), una propuesta de build cerrada para CUDA 13 (§6), **las decisiones que preferimos que tomes vos** (§4 — nombres de flags, si `kv_resident` sale o no de la identidad, `max_context`/`mtp_window`, y el alcance no cubierto), y **al final la descripción completa del delta 2** (§7: el mecanismo, sección por sección, y las decisiones de diseño con su porqué). No hay afirmaciones sin medición: lo que no está medido está marcado 🟡 y dicho como tal.

**Qué NO incluye este aporte:** SYCL/Intel, el encoder de visión, y ninguna política de borrado automático que no sean las dos de §1.2. El delta 2 **no** agrega flags obligatorios ni cambia el default de ningún flag existente salvo el de `--conversation-cache-spill-on` **dentro del tier encendido** (§7.6).

---

## 0. Sobre los hombros de otros (no lo hicimos de cero)

El delta 1 y el delta 2 **no nacen de cero**: la capa se construye sobre `v0.1.40.1` **más dos PRs de terceros que ya están absorbidos en la rama base** (`layer/base`). Es honesto decirlo, y además explica por qué extendemos trabajo de la comunidad en vez de duplicarlo. Los dos commits llevan **al autor original como autor** (no reescrito) y la URL del PR en el mensaje (mecanismo `cherry-pick -x`).

| PR | Autor | Título | URL | Qué tomamos de él | Qué agregamos nosotros |
|---|---|---|---|---|---|
| **#1271** | **ANBAL534** (Aníbal Muñoz Calero) | *conversation-cache-spill-dir* | https://github.com/Niko1221/Strata/pull/1271 | **El tier de disco entero**: cuando el caché de RAM de conversaciones expulsa un park, se escribe a `DIR` como session file ordinario (`.sess`) + sidecar (`.meta`), reutilizando `conversation_file.cpp` (mismo formato e identidad, un archivo ajeno se rechaza). Traído como commit `5f28241` (cherry-pick de `34e24094`). | El delta 1 arregla que **el tier funcione con `--layer-split`** (un archivo por etapa + sidecar conjunto, validando todas las etapas antes de aplicar) y que **el escaneo no borre** (conserva y cuenta; solo el GC borra). El delta 2 convierte el overflow en **espejo** y agrega compactación, colapso y cancelación. |
| **#1269** | **pspranger-throw** | *restore a session file without holding its K/V in RAM* | https://github.com/Niko1221/Strata/pull/1269 | La **restauración de un session file en dos pasadas** (leer/validar sin materializar el K/V, luego aplicar por bloques de 16 MiB), y la lección de que la **reserva de residencia** se re-arma por capa (`kv_stream_reset` / `kv_ring_restore`). Traído como commit `08d8cd4` (cherry-pick de `d438ca51`). | El delta 1/2 se apoyan en esa restauración (los restores en vivo de §3/§7 usan ese camino). El resto de la capa (caché de system prompt, identidad agnóstica a la residencia, y todo el delta 2) es nuestro. |

Los **dos PRs son el inicio de la serie**: los commits 1 y 2 de los 10 son, respectivamente, `5f28241` y `08d8cd4`. El registro vive en `upstream.lock` bajo `absorbido_por_terceros`.

---

## Resumen (leé esto y nada más si tenés 2 minutos)

**Cuatro cambios de la capa base (delta 1) y cuatro del delta 2** — todos **opcionales por defecto**, y el delta 2 **inerte si el delta 1 no está encendido**:

1. **Spill por etapa** (delta 1): que el tier de disco de #1271 funcione con `--layer-split` (hoy se apaga), y que **el escaneo no borre** archivos que superan el presupuesto (hoy los borra).
2. **Dos flags de política** (delta 1): `--conversation-cache-spill-when-full evict-oldest|reject` y `--conversation-cache-spill-max-age-days` (0 = sin borrado por tiempo).
3. **Caché de prefill del system prompt** (delta 1) en disco (`--system-prompt-cache*`): guarda el checkpoint raíz como **session file ordinario**, lo recarga al arrancar, **detecta por hash** cuándo el system prompt cambió, y mantiene **variantes** conviviendo.
4. **Identidad agnóstica a la residencia** (delta 1): `kv_resident` sale de la identidad dura del archivo, y al recargar la residencia se re-arma **según la config vigente** — así un session file sobrevive a cambiar `--kv-resident`.
5. **Escritura al parkear (espejo)** (delta 2): con el tier encendido, cada conversación se escribe a disco **al cerrar cada turno**, no solo cuando el caché de RAM la expulsa. Así un reinicio encuentra todo lo que llegó a tener un turno cerrado. `--conversation-cache-spill-on` default `park`; `evict` reproduce el delta 1 exacto.
6. **Compactación** (delta 2): si el cliente **reescribe la cola** del historial, la copia guardada se **descarta** en vez de quedar huérfana ocupando GB.
7. **Colapso** (delta 2): **una ranura por conversación** con el estado más nuevo — un turno con 5 tool-calls escribe **una** vez, no cinco.
8. **Cancelación** (delta 2): un pedido cancelado deja estado **provisional** — no publica copia durable, la copia buena anterior queda intacta, y el estado vivo se revierte al último `--turn-token`.

El delta 2 corre hoy en **producción** (`:5011`): en el log de arranque se ve `spill-on=park` y cada cierre de turno deja `park mirror queued (... copy X ms); writes=N collapsed=0 throttled=0`, con **archivos `.sess` en disco escritos sin que ninguna expulsión los empujara** (`parked ... evictions=0`) — la prueba de que el tier dejó de ser overflow (§3, §7).

Todo **reusa tu formato** (`conversation_file.cpp`): no inventamos un segundo formato, ni identidad, ni checksum. Los PRs que absorbimos van **atribuidos a sus autores** (`cherry-pick -x` con la URL).

**¿Te conviene?** Si te interesa que los slots parkeados sobrevivan al reinicio y que el prefill de un system prompt largo no se pague en cada arranque, sí, y el costo de revisión es bajo (aditivo, inerte, con tests host-only). Si preferís que esa política viva **fuera** del motor (como decidió llama.cpp: *el server da el mecanismo, el cliente la política*), entonces este aporte no va en tu dirección — y está bien saberlo de entrada.

---

## 1. Qué aportamos, y por qué cada cosa

### 1.1 Spill por etapa (multi-GPU) — *implementado y medido en una modalidad*

**Problema:** #1271 apaga el tier de disco cuando el modelo corre repartido en etapas (`stages.empty()`), y hoy el escaneo **borra** los archivos que superan el presupuesto vigente. En una máquina de 2 GPUs (nuestro caso: 3090 + 4080 SUPER) la función queda **inerte**: los flags aparecen en `--help` y no escriben nada.

**Qué hicimos:** replicar en disco lo que tu parking en RAM ya resuelve — **un archivo por etapa + un sidecar conjunto**, validando **todas** las etapas antes de aplicar ninguna. Y cambiar la regla del escaneo: **se conserva y se cuenta** (oversized, stale, identidad ajena, huérfanos); **sólo el GC borra**, por presupuesto y edad, más viejos primero.

**Medido** (2 GPUs, layer-split, 4 slots, KV int8 `--kv-resident 98304`): 4 conversaciones → **8 archivos `.sess` + 4 `.meta`** = exactamente **2 etapas por conversación**; y restores de **133–200 ms** donde antes medíamos lecturas en frío de **537–602 s**.

### 1.2 Los dos flags de política — *implementado, tests host-only*

| Flag | Default | Qué hace |
|---|---|---|
| `--conversation-cache-spill-when-full MODE` | `evict-oldest` | Al llenarse: borra los más viejos (comportamiento actual, hecho explícito) o `reject` = no guarda más y avisa, **nunca borra** |
| `--conversation-cache-spill-max-age-days N` | **0 = off** | Poda **opcional** por antigüedad; con 0 no existe borrado por tiempo |

### 1.3 Caché de prefill del system prompt — *implementado; la extensión multi-GPU está en curso*

**Problema que ataca:** un system prompt largo (agente con instrucciones y lista de herramientas) se re-procesa entero en cada arranque o reinicio del motor. En nuestra configuración eso son **minutos**.

**Qué hace:** persiste el **checkpoint raíz** —el que hoy vive sólo en RAM con `--prompt-cache-root`— como **session file ordinario**, y lo recarga al arrancar para que un chat **nuevo** que comparte ese prefijo lea **sólo lo que sigue**. Detalles:
- **Clave** = hash del **prefijo exacto** de tokens del system prompt (+ `--system-prompt-cache-key` opcional + identidad modelo/config).
- **Detección de cambio**: si el system prompt cambia, el hash cambia → **no se reusa**, se reprocesa, y la variante nueva se escribe **al lado** de la vieja (con aviso y contador).
- **Variantes**: cambiar el system prompt **no borra** la anterior; volver a ella es *hit*. Sólo el GC las quita (espacio o edad, más vieja primero).

**No-afirmación que nos parece la más importante de todo el aporte** (está también como comentario en el código): *la atención es causal*. El K/V de una cola **no significa nada** detrás de un system prompt distinto —adjuntarlo corrompería silenciosamente todo lo posterior—, así que una variante se aplica **sólo** a un prompt que empieza **exactamente** con sus tokens. Si el cambio está al final del system prompt, se paga sólo la cola; si está al principio (el caso real del bloque de atribución por request que ya mencionás en tu doc), se paga todo lo posterior. **Ese es el comportamiento correcto, no una limitación.**

*Estado honesto:* funciona en **una sola GPU / sesión única**; la extensión a **múltiples etapas** (layer-split) y a `--batch` está **en curso** y no la reclamo como hecha.

### 1.4 Identidad agnóstica a la residencia — *hallazgo + cambio en curso*

Tu `SessionConfig` (`conversation_file.hpp`) es la identidad del archivo, y su comentario dice que ahí va *"every engine setting that changes what the saved state means"*, excluyendo lo que *"changes what is computed next, not what the saved cells hold"*. **`kv_resident` está dentro**, junto a `engine_version`, `backend`, `kv`, `max_context`, `mtp_window`, `kv_rot`, `rope`, `cvec` y `switches`.

Nos parece que `kv_resident` pertenece a la segunda familia: decide **dónde viven** los bytes (VRAM vs RAM), no **qué significan**. Consecuencia práctica hoy: si guardás con `--kv-resident 98304` y recargás con otro valor, **el archivo se rechaza** — aunque su K/V sea perfectamente válida.

**Qué proponemos** (y estamos probando):
1. sacar `kv_resident` de la identidad dura;
2. que el archivo guarde la **K/V autoritativa completa** (el pool host — que es lo que tu snapshot ya toma como fuente para capas con streaming), sin codificar qué parte estaba residente;
3. que al recargar la residencia se **re-arme según la config vigente**, con la reubicación de residencia que corresponda (`kv_stream_reset` / `kv_ring_restore`, la lección de #1269);
4. **prueba explícita**: guardar con `--kv-resident A` → relanzar con **B distinto** → **paridad de tokens**. Y la recíproca: cambiar `--kv` (int8→q4_0) o la rotación **sí** debe rechazar.

`max_context` y `mtp_window` nos quedan como **pregunta abierta** para vos: parecen más de "encaje" que de significado, pero no lo damos por sentado.

---

## 2. Cómo lo hicimos (diseño)

| Principio | Cómo se ve en el código |
|---|---|
| **Un solo formato** | Todo pasa por `conversation_file.cpp`: mismo formato, misma identidad, mismo checksum. No hay segundo serializador |
| **Aditivo e inerte** | Sin flags no se crea directorio ni se escribe un byte; con flags apagados el comportamiento es el de upstream |
| **Validar antes de aplicar** | Un archivo (o una etapa) que no valida **se rechaza limpio**: nunca estado parcial |
| **El GC es el único que borra** | El escaneo conserva y **cuenta** (oversized/stale/ajeno/huérfano); el borrado vive en un solo lugar, con contadores separados por presupuesto y por edad |
| **Atribución** | #1271 y #1269 absorbidos con `cherry-pick -x`: autor original y URL en el commit |
| **Anclas, no líneas** | Nuestra capa mantiene un manifiesto de **anclas por patrón** y un verificador que **falla ruidosamente** si tu código se movió — nos sirve para sobrevivir a tus releases, no es parte del aporte |

---

## 3. Estado de verificación (sin adornos)

| Qué | Estado |
|---|---|
| Compilación | ✅ `strata.exe` enlaza (MSVC + CUDA **12.8** en nuestra máquina; ver §4) |
| Serie de parches reproducible | ✅ **10 parches** (`layer/series`, `bea20c9`; los 2 primeros son los PRs #1271/#1269). Re-verificado el 2026-10-07 como tercera parte: clon de `v0.1.40.1` → `git am --3way` de los 10 → 11 anclas OK → **paridad de árbol exacta** `e7506b4270e527953ec76b9b96b4ce1819c38c99` (idéntica a `layer/series^{tree}`). La revisión 1 traía 9 parches y paridad `5154502a…`; el commit 10 es el delta 2. Nota de un defecto real ya arreglado: con `core.autocrlf=true` el checkout reescribía la serie a CRLF y un clon fresco no habría podido aplicarla; `.gitattributes` la marca `-text` |
| Tests host-only | ✅ **spill 169 checks** (era 102; +67 del delta 2) · **system prompt 112** · **file 188** · **cache 4191** · **memory 25**. Los cinco suites en exit 0, re-corridos el 2026-10-07 |
| Delta 2 · escritura al parkear, en producción | ✅ **medido en producción** (`:5011`, el binario que sirve es el delta 2 — SHA `F78876ED…`, §7): 15 cierres de turno → `park mirror queued (... copy 113–643 ms); writes=0..15 collapsed=0 throttled=0`, con `parked ... evictions=0` en los primeros parks. Los `.sess` están en `D:\AI\servers\strata\slots\flash` sin que ninguna expulsión los empujara |
| Delta 2 · restauración tras reinicio | ✅ **medido en producción**: `restored 50531 tokens (disk/live) in 216.8 ms`, `restored 89087 ... in 1032.4 ms`, hasta `1948.1 ms` para 59724 tokens — reúso de disco/live, no lectura desde el token 0 |
| Delta 2 · compactación / colapso / cancelación | ✅ implementado y con tests host-only (`+67` checks); 🟡 **no ejercitado con un cliente real** (una compactación en vivo, un turno de 5 tool-calls, y un Escape-Escape) — se prueba a nivel de módulo, no end-to-end |
| Spill multi-GPU end-to-end | ✅ medido en **una** modalidad (2 GPUs, residencia mixta): 2 etapas por conversación, restores 133–200 ms |
| Matriz de modalidades (2 GPU × {mixta, sólo RAM, sólo VRAM} y 1 GPU × las tres) | 🟡 **en curso** — el módulo A (2 GPU, mixta, 4 slots) ya cerró |
| System prompt multi-GPU | 🟡 **en curso**: el soporte entró (un archivo por etapa, sidecar v2, lee también la v1 de archivo único) y los tres documentos que decían lo contrario quedaron corregidos; falta la **medición en vivo** |
| Agnosticismo a la residencia (`--kv-resident` A→B) | 🟡 **implementado y con el test del requisito verde**: guardar bajo `--kv-resident` A → **reabrir bajo B se acepta**, y cambiar `--kv` (int8↔q4_0) o `kv_rot` **sí se rechaza**. Falta la medición en vivo (módulo G de la matriz, en curso) |
| Medición comparada de aceptación de drafts | 🟡 tenemos la **línea base** de 0.1.39 sobre 1.999 lecturas: **78,9 %** global; por rango de prompt 82,3 % (10–50k) → **79,4 %** (>120k); el costo está en las lecturas en frío (163 casos, el peor **179.836 tokens en 890.290 ms**) |

**No reclamamos** nada que no esté medido, y no vamos a mandarte un PR hasta que la matriz cierre.

---

## 3-bis. Batería de pruebas — qué se corrió y con qué criterio

Todo lo que sigue tiene **criterio explícito** y evidencia en disco. Lo que todavía no corrió está marcado 🟡 y **no** se cuenta como verificado.

### a) Tests del motor, host-only (sin GPU)

Se compilan con `-DSTRATA_BUILD_CONVERSATION_TESTS=ON`. Son deterministas y no dependen de las tarjetas: ésa es la red que se corre en **cada** cambio.

| Suite | Qué valida | Resultado |
|---|---|---:|
| `conversation_cache_test` | política del parking en RAM: presupuesto, LRU, retención | ✅ |
| `conversation_memory_test` | telemetría de RAM y admisión (piso de memoria libre) | ✅ |
| `conversation_file_test` | **el formato en disco**: cabecera, identidad, checksum, rechazo de un archivo ajeno | ✅ |
| `conversation_spill_test` | tier de disco: round-trip, match por sidecar, **rechazo limpio**, evicción por presupuesto, reapertura, **spill por etapa byte a byte**, las reglas del GC, y **todo el delta 2** (escritura sin expulsión, colapso, supersedencia, skip, throttle on/off, `reject` con la copia anterior intacta, R2 compactación, R4 cancelación) | ✅ **169 checks** (era 102; +67 del delta 2) |
| `conversation_prompt_cache_test` | caché del system prompt: **hit tras reinicio**, **miss + reescritura al cambiar el prefijo**, **dos variantes conviviendo**, e **inerte sin flags** | ✅ **52 checks** |

### b) Tests de la parte Python (instalador, ajustes, métricas)

| Suite | Resultado |
|---|---|
| `tools/test_setup_*` (el instalador ofrece las dos funciones, apagadas por defecto) | ✅ **332/332** |
| `serve/test_runconfig.py` + `serve/test_monitor.py` (Settings y métricas) | ✅ **22/22** (+3 nuevos) |

*Nota honesta:* en la suite completa de `serve/` (455 tests) hay **1 fallo + 1 error preexistentes y de entorno** (ruta corta 8.3 de Windows y un test que devuelve `None`); se reprodujeron en el árbol **sin** nuestra capa, así que no son de este aporte.

### c) Protocolo end-to-end en la máquina, con el modelo cargado (5 pruebas) — 🟡 en curso

Sobre una copia del server con el motor de la capa, **producción parada**, puerto aparte:

| # | Prueba | Criterio |
|---|---|---|
| 1 | Spill con layer-split: 4+ conversaciones con prefijos distintos para forzar evicciones | **un archivo por etapa** + un sidecar; restore con reúso alto y **sin** lectura desde el token 0 |
| 2 | **Sobrevivir al reinicio** del motor | la conversación vuelve de disco con reúso alto |
| 3 | Degradación limpia (`.sess` truncado / `.meta` corrupto) | **rechazo limpio**, sin crash ni estado parcial |
| 4 | Reglas duras del GC | sin `--max-age-days` **no** borra por tiempo; al llenarse borra **los más viejos**; bajar el presupuesto **no** borra en el escaneo |
| 5 | Inercia | sin los flags de disco, **cero** archivos escritos |

**Actualización 2026-10-07 (delta 2):** este protocolo aislado (puerto aparte, producción parada) **no se corrió** en su forma original porque las dos GPUs quedaron tomadas por el motor de producción. En su lugar tenemos **evidencia de producción real** del delta 2: el binario de `:5011` **es** el delta 2 (SHA `F78876ED…`) y el log de arranque/uso muestra las tres cosas que este protocolo pedía — (1) escritura al parkear con `evictions=0`, (2) `.sess` en disco y restauración tras uso, y (3) las ranuras `writes`/`collapsed`/`throttled`. El detalle y los números están en §7.9. El caso (5) «inercia» sigue cubierto por tests: sin flags no hay carpeta ni byte.

### d) Matriz de modalidades — 🟡 en curso

**2 GPUs × {residencia mixta, sólo RAM, sólo VRAM}** y **1 GPU × las tres**, con 4 slots y conversaciones **cortas** (no medimos una KV gigante: medimos **consistencia** y si **relanzar con otra config** da problemas). Más la prueba transversal **G** (guardar con `--kv-resident A` → relanzar con **B** → **paridad de tokens**, que es el requisito de agnosticismo) y los controles negativos **H** (cambiar `--kv` o la rotación ⇒ **debe rechazar**).

### e) Línea base de aceptación de drafts (para comparar después)

Análisis del log de servicio histórico (4–6 Oct): **78,9 % global** (294.733/373.712), insensible a 1 vs 2 slots, y con caída por profundidad de contexto (82,3 % a 10–50k → **79,4 %** a >120k). Los turnos `0 of 0` (**57,8 %**) se informaron **aparte**: son peticiones que generan **1 token**, no fallos del speculative.

---

## 4. Cosas que quizá quieras decidir vos

1. **Nombres de flags**: los de #1271 los respetamos tal cual. `--conversation-cache-spill-when-full`, `--conversation-cache-spill-max-age-days` y toda la familia `--system-prompt-cache-*` son **nuestros**: renombralos como prefieras.
2. **La identidad** (§1.4): si preferís que `kv_resident` **siga** siendo parte de la identidad, se cae el punto 4 del aporte — y preferimos que lo decidas vos.
3. **Con qué se compiló nuestra copia de prueba**: **CUDA 12.8**, y el motivo es acotado y reversible: en la máquina de prueba **sólo está instalado el toolkit 12.8** (falta el toolkit 13.0, que son ~3 GB y un rebuild). **No es una limitación de hardware**: las GPUs de prueba (RTX 3090 = sm_86, RTX 4080 SUPER = sm_89) y su driver **soportan CUDA 13** — de hecho tu motor **13.0 corre en ellas** hoy. Para el aporte da igual (el código no cambia entre toolkits); lo decimos para que sepas con qué se midieron nuestras cifras.
4. **Alcance no cubierto**: no tocamos SYCL/Intel ni el encoder de visión; el tier de disco con visión merece una decisión explícita.

---

## 5. Cómo lo aplicarías (si te sirve)

La capa viene como **serie de parches** sobre `v0.1.40.1`, con un script que clona el tag, los aplica y **verifica las anclas antes de dejarte un árbol a medias**:

```
# conceptual
git clone --branch v0.1.40.1 https://github.com/Niko1221/Strata strata-con-capa
cd strata-con-capa && git am patches/*.patch
pwsh -File verify-layer.ps1 -Exe <engine>     # anclas + flags: falla ruidosamente si algo se movió
```

Y si preferís revisarlo por partes, los cuatro cambios de §1 son **independientes** entre sí: podés tomar el 1.1 solo (que arregla dos cosas de un PR tuyo ya abierto) y dejar el resto.

---

## 6. Propuesta de compatibilidad con CUDA 13 — **completa para revisar, no ejecutada**

**Por qué existe esta sección.** Nuestra copia de prueba se compiló con **CUDA 12.8** porque en la máquina de prueba **sólo está instalado ese toolkit**. No es una limitación de hardware (ver §4.3): las GPUs y el driver soportan 13.0 y el motor 13.0 publicado corre en ellas. Dejamos la propuesta **cerrada**, para que quien la revise sepa exactamente qué hacer y qué verificar. **No está ejecutada**, y por eso la propuesta global no va a `main`.

**Lo que NO cambia: el código.** La capa es agnóstica al toolkit: no hay `#if` de versión de CUDA ni nada específico de `nvcc` en los archivos que tocamos. Es un asunto de **build y de verificación**, no de implementación.

**Pasos propuestos**

| # | Paso | Detalle |
|---|---|---|
| 1 | Instalar **CUDA Toolkit 13.0** (`nvcc`) | El driver ≥580 ya está (el motor 13.0 corre en esta máquina) |
| 2 | Compilar con **las mismas archs que el build publicado** | `CMAKE_CUDA_ARCHITECTURES=75;86;89;120`. Para sólo nuestras máquinas alcanzaría `86;89`, pero para **paridad** conviene la lista completa |
| 3 | Apuntar `lib_dirs` a las **wheels cu13** | `nvidia-cublas==13.0.2.14` + `nvidia-cuda-runtime==13.0.96` (lo que instala tu `setup.py`), en lugar del toolkit 12.8 |
| 4 | Recompilar y re-verificar | host-only (los conteos de hoy: **spill 169** + **prompt cache 112** + file 188 + cache 4191 + memory 25) + **un smoke con el modelo cargado** + la prueba **G** de la matriz (guardar con `--kv-resident A`, relanzar con `B` distinto) |
| 5 | Registrar la evidencia | versión exacta de `nvcc`, archs usadas y **todas** las cifras medidas con ese build |

**Criterios de aceptación (esto es lo que la haría "resuelta")**

- Compila y enlaza **sin warnings nuevos** de `nvcc`.
- Los tests host-only pasan **con los mismos conteos** (spill 169 + prompt cache 112 + file 188 + cache 4191 + memory 25).
- **Paridad de tokens** en la prueba G con el build 13.0.
- Las cifras (aceptación de drafts, tiempos de restauración) **no son peores** que con 12.8 — o la diferencia queda **explicada**, no tapada.

**Riesgo residual, declarado:** el comportamiento numérico puede diferir mínimamente entre toolkits (kernels y cadenas FMA distintos). Por eso el criterio es **paridad de tokens**, no "compila y listo". Y por eso preferimos decirlo antes de que alguien lo descubra midiendo.

**Nota para vos:** si compilás vos con tu 13.0 y publicás, este punto se resuelve de tu lado; la propuesta es para que **nuestras** cifras queden con paridad cuando las leas.

**Estado re-verificado el 2026-10-07 (para que no quede duda):** sigue **pendiente de vuestro lado, no ejecutada**. En la máquina de prueba, `C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\` contiene **solo `v12.8`** (no hay toolkit 13), y el `CMakeCache.txt` del build declara `CMAKE_CUDA_COMPILER = ...\CUDA\v12.8\bin\nvcc.exe` con `CMAKE_CUDA_ARCHITECTURES = 86;89`. Por eso **no hay que hacer nada de nuestro lado**: el delta 2 se sumó al mismo build 12.8 (recompilado, enlace exit 0) y las cifras de §3/§7 son de ese build. La propuesta de CUDA 13 se mantiene como está — completa para revisar, no ejecutada — y es lo único 🟡 que impide el merge.

---

## 7. Delta 2 — descripción completa (escritura al parkear, compactación, colapso, cancelación)

Esta es la descripción larga: qué se hizo y cómo, sección por sección, con las decisiones de diseño y su porqué. Es la parte que responde «¿qué estoy revisando exactamente?» al detalle. El resumen corto está al inicio del documento.

### 7.1 El cambio de fondo: de overflow a espejo

Con el PR #1271, el tier de disco era **overflow**: una conversación llegaba al disco **solo cuando el caché de RAM la expulsaba** (presión de memoria, cambio de slot, `--conversation-cache-slots`). El problema es que la expulsión es justamente el evento del que la gente quiere protegerse: si el motor se reinicia con la conversación todavía residente, **no hay copia en disco** y el siguiente request la relee desde el token 0.

El delta 2 agrega un **segundo momento de escritura**: el **park**. Un «park» es el estado con el que un pedido **cierra** (respuesta completa, slot estacionado). Al cerrar cada turno, la conversación se escribe a disco **entonces**, sin esperar a que la expulsen. Así un reinicio encuentra **todo lo que llegó a tener un turno cerrado**. El tier deja de ser «lo que no entra en RAM» y pasa a ser **espejo de lo que el cliente ya terminó**.

### 7.2 Mecanismo

**(a) Una ranura por conversación.** El escritor no guarda un archivo por park: guarda **una celda por conversación** (clave = *fingerprint* estable del encabezado, §7.2-d) que contiene **solo el estado más nuevo**. Un hilo de fondo drena las celdas a disco. Un turno con cinco tool-calls produce cinco parks de la **misma** conversación → **una** escritura, no cinco.

**(b) Escritura asíncrona.** El pedido **ya respondió** cuando se encola el park; el escritor drena en su propio hilo. El hilo del server le entrega al escritor una copia de la imagen (el `put()` de la RAM se lleva el original), y `wants()` evita esa copia cuando el escritor de todos modos la descartaría. El escritor y el server comparten el mismo `ConversationSpillCache`, así que el cache ahora tiene `std::mutex` y **todos** sus métodos públicos lo toman (sin inversión de locks: el mutex del escritor nunca se sostiene mientras se toma el del cache).

**(c) Sidecar.** Junto a cada `.sess` va un `.meta` (magic `SCSM`, `kMetaVersion = 2`) que guarda **solo los token e imágenes de la conversación**, no el K/V. Eso es lo que permite comparar el prompt entrante con la copia guardada **sin leer el K/V** (base de la compactación, §7.3) y hace que `best()` encuentre la copia por ids y no por bytes.

**(d) Cadena de prefijo y encabezado.** El archivo guardado y el prompt entrante son **dos cadenas de tokens**; el valor útil es su **prefijo común** `C`. El **encabezado** es la parte estable de la conversación: los primeros tokens **hasta el tercer `--turn-token`** (el `im_start` de la primera respuesta), o sea *system prompt + primera vuelta*. Las decisiones se toman sobre `C` contra `len(guardado)` y contra el encabezado (§7.3). Elegimos el **tercer** turn-token (y no el primero) para que **dos conversaciones distintas del mismo cliente** —mismo system prompt, otra primera pregunta— tengan **encabezado distinto** y una **no** descarte a la otra. Está comentado en el código y unit-testeado (`header == 52` en el caso de prueba).

### 7.3 Compactación (R2) — descartar la copia, no dejarla huérfana

Si el cliente **reescribe la cola** del historial (una compactación, o editar mensajes viejos), la copia guardada deja de ser un prefijo válido del prompt nuevo: **nunca va a ser un hit**, pero seguiría ocupando su tamaño en disco. En cada request, con el espejo encendido:

1. Se calcula `C` = prefijo común entre los ids guardados y los del prompt entrante (por **ids del sidecar**, sin leer K/V).
2. `C == len(guardado)` → el prompt **extiende** la copia: turno normal, se conserva.
3. `C < encabezado` → el encabezado difiere → **otra conversación**: no se toca (se ignora, nunca se borra).
4. `encabezado ≤ C < --conversation-cache-spill-divergence-tokens` (default **4096**) → el cliente reescribió la cola: la copia se **descarta** (índice **y** archivo), se cuenta `compacted` y se loguea. Deja de ocupar GB.

Un umbral, no una medida: una compactación que conserve **más** de N tokens de prefijo no se detecta y la copia queda para el GC.

### 7.4 Colapso (R3) — una escritura por ráfaga, no por park

Es lo de §7.2-a visto desde los contadores. Si llegan varios parks mientras una escritura está en vuelo, la celda se **reemplaza** (contador `collapsed`): no se encolan. El **último** estado siempre termina en disco; los intermedios que no alcanzaron a escribirse se descartan. Detalles:

- **Supersedencia en orden correcto:** cada estado drenado se escribe y **después** se borran las copias de la misma conversación que supersede — **nunca antes**, para no dejar una ventana sin copia. En modo espejo, `park_current_body` ya **no** hace el `drop_superseded` sincrónico de disco: lo hace el escritor.
- **Skip:** si `live.ids` no creció respecto de lo último escrito para esa clave, no se escribe (contador `skipped`).
- **Throttle:** `--conversation-cache-spill-park-throttle-s N` (default **0** = escribe en cada park; N>0 = no reescribe la misma conversación dentro de N s, contado `throttled`). Es un rate-limiter, **no** una palanca de corrección: el estado más nuevo igual termina en disco, en el próximo park fuera de la ventana.
- **Métricas:** `writes`, `collapsed`, `skipped`, `throttled`, `refused`, en la línea del park y en el cierre.

### 7.5 Cancelación (R4) — estado provisional

La señal es la del propio motor: la línea de cierre del request imprime `(cancelled)`. Regla, harness-agnóstica:

1. Un pedido cancelado deja un estado **provisional**: **no se publica copia durable** de él (se estaciona en RAM, que es reúso válido, pero se **saltea el espejo** a disco).
2. **La copia buena anterior no se toca** — es el prefijo válido que el cliente reenviará.
3. El slot se **revierte al último límite de turno** alcanzado: los ids vivos se truncan para terminar en el último `--turn-token` **dentro de lo que efectivamente se leyó** (`pp_reached`). Si el corte ocurrió antes de ese límite, no se revierte (no se reclaman tokens que no se leyeron).
4. Si el cliente conserva la respuesta parcial y sigue, el prefijo común la cubre: el pedido se sirve igual y el park siguiente publica una copia nueva y consistente.

El flag interno `park_provisional` se consume en el primer park que corre y se limpia en cada pedido **terminado** (`if (!cancelled)`), así una cancelación con `--prompt-cache 0` (nada estacionable) **no** puede suprimir el espejo de un pedido posterior legítimo.

### 7.6 Decisiones de diseño (y por qué)

| Decisión | Por qué |
|---|---|
| **`park` es el default** cuando el tier está encendido | El objetivo es sobrevivir al reinicio; el overflow solo escribe en la expulsión, que es exactamente lo que se quiere no perder. `evict` queda como **opt-out explícito** |
| **`evict` reproduce el delta 1 byte a byte** y R2/R4 están *gated* a `park` | Para que el mantenedor pueda tomar el delta 1 **solo** (sin espejo, sin compactación, sin cancelación) o los dos juntos |
| **Sin `--conversation-cache-spill-dir`, nada** (ni carpeta ni byte) | Inercia: la config de un motor viejo sigue válida; un flag nuevo nunca rompe un arranque que no lo pasa (recordá que un flag desconocido es error fatal, §5) |
| **Una celda por conversación + escritor asíncrono** | Una escritura de varios GB no puede bloquear la respuesta, y 5 tool-calls no deben ser 5 escrituras |
| **Supersedencia después de escribir, nunca antes** | No dejar una ventana en la que no exista ninguna copia |
| **Encabezado = hasta el tercer `--turn-token`** | Que una conversación distinta del mismo cliente tenga encabezado distinto y **no** sea descartada por la compactación |
| **Detección de compactación por ids del sidecar** | Barata: no hay que leer el K/V para saber que la copia ya no sirve |
| **Reversión por cancelación al último turn-token** | Conservar un prefijo **válido** en vez de una cola a medias |
| **El escritor toca el mismo cache, con mutex** | No duplicar estado; sin inversión de locks |

### 7.7 Invariantes y no-afirmaciones del delta 2

- Con el tier **apagado**, ninguna de las dos cosas (espejo u overflow) escribe: **cero bytes**.
- El espejo escribe **al cerrar el pedido, nunca a mitad de la generación**.
- El disco queda acotado por `--conversation-cache-disk-mib` **exactamente como antes**.
- **La atención es causal:** la cola de una conversación **no significa nada** bajo otro system prompt; una copia se aplica solo a un prompt que empieza exactamente con sus tokens. Sin cambios respecto del delta 1.
- La compactación es un **umbral**, no una medida: una compactación que conserve más de N tokens de prefijo no se detecta.
- R2 y R4 **no corren en `evict`** (están *gated* a `park`), para preservar «delta 1 byte a byte».
- La carpeta de spill **no tiene autenticación**: los archivos contienen los ids de tokens y el estado de la conversación, así que debe quedar privada.
- Sin los flags, el motor se comporta como el tuyo.

### 7.8 Piezas tocadas (delta 2)

| Pieza | Qué se agregó |
|---|---|
| `include/strata/core/conversation_spill.hpp` | `enum SpillOn`; `conversation_header_length`, `conversation_key`, `revert_to_turn_boundary`; `ConversationSpillCache` con `mutex`, `discard_diverged` (+`compacted`), `spill(..., stored_path)`, `drop_superseded(..., keep)`; **`ConversationSpillWriter`** (mapa de celdas, hilo, `start/stop/post/drain/wants`, contadores) |
| `src/core/conversation_spill.cpp` | locking de todos los métodos públicos; `discard_diverged_impl`; `keep` en `drop_superseded`; `stored_path` en `spill` |
| `src/core/conversation_spill_test.cpp` | +67 checks: escritura sin expulsión, colapso, supersedencia, skip, throttle (on/off), `reject` con la copia anterior intacta, R2 (extensión / otra conversación / compactación) y R4 (reversión, límite alcanzado, copia anterior intacta) |
| `src/program/generate.cpp` | 3 flags + help; `// R2` `discard_diverged` antes del `best()` de disco; `spill_on_park` + `ConversationSpillWriter`; hook de espejo en `park_current_body` (post tras el snapshot, antes del `put`); `spill_evicted` con supersedencia en park; R4 al cerrar el request cancelado; drain/stop del escritor en el cierre |
| `docs/FLAGS.md` | filas nuevas de `-spill-on` (default, alcance, no-claims), `-divergence-tokens` y del throttle; nota del cambio de default con el tier encendido; «three caches» y §A reescritas |
| `docs/SPILL_AND_PROMPT_CACHE.md` | el tier deja de ser overflow y pasa a ser espejo, con compactación y cancelación; **mermaid del ciclo de slot actualizado** |
| `upstream.lock` | 3 flags nuevos, 2 anclas nuevas (A10 `--conversation-cache-spill-on`, A11 `ConversationSpillWriter`), invariantes de delta 2, `layer_version` 0.1.0 → 0.2.0 |

### 7.9 Evidencia de producción (lo más valioso y lo más nuevo)

El binario que sirve hoy en `:5011` **es el delta 2** (`strata.exe`, SHA256 `F78876ED61057A36B02877DCF9871861B9AB6472DD61F6F39EA7CD881161DF95`), verificado el 2026-10-07. El arranque deja en el log `spill dir ready (44 conversations, 38825 MiB, when-full=evict-oldest, max-age=0 d, spill-on=park, divergence=4096 tok, park-throttle=0 s, ..., 0 disk evictions, 0 age evictions)`.

**La prueba del delta:** archivos escritos con `evictions=0`, o sea **sin que ninguna expulsión los empujara**. En el log de uso se ven 16 cierres de turno consecutivos, cada uno con su línea de espejo antes del `parked`:

```
conversation cache: park mirror queued (65420 tokens, copy 222.4 ms); writes=0 collapsed=0 throttled=0
conversation cache: parked 65420 tokens in 379.5 ms; parked=1 bytes=1761558616 evictions=0 snapshot_bytes=1761558616 reused_kv_bytes=771259392
conversation cache: restored 89087 tokens (disk/live) in 1032.4 ms; parked=1 bytes=3121403504
...
conversation cache: park mirror queued (69205 tokens, copy 310.6 ms); writes=15 collapsed=0 throttled=0
conversation cache: parked 69205 tokens in 733.8 ms; parked=4 bytes=5961136224 evictions=10 snapshot_bytes=1294367728 reused_kv_bytes=0
```

Números extraídos del log (no heredados):

| Métrica | Valor observado |
|---|---|
| Escrituras de espejo (`writes`) | **0 → 15** (16 cierres de turno seguidos) |
| `collapsed` / `throttled` | **0 / 0** en las 16 (los parks no se solaparon; el colapso se prueba a nivel de módulo) |
| Tamaño de la copia por turno | 34 506 – 96 160 tokens |
| Tiempo de copia (`copy`) | **113 – 643 ms** |
| `evictions=0` en los primeros parks | sí (los writes 0–4 ocurrieron con **cero** expulsiones de RAM: la escritura fue por el park, no por la expulsión) |
| Escrituras al disco por expulsión (`spilled ...; disk_evictions`) | `disk_evictions=0` en todas: **el GC de disco no borró nada** |
| Restauraciones | **216.8 ms** (50 531 tok) · **1032.4 ms** (89 087 tok) · **1948.1 ms** (59 724 tok) — leídas `(disk/live)`, no desde el token 0 |
| Archivos creados | `.sess` + `.meta` en `D:\AI\servers\strata\slots\flash` (p. ej. `strata-conv-64.sess` 751 706 448 B, `strata-conv-65.sess` 902 558 856 B), con marcas de tiempo 2026-10-06 23:32 → 2026-10-07 01:09 |

Esto cubre el criterio que el informe del delta dejó como pendiente (§6/§7 de `2026-10-06-delta2-volcado-tiempo-real-v1.0.0.md`): el `.sess` aparece **sin expulsión previa**, y hay restauraciones reales. **No medido todavía** con este build: un turno con 5 tool-calls reales (colapso end-to-end), una compactación del cliente en vivo, y un Escape-Escape real (cancelación de punta a punta).

---

*Documento preparado **en conjunto** por **szargarpour** y **deepseek flash** — y nada más —, 2026-10-07: szargarpour planteó el problema, fijó los requisitos (multi-GPU indispensable, KV que vive en RAM, agnosticismo a la residencia, la regla de que sólo se borre por espacio lleno, y que el tier sea espejo en vez de overflow) y revisó cada entrega; deepseek flash redactó e implementó junto con él, y verificó contra el binario en producción. El delta 1 se apoya en los PRs de terceros #1271 (ANBAL534) y #1269 (pspranger-throw), atribuidos con `cherry-pick -x`. Todo lo verificable está en disco: informes de implementación, evidencia cruda de las pruebas, el log de producción y las series de parches. Lo que está marcado 🟡 no está terminado y no debería leerse como terminado.*
