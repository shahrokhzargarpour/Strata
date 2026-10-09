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
  - Source: <local-path>/09-implementacion/2026-10-09-t1-onda-e-evidencia-viva-v1.0.0.md
  - Source version: v1.0.0
  - Copied: 2026-10-09
  - This is the live-serving evidence behind PR #1331.
-->

# T1 ONDA E - Evidencia en vivo reemplaza la no-afirmacion central (delta2 sobre v0.1.41)

- **Fecha:** 2026-10-09. **Onda:** E (docs sobre la bateria en vivo del puerto 5012).
- **Alcance:** solo `.md` en `<local-path>` (rama `layer/t1-041`). Cero push. No se
  toco `:5011` ni `<local-path>`. Worktree limpio al cerrar.
- **Head anterior:** `da2b59e`. **Head nuevo:** `6b338fa` (`6b338faad6079510736ab9a7c7109c2259e09347`).
- **Input:** los dos logs pedidos (45 lineas cada uno) y el doc ya editado en la onda D-R. No se abrio ningun
  informe de recon.

## 1. Verificado en disco (comando + resultado)

| # | Comando | Resultado |
|---|---|---|
| E1 | `read bench-20261009-051623.log` (corrida 1, harness v1.0.0) | ready **156.6 s**; `/props build_info='Strata 0.1.41' n_ctx=196608`; modelo `qwen3.8-flash-next-unsloth-ud-iq4_xs`. Test 2 throughput: mediana TTFT 10.71 s, `tok/s=None` -> **throughput FAIL**, **OVERALL: FAIL**. Test 3: call 1 TTFT **30.296 s** (`reused 0/7925`, `sysprompt hits=0`) -> call 2 TTFT 2.238 s (`reused 7904/7923`, `tokens_saved=0`), "(baja 92.6 %)". Test 4: B1 **29.76 s**, B2 **30.10 s** (`prompt_tokens=8016`); contadores `disk: enabled=True conversations=0 spills=2 bytes=1430257664 restores=0 \| sysprompt: enabled=True variants=3 hits=0 misses=2 bytes=719323136` |
| E2 | `read bench-20261009-061613.log` (corrida 2, harness v1.1.0) | ready **156.6 s**; mismo `build_info`/`n_ctx`/modelo. Test 2 (sin `max_tokens`, stop natural): **472/480/458** tokens `finish=stop`; TTFT mediana **0.452 s** (min 0.431 / max 3.618); **28.11 tok/s** decode, 27.39 e2e -> PASS. Test 3: TTFT **1.096 s** -> **1.52 s** ("baja -38.7 %"), `reused 7920/7925` y `7918/7923`, `tokens_saved=0`. Test 4: B1 **1.98 s**, B2 **1.98 s**; `disk: enabled=True conversations=0 spills=2 bytes=2153775104 restores=4 \| sysprompt: enabled=True variants=3 hits=1 misses=0 bytes=719323136`; spill 19 archivos / 2.154.484.304 bytes; **OVERALL: PASS** |
| E3 | `Get-FileHash build-cuda\strata.exe` (worktree de la capa) | `C1D54A4F5A405F076A0D5F1EB0384DECB5A5E422C3A109A7AD6CD7B86A26FB99` - **coincide** con el sha ya citado en el doc (mtime 2026-10-08T23:23:31) |
| E4 | `Select-String bench-t1-5012 -Pattern "C1D54A4F\|sha256"` | `README.md:9` del propio harness registra ese sha256 (verificado 2026-10-09) para `...\strata-t1-041\build-cuda\strata.exe`, base `fb58e0d` = v0.1.41 + PR #1331, puerto 5012 ("el de produccion, 5011, no se toca en ningun paso"). **El vinculo sha <-> corrida viva esta registrado fuera del log: el log solo consigna `build_info`** |
| E5 | `Select-String bench-t1-5012\results\*.stdout.log -Pattern "sha\|\.exe\|build_info"` | 0 coincidencias: los stdout del server no nombran el binario (por eso E4 busca en el README del harness) |
| E6 | `Select-String docs\*.md,README.md -Pattern "live run\|not tested live\|no measurement yet\|not been read from"` | 5 puntos con no-afirmaciones vivas: `FLAGS.md:115`, `SPILL:184`, `SPILL:197-200`, `SPILL:223`, `SPILL:245`. Los cinco se reescribieron |
| E7 | `git diff --name-only da2b59e..HEAD` | solo `docs/FLAGS.md` y `docs/SPILL_AND_PROMPT_CACHE.md` (cero codigo) |
| E8 | largo de lineas anadidas (`git diff -U0`, lineas `+`) | 53 lineas anadidas, maximo **115** caracteres, **0** por encima de 120. Las 4 lineas >120 del doc (51, 246-248) son preexistentes: prosa y filas de tabla de "Sizes by KV type" |
| E9 | `Select-String "Known limitation: the divergence discard"` | **1** coincidencia: la bala de la onda D-R sigue intacta, sin tocar |

