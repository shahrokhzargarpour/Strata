# A contribution for Strata — disk-backed slots, a system-prompt cache, and residency-agnostic session files

**Audiencia:** el propietario/mantenedor de `Niko1221/Strata`.
**Fecha:** 2026-10-06.
**Base:** `v0.1.40.1` (commit `82f46a8`). Capa **aditiva** sobre esa versión: con los flags ausentes, el comportamiento es el de upstream. Los créditos están al final del documento.

**ESTADO DE LA PROPUESTA: completa y lista para REVISIÓN — NO lista para merge.** Hay puntos aún en curso (§3) y la propuesta de CUDA 13 (§6) está **especificada pero no ejecutada**. Se puede revisar el diseño, los tests y los parches; no se debe mergear hasta que las filas 🟡 estén verdes.

---

## Qué estás revisando (y qué podés esperar)

Cinco bloques. **Cuatro son cambios de código** (todos **apagados por defecto**: sin flags, el motor se comporta como el tuyo) y **uno es una propuesta de build** que **no está ejecutada**.

| # | Bloque | Qué incluye | Archivos | Estado |
|---|---|---|---|---|
| **1** | **Spill por etapa (multi-GPU)** | Que el tier de disco de #1271 funcione con `--layer-split` (un archivo por etapa + sidecar conjunto, validando todas antes de aplicar) y que **el escaneo no borre** los archivos que superan el presupuesto | `conversation_spill.{hpp,cpp}` · `conversation_cache.hpp` · `program/generate.cpp` | ✅ implementado · medido en **una** modalidad |
| **2** | **Dos flags de política** | `--conversation-cache-spill-when-full evict-oldest\|reject` y `--conversation-cache-spill-max-age-days` (0 = sin borrado por tiempo) | `program/generate.cpp` · `conversation_spill.*` | ✅ implementado · tests host-only |
| **3** | **Caché de prefill del system prompt** | `--system-prompt-cache*` (6 flags): persiste el checkpoint raíz como session file, lo recarga al arrancar, detecta el cambio por **hash** y mantiene **variantes** | `conversation_prompt_cache.{hpp,cpp}` · `program/generate.cpp` | ✅ implementado, single-GPU **y multi-GPU** (un archivo por etapa, sidecar de versión 2) · falta la medición en vivo multi-GPU |
| **4** | **Identidad agnóstica a la residencia** | `kv_resident` fuera de la identidad dura ⇒ un session file escrito bajo una residencia se recarga bajo otra | `conversation_file.hpp` (identidad) · camino de carga | ✅ implementado, **con el test del requisito verde**: guardar bajo `--kv-resident` A → reabrir bajo B **se acepta**; cambiar `--kv` o `kv_rot` **se rechaza** |
| **5** | **Propuesta de CUDA 13** | **No es código**: es el build con el toolkit 13.0 y su verificación. **Especificada y completa en §6, NO ejecutada** | — (§6) | 🟡 **propuesta para revisar** |

**Qué podés esperar de este documento:** el diseño y el porqué de cada bloque (§1), cómo está hecho (§2), **qué se probó y cómo** (§3), una propuesta de build cerrada para CUDA 13 (§6), y **las decisiones que preferimos que tomes vos** (§4 — nombres de flags, si `kv_resident` sale o no de la identidad, `max_context`/`mtp_window`, y el alcance no cubierto). No hay afirmaciones sin medición: lo que no está medido está marcado 🟡 y dicho como tal.

**Qué NO incluye este aporte:** SYCL/Intel, el encoder de visión, y ninguna política de borrado automático que no sean las dos de §1.2.

---


---

## Resumen (leé esto y nada más si tenés 2 minutos)

Cuatro cambios, todos **opcionales por defecto** y apoyados en lo que ya existe:

1. **Spill por etapa**: que el tier de disco de #1271 funcione con `--layer-split` (hoy se apaga), y que **el escaneo no borre** archivos que superan el presupuesto (hoy los borra).
2. **Dos flags de política**: `--conversation-cache-spill-when-full evict-oldest|reject` y `--conversation-cache-spill-max-age-days` (0 = sin borrado por tiempo).
3. **Caché de prefill del system prompt** en disco (`--system-prompt-cache*`): guarda el checkpoint raíz como **session file ordinario**, lo recarga al arrancar, **detecta por hash** cuándo el system prompt cambió, y mantiene **variantes** conviviendo.
4. **Identidad agnóstica a la residencia**: `kv_resident` sale de la identidad dura del archivo, y al recargar la residencia se re-arma **según la config vigente** — así un session file sobrevive a cambiar `--kv-resident`.

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
| Serie de parches reproducible | ✅ **9 parches** (`layer/series`). Verificado como tercera parte: clon de la capa + clon de `github.com/Niko1221/Strata` en `v0.1.40.1` → `git am --3way` de los 9 → 9 anclas OK → **paridad de árbol exacta** (`5154502a…`). En el camino apareció un defecto real y quedó arreglado: con `core.autocrlf=true` el checkout reescribía la serie a CRLF (73.365 → 72.137 bytes) y un clon fresco no habría podido aplicarla; `.gitattributes` la marca `-text` |
| Tests host-only | ✅ **spill 102 checks** + **system prompt 52 checks**, más los previos verdes (la identidad nueva suma **112** en el prompt cache y deja el file en **188**) |
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
| `conversation_spill_test` | tier de disco: round-trip, match por sidecar, **rechazo limpio**, evicción por presupuesto, reapertura, **spill por etapa byte a byte**, y las reglas del GC | ✅ **102 checks** |
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
| 4 | Recompilar y re-verificar | host-only (**spill 102** + **prompt cache 52**) + **un smoke con el modelo cargado** + la prueba **G** de la matriz (guardar con `--kv-resident A`, relanzar con `B` distinto) |
| 5 | Registrar la evidencia | versión exacta de `nvcc`, archs usadas y **todas** las cifras medidas con ese build |

**Criterios de aceptación (esto es lo que la haría "resuelta")**

- Compila y enlaza **sin warnings nuevos** de `nvcc`.
- Los tests host-only pasan **con los mismos conteos** (102 + 52).
- **Paridad de tokens** en la prueba G con el build 13.0.
- Las cifras (aceptación de drafts, tiempos de restauración) **no son peores** que con 12.8 — o la diferencia queda **explicada**, no tapada.

**Riesgo residual, declarado:** el comportamiento numérico puede diferir mínimamente entre toolkits (kernels y cadenas FMA distintos). Por eso el criterio es **paridad de tokens**, no "compila y listo". Y por eso preferimos decirlo antes de que alguien lo descubra midiendo.

**Nota para vos:** si compilás vos con tu 13.0 y publicás, este punto se resuelve de tu lado; la propuesta es para que **nuestras** cifras queden con paridad cuando las leas.

---

*Documento preparado **en conjunto** por **szargarpour**, el equipo de StudioZ y **deepseek flash** (asistente), 2026-10-06: szargarpour planteó el problema, fijó los requisitos (multi-GPU indispensable, KV que vive en RAM, agnosticismo a la residencia, y la regla de que sólo se borre por espacio lleno) y revisó cada entrega. Todo lo verificable está en disco: informes de implementación, evidencia cruda de las pruebas y las series de parches. Lo que está marcado 🟡 no está terminado y no debería leerse como terminado.*
