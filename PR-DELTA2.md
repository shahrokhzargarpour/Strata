# PR (delta 2) — disk tier: `--conversation-cache-spill-on park` (a mirror at the park), compaction and cancellation

> Documento **listo para pegar** en un PR contra `Niko1221/Strata`. No se abrió ningún PR ni se hizo push: el aporte se prepara en disco y entregarlo es decisión del mantenedor.

---

## Título propuesto

```
serve: the disk conversation tier mirrors at the park (--conversation-cache-spill-on park), compacts rewritten tails, and cancels cleanly
```

Alternativas, si preferís más corto:

- `serve: write parked conversations to disk at park time (a live mirror), with tail compaction`
- `disk tier: park mirror + divergence compaction + cancel-safe state`

---

## Qué hace

El tier de disco de conversaciones deja de ser **solo overflow** y pasa a ser **espejo**. Con el tier encendido, el estado con el que **cierra cada pedido** (el *park*) se escribe a disco **entonces**, no solo cuando el caché de RAM lo expulsa, así un reinicio encuentra todo lo que llegó a tener un turno cerrado.

Tres cosas más, todas dentro del tier y **apagadas por defecto**:

1. **Compactación.** Una copia guardada cuyo encabezado aún coincide pero cuyo **prefijo común** con el prompt entrante es menor a `--conversation-cache-spill-divergence-tokens` (default **4096**) es una **cola reescrita** (compactación del historial o edición): se **descarta** (índice y archivo) en vez de quedar huérfana ocupando GB. Se compara por los **token ids del sidecar**, sin leer el K/V.
2. **Colapso.** El escritor guarda **una celda por conversación** con solo el estado más nuevo: un turno con 5 tool-calls escribe **una** vez, no cinco. Los parks intermedios que no llegan a escribirse se cuentan `collapsed`. La escritura es **asíncrona** (el pedido ya respondió).
3. **Cancelación.** Un pedido cancelado deja un estado **provisional**: no publica copia durable, **la copia buena anterior queda intacta**, y los ids vivos se **revierten al último `--turn-token`** alcanzado.

Flags (todos nuevos, todos con default inerte):

| Flag | Default | Qué hace |
|---|---|---|
| `--conversation-cache-spill-on MODE` | **`park`** cuando el tier está encendido | `park` = espejo al cerrar el pedido; `evict` = comportamiento delta 1 byte a byte; sin `--conversation-cache-spill-dir`, ninguno de los dos hace nada |
| `--conversation-cache-spill-divergence-tokens N` | `4096` | Umbral de prefijo común bajo el cual una copia de encabezado coincidente se lee como cola reescrita y se descarta |
| `--conversation-cache-spill-park-throttle-s N` | `0` (off) | No reescribe la misma conversación dentro de una ventana de N s (rate-limiter; el estado nuevo igual termina en disco) |

---

## Por qué

- **El overflow pierde justo lo que la gente quiere conservar.** Con solo overflow, una conversación llega al disco **cuando el caché de RAM la expulsa**. Si el motor se reinicia con la conversación todavía residente, no hay copia y el próximo request relee el prompt desde el token 0.
- **El park es el momento natural de consistencia.** Escribir al **cerrar el turno** (nunca a mitad de la generación) da una copia que el cliente puede volver a pedir sin ambigüedad.
- **La compactación deja basura.** Si el cliente reescribe la cola del historial, la copia vieja nunca más es un hit, pero seguiría ocupando su tamaño en disco. Descartarla es puro beneficio.
- **Cinco tool-calls no son cinco escrituras.** El colapso evita multiplicar una escritura de varios GB por turno.

---

## Cómo probarlo

Sin GPU (rápido, determinista):

```powershell
cd <arbol-de-la-capa>
cmd /c _host_build.bat
.\build-host\conversation_spill_test.exe        # 169 checks (era 102; +67 del delta 2)
```

Con el modelo cargado (criterios de aceptación):

```powershell
& $BIN --serve --port 5012 `
    --pack <pack> --native <gguf> ... `
    --conversation-cache-mib 8192 --conversation-cache-slots 4 `
    --conversation-cache-spill-dir $DIR --conversation-cache-disk-mib 65536 `
    --conversation-cache-spill-on park
```

En el log, al cerrar cada pedido:

```
conversation cache: park mirror queued (65420 tokens, copy 222.4 ms); writes=0 collapsed=0 throttled=0
conversation cache: parked 65420 tokens in 379.5 ms; parked=1 bytes=1761558616 evictions=0 ...
```

Criterios:
1. El `.sess` (+ `.meta`) aparece en `$DIR` **sin expulsión previa**: `park mirror queued ... writes=N` con `parked ... evictions=0`. Esa es la prueba del delta.
2. Reiniciar el motor y volver a pedir la misma conversación → `restored ... (disk/...)` con el mismo texto.
3. `disk_evictions=0` en las líneas `spilled`: el GC de disco no borra nada por el cambio.

Aplicar la serie completa:

```powershell
git clone --branch v0.1.40.1 https://github.com/Niko1221/Strata strata-con-capa
cd strata-con-capa && git am patches/*.patch
pwsh -File verify-layer.ps1 -Exe <engine>     # 11 anclas + 15 flags; exit 1 si algo se movió
```

---

## Qué NO hace

- **No toca el camino que ya reutiliza:** no arregla residencia de VRAM ni planificación. Solo agrega el momento de escritura y las políticas de descarte.
- **No cambia ningún default fuera del tier encendido.** Sin `--conversation-cache-spill-dir`, `park` y `evict` son inertes (ni carpeta ni byte); la config de un motor viejo sigue válida.
- **No reutiliza la cola bajo otro system prompt.** La atención es causal: una copia se aplica solo a un prompt que empieza **exactamente** con sus tokens.
- **No mide divergencia fina:** el umbral de compactación es un umbral, no una medida — una compactación que conserve más de N tokens de prefijo no se detecta y queda para el GC.
- **No autentica la carpeta:** los archivos contienen ids de tokens y estado; la carpeta debe quedar privada.
- **R2 y R4 no corren en `evict`** (están *gated* a `park`), para que `evict` reproduzca el delta 1 byte a byte.

---

## Estado honesto (medido vs no medido)

**Medido:**

- Host-only: `conversation_spill_test` **169 checks** (era 102), exit 0; el resto sin cambios (`prompt_cache 112`, `file 188`, `cache 4191`, `memory 25`).
- Serie de **10 parches** con **paridad de árbol exacta** `e7506b42…` (aplicando `patches/*.patch` sobre `v0.1.40.1`).
- `verify-layer.ps1`: **11 anclas OK + 15 flags**, exit 0.
- **Producción (el binario de `:5011` es este delta 2):** 16 cierres de turno → `park mirror queued (... copy 113–643 ms); writes=0..15 collapsed=0 throttled=0`; `parked ... evictions=0` en los primeros parks (la copia llegó al disco **sin** expulsión); restauraciones reales `216.8 ms / 1032.4 ms / 1948.1 ms` para 33k–90k tokens; `disk_evictions=0`.

**NO medido todavía:**

- Colapso end-to-end con un turno de **5 tool-calls reales** (se prueba a nivel de módulo).
- Compactación con un **cliente que reescriba la cola en vivo**.
- Cancelación con un **Escape-Escape real** (se prueba el helper de reversión y la invariancia de la copia anterior).
- Costo por turno con el modelo real (bytes/ms) más allá de los `copy ms` del log.

**Compilado con CUDA 12.8** (toolkit 13 no instalado en la máquina de prueba). El código es agnóstico al toolkit; la propuesta de CUDA 13 está especificada y **no ejecutada**.

---

## Reconocimiento

Este delta **se apoya en trabajo de terceros ya absorbido** y lo extiende, no lo duplica:

- **[#1271](https://github.com/Niko1221/Strata/pull/1271)** de **ANBAL534** — el tier de disco entero (spill por evicción, session file + sidecar, reutilizando `conversation_file.cpp`). El delta 2 convierte ese overflow en espejo.
- **[#1269](https://github.com/Niko1221/Strata/pull/1269)** de **pspranger-throw** — la restauración de un session file sin sostener el K/V en RAM (dos pasadas), de la que se toma la lección de re-armar la residencia por capa (`kv_stream_reset` / `kv_ring_restore`).

Ambos commits van con el **autor original** y la URL del PR (`cherry-pick -x`).

---

*Preparado en conjunto por **szargarpour** y **deepseek flash** — y nada más —, 2026-10-07.*