## 2. Que afirma ahora el doc (y que retiro)

`docs/SPILL_AND_PROMPT_CACHE.md`:

1. **"Validation environment"**: la frase final `None of that is a live run - see the first non-claim below.`
   desaparece y entra una bala **"A live run against this base exists now"**: el mismo `strata.exe` (sha256
   completo, con la aclaracion de que **el log registra `build_info`, no el digest** - el digest lo registra el
   harness que lo levanto), sirviendo `127.0.0.1:5012` sobre un clon de la configuracion de produccion,
   `/props build_info='Strata 0.1.41'` + `n_ctx=196608`, listo en 156.6 s en ambas corridas, dos corridas con
   reinicio en el medio, y **ambos `OVERALL` consignados**: `FAIL` la primera (por el chequeo de throughput del
   harness v1.0.0 con `max_tokens=256`, no por la capa) y `PASS` la segunda. Se aclara que los logs viven con el
   harness, no en el repo.
2. **"Measured benefit"**: el parrafo `There is no measurement yet of the disk tier or the system-prompt cache
   with the model loaded` se **reemplaza** por `This layer, end to end (live, the first two runs)` con tres balas
   (frio-vs-restaurado, contadores que se movieron, y que sirve el mismo binario) y un parrafo
   `What those numbers are not`.
3. **"Non-claims"**: la bala `Not tested live against v0.1.41` se **retira explicitamente** ("is **withdrawn**")
   y la reemplaza `The live run is a functional pass, not a benchmark`. La bala final
   `There is no end-to-end measurement yet` pasa a `The end-to-end numbers are two runs, not a profile`.

`docs/FLAGS.md`: la linea de cierre de la seccion E decia `what has not (any live run)`; ahora dice que existe una
corrida viva de los cuatro escenarios con la capa encendida, y que sigue sin estar medido **con la capa apagada** y
ninguna de las flags que la bateria no toco (`--head-device`, layer split, `--batch-mtp`, cancelacion, palancas de
GC, compactacion).

## 3. Guardas de honestidad aplicadas (verificadas contra el log, no contra el encargo)

| Guarda | Como quedo |
|---|---|
| No es capa vs sin capa | Texto: "Both runs used the same binary with the layer **on**, so what is measured is **cold prefill against a restore from disk after a restart** - nothing more. It is not a comparison against upstream, not a speedup ratio for the layer, and not a throughput claim about it." |
| Muestras de a una | "`restores=4` and `hits=1` are **one run each**: a working signal, not a rate." |
| `conversations=0` | "The `conversations=0` on that same counter line is what the engine reports and **is not interpreted here**." No se usa como evidencia de nada. |
| Ruido del test de system prompt | Se nombran los dos numeros y se desactivan: el 1.096 s -> 1.52 s de la corrida 2 es "one sample of a warm prefix, not a regression"; y el **-92.6 %** de la corrida 1 se atribuye a **reutilizacion de KV en prefill frio** (ese log lee `sysprompt hits=0`), no a la cache de system prompt en disco. |
| Compactacion sin bench | Sigue declarada. En la bala de non-claims entra en la lista de lo que la bateria **no** toco, con la razon: "when a rewrite happens is the harness's decision, and this delivery carries no archive tier". |
| Limitacion de divergencia | Intacta (E9). La bateria no toca esa ruta; no se modifico ni una palabra de esa bala. |
| Inercia con flags off | Sigue sin afirmar: "That the layer is **inert with the flags off under load** is likewise still unshown: both runs had it on." |

## 4. Commit, diff y N17

- **Commit:** `6b338fa` - `docs: the live run replaces the "never tested live" non-claim`, con cuerpo en el estilo
  de la serie (linea `Documentation only - no behaviour, no code.`, balas por seccion y cierre que reafirma la
  limitacion de divergencia). 2 archivos, +55/-18.
- **`git diff --stat fb58e0d..HEAD`:** `34 files changed, 5823 insertions(+), 181 deletions(-)`
  (en `da2b59e` era +5786/-181; el mismo conjunto de 34 archivos, sin archivos nuevos).
- **N17:** 34 archivos en el diff; filtro `upstream\.lock|FROZEN|patches/|\.ps1|bench/` -> **0 coincidencias**.
  `git rev-list --left-right --count fb58e0d...HEAD` -> **0 detras / 17 adelante**. **N17: PASA.**
- **Formato:** 53 lineas anadidas, maximo 115 caracteres, 0 por encima del wrap del doc; encabezados precedidos de
  linea en blanco; anclas internas `#validation-environment`, `#measured-benefit`, `#non-claims` resuelven contra
  encabezados existentes.
- **Worktree:** `git status --porcelain` vacio. Cero push.

## 5. Cuerpo del PR actualizado (template literal - NO publicado)

Mismos 4 encabezados literales verificados en `.github/pull_request_template.md` (onda D-R, V2/V3). Cambian
`## Summary` (una linea), `## What changed` (la bala de docs) y `## Extra Notes` (evidencia dividida en estatica y
viva, no-afirmaciones reescritas). `### Known limitation`, `### Collaboration` y `### Credits` quedan intactos.

```markdown
## Title
On-disk conversations and the system prompt: spill tier, prefill cache, layer-split plumbing - tested against `v0.1.41`

Issue: Resolves # 

## Summary
An opt-in **on-disk layer** for long conversations: a disk tier that parks a conversation's K/V image when the
RAM cache fills and restores it on a later request, a **system-prompt prefill cache**, both working across a
**layer split**, plus `--head-device` card placement and acceptance reporting for `--batch-mtp`.

This is the same on-disk layer as the previous version of this PR, **rebased and re-verified against upstream
`v0.1.41` (`fb58e0d`)** - and, since that version, **run live against it**. Every statement below is about that
base.

## What changed
- **The whole series is rebased onto `v0.1.41`** - 17 commits, original authorship preserved, including the
  #1271/#1269 cherry-picks.
- **The `make_room` conflict is resolved semantically, not textually**: the spill hook now lives in
  `evict_oldest()`, which gained a `template<class Spill>` overload. The zero-argument overload stays, so **with
  the layer's flags off the code is upstream's byte for byte**, and the hook sees the real eviction victim (which
  can be evicted from the middle of the deque) instead of a fixed `entries_.front()`.
- **The `put()` re-reservation hole is closed**: `put()` re-reserves with the real post-capture `image.bytes()`,
  which typically exceeds the estimate `make_room()` balanced against - so eviction at `put()` is the **normal**
  path of a large insert, not an edge case. `put()` gained a spill-callback overload and the park path propagates
  it. (`drop_superseded()` is deliberately left without a hook, and documented as considered-and-declined.)
- **Docs**: `docs/FLAGS.md` (every flag, its scope, its non-claim, and a section on the upstream mechanisms this
  layer lives beside without fusing with - `pin=N`, `--peer-device`, `STRATA_KV_GROW_HOLD`),
  `docs/SPILL_AND_PROMPT_CACHE.md` (how it works, its limits, what was verified and what was not, now including
  the live run), a README section, and the host-only tests for the pure classes.
- **One known limitation ships declared rather than fixed** - the divergence-discard path can name a sibling
  conversation's copy under a chat template that puts few-shot turns inside the system prompt. It is stated in
  `docs/SPILL_AND_PROMPT_CACHE.md` and in Extra Notes below; the fix is the next stacked PR on this branch.

## Extra Notes
### Evidence - static, against `v0.1.41`
CUDA build exit 0 - the `strata.exe` verified here is sha256
`C1D54A4F5A405F076A0D5F1EB0384DECB5A5E422C3A109A7AD6CD7B86A26FB99`; its `--help` lists all 17 flags of the layer;
an unknown flag is fatal (`unknown argument`, exit 2); the host-only test battery passes **12/12** (`ctest` exit
0); the layer's anchor/flag verifier (39 anchors, 17 flags) exits 0.

### Evidence - live, against `v0.1.41`
That same binary served `127.0.0.1:5012` on the verification machine on a clone of the production serve config
(production stays on 5011 and was not touched) and reported `/props` `build_info='Strata 0.1.41'`,
`n_ctx=196608`, model `qwen3.8-flash-next-unsloth-ud-iq4_xs`, ready in **156.6 s** in both runs. A four-test
battery (smoke, streamed throughput, repeated system prompt, two conversations that spill) ran **twice**, with a
server restart between runs and the tier's folders left in place. The second run passed all four tests
(`OVERALL: PASS`); the first reported `OVERALL: FAIL` for one reason only - its harness (v1.0.0) could not compute
a throughput figure at `max_tokens=256`.

- **Cold prefill against a restore after a restart.** Two ~8k-token conversations (`prompt_tokens=8016`) took
  **29.76 s** and **30.10 s** in the first run (a fresh process, nothing on disk for them) and **1.98 s** each in
  the second (a new process, both already on disk), with the engine counting `restores=4` in that second run
  against `restores=0` in the first. The 33,409-character system-prompt test has the same shape: **30.296 s** for
  its first call in the first run (nothing reused) against **2.298 s** for the same call in the second.
- **The tier's counters, read from the running engine:** `disk: enabled=True spills=2 bytes=2153775104
  restores=4` over a folder of 19 files / 2,154,484,304 bytes, and `sysprompt: enabled=True variants=3 hits=1
  misses=0 bytes=719323136`.
- **What the build serves** (a property of the build, not of the layer): with no output cap and a natural stop,
  three reps produced 472 / 480 / 458 tokens (`finish=stop`) at a median TTFT of **0.452 s**, at **28.11 tok/s**
  decoding (27.39 tok/s end to end).

**What the live numbers are not.** Both runs used the same binary with the layer **on**, so what is measured is
**cold prefill against a restore from disk after a process restart** - nothing more. It is not a comparison
against upstream, not a speedup ratio for the layer, and not a throughput claim about it. `restores=4` and `hits=1`
are **one run each**: a working signal, not a rate. The `conversations=0` on that same counter line is what the
engine reports and is not interpreted here. The system-prompt test of the second run (TTFT 1.096 s then 1.52 s,
with `reused=7920/7925` already warm) is one sample of a warm prefix, not a regression - and the **-92.6 %** of
the first run is a cold-prefill KV-reuse figure (that run read `sysprompt hits=0`), so it is not a property of the
system-prompt cache either.

### What this PR does not claim
The previous version of this PR said "not tested live against `v0.1.41`". That non-claim is **withdrawn** - the
runs above happened. What is still not claimed:

- **No layer-versus-no-layer run.** Both live runs had the layer on, so nothing here is a measured speedup over
  upstream, and no performance number anywhere in the diff is one.
- **Two runs of one harness on one machine.** One `restores=4`, one `hits=1`, one median TTFT, one conversation
  length. Both runs read `tokens_saved=0`, so there is no hit rate and no tokens-saved total.
- **Not every flag was reached.** The battery did not exercise `--head-device` card order, a layer split,
  `--batch-mtp`, a cancelled request, the GC's age and budget levers, or the compaction path (when a rewrite
  happens is the harness's decision, and this delivery carries no archive tier). That the layer is inert with the
  flags off under load is likewise still unshown.
- The host-only tests cover the pure classes (cache, spill, file, prompt cache, stage plan); the live battery
  covers the `--serve` loop for those four scenarios and nothing beyond them.

### Known limitation: the divergence discard can name a sibling's copy
(sin cambios respecto del borrador de la onda D-R: mecanica, consecuencia en esta version, fix en la rama hermana
como PR apilada siguiente, y la aclaracion de que el test rojo/verde se escribio sobre `v0.1.40.1`, no sobre
`v0.1.41`. La bateria en vivo no toca esa ruta, asi que no cambia nada de ese texto.)

### Collaboration
(sin cambios: solapamiento con **#1529**, colaboracion con **konijiwa110/Strata#1**, y el limite de "no verifique
el contenido de ninguno de los dos mas alla de sus threads".)

### Credits
(sin cambios: autoria y direccion de **Shahrokh Zargarpour**; trabajo realizado con el agente **Grok TUI Build**,
primero sobre **DeepSeek Flash** y actualmente sobre **Qwen3.8 flash-next UD iq4_xs**, el runtime de inferencia
local sobre el que se desarrollo y verifico la capa.)
```

## 6. Veredicto

**ONDA E PASA.** Head nuevo `6b338fa`. La no-afirmacion central ("nunca corrido en vivo") se retira y se reemplaza
por evidencia viva con sus guardas; N17 en verde (34 archivos, 0 coincidencias de tooling, 0 detras / 17 adelante);
diff `+5823/-181`; solo `.md`; worktree limpio; cero push.

