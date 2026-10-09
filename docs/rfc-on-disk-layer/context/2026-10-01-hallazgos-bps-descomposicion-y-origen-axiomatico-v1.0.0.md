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
  - Source: <local-path>/01-axiomatico/2026-10-01-hallazgos-bps-descomposicion-y-origen-axiomatico-v1.0.0.md
  - Source version: v1.0.0
  - Copied: 2026-10-09
-->

# Hallazgos: Axiomático — Aplicación de BPs, descomposición jerárquica, techo real y origen

> **Documento**: `2026-10-01-hallazgos-bps-descomposicion-y-origen-axiomatico-v1.0.0.md` · **Semver**: v1.0.0
> **Fecha**: 2026-10-01 · **Autor**: orquestador (slot 1) · **Rama**: `codex/pruebas`
> **Estado CDE**: `WIP` (hallazgos pre-corrida-manual; la corrida manual paso a paso sigue)
> **Veto**: BP-954 no-nerfing vigente — todos los fixes propuestos son VETO-safe (cambian evidencia/entrada, no la fórmula v3 ni el umbral 0.95).

---

## 1. Resumen ejecutivo

Se ordenaron las ideas sobre el estado del axiomático (v1.7.1) y se levantaron hallazgos
con evidencia en disco y en código. Conclusiones principales:

1. **Las BPs SÍ se usan** (como `especificas` + señales + `pool_via_global` 9–41 por plan),
   pero casi ninguna llega a ser **mandatoria** (0–1 por plan) porque la relevancia se
   calcula contra el **título del plan** (texto equivocado), no contra el contenido de
   cada sub-tarea.
2. **El techo no es el techo real**: el JSON C2 del plan trae `grafo_funciones.nodos`
   como **strings planos (solo IDs, sin descripción)**. El decomposer arma el objetivo de
   la wave como `"{id} — sub-tarea del plan: {título}"` → objetivos casi idénticos →
   scores idénticos (w2: 8×0.939) → el "techo" es el score del título, no de cada sub-tarea.
3. **Cobertura de embeddings: 100%** (404/404 vigentes, 1024 dims, cola vacía). No es el problema.
4. **Falso positivo de ISOs**: NO es el patrón. Es un **type mismatch** — `facet_classifier`
   pobla `isos_aplicables` como `list[dict]`, pero `source_validator._validate_iso` hace
   `str(dict)` → no matchea. Afecta a **dos** plugins (`source_validator` + `pre_research_scout`).
5. **Auto-cumplimiento**: el axiomático cumple BP-954 (fórmula inmutable) y BP-974
   (parametrización SSOT), pero **viola BP-947** en el hot path (research_executor manda el
   objetivo crudo de 300 chars) y aplica BP-948 solo parcialmente.
6. **BP de descomposición**: existen BPs relacionadas (HTN BP-780/779, spec-driven BP-963,
   wave planning BP-950/953, one-shot BP-847) pero **no hay una canónica única** para la
   descomposición jerárquica recursiva con aplicabilidad de BPs/ISOs por nivel.
7. **El axiomático original** (repo legacy `<local-path> Datos\...\0000 Conexión IA para planos`)
   era un **prompt one-shot a un LLM** (DeepSeek R1) que descomponía en sub-tareas atómicas
   con ISO/rol/dependencias/entregable/verificación/estimación. El diseño original ya era
   **híbrido**: LLM descompone + motor valida. Esto es lo que se rescata.

---

## 2. Lo hecho en los últimos 5 días (9 commits + sin commitear)

### Commiteado

| Fecha | Commit | Qué fue |
|---|---|---|
| 09-25 | `62769a6` | Gate Akasha — rediseño non-blocking + refuerzo de contexto (S459) |
| 09-25 | `10b648e` | SearXNG: engine Bright Data SERP API como fallback de serper |
| 09-28 | `b28c4d8` | **Axiomatico 1.5.0** — 1024 dims + familiaridad por vectores + 6 BPs design system |
| 09-29 | `74e9f3a` | **Axiomatico 1.6.0** — defectos A-G (vía global, tie resolver, brechas, docs_oficiales, router, plugins, discriminador) + batería 15 planes |
| 09-30 | `b259c3c` | Embeddings :8082 — canonicación de la unidad server-embedding (P2) |
| 09-30 | `5161ed5` | SearXNG: recalibración de timeouts + fix stackoverflow duplicado |
| 09-30 | `564d968` | SearXNG: presupuesto Google v2 paramétrico (P4) |
| 09-30 | `c726d0c` | SearXNG: enqueue_pending + meta para reintentos del drain (P5) |
| 09-30 | `39c4764` | **Axiomatico 1.7.0** — base paramétrica (db_policy + BP 974) + docs_oficiales P3 + research_executor P5 + waves AAA+ P6 |

### Sin commitear (1.7.1 + P8 + SearXNG + watchdog)

| Bloque | Archivos | Estado |
|---|---|---|
| Backfill sin tope | `config/axiomatico/backfill_policy.json` + asset, `source_backfiller_plugin.py`, `semantic_discoverer.py`, `bps_resolver_v3.py`, `source_validator_plugin.py`, tests (25), pyproject 1.7.1, CHANGELOG, README, informe | ✅ implementado, verificado (427/427), **pendiente commit** |
| P8 waves | `wave_decomposer.py`, `mcp_server.py` (tool `axiomatico_evaluate_waves`), `test_wave_decomposer.py` (28), `bateria_waves_v170.py`, informe + JSON batería | ✅ run final OK (6159s, exit 0), **pendiente commit** |
| SearXNG v2 | `serper.py` v2, `google_budget.py` v2, `search_budget.json` | ✅ en disco, **contenedor con código viejo → requiere restart** |
| Watchdog Obscura | `scripts/obscura-watchdog.ps1` + tarea programada `StudioZ_Obscura_Watchdog` | ✅ cableado (background + UAC), Obscura sano |

---

## 3. Lo solicitado

| # | Pedido | Estado |
|---|---|---|
| M | **Maestra:** implementar el axiomático hasta completar (versionado, commit, docs canónicos, instalador), luego usarlo con todos los planes pendientes, luego el taller hasta el flujo de imágenes | 🔄 en curso |
| 1 | Mostrar los scores nuevos antes de pasar al taller | ✅ |
| 2 | SearXNG: Google solo vía SerpAPI+BrightData; reparar git/reddit/otros; duck descartado; subir timeout, destilar queries, cambiar mezclas; tests | 🔄 pendiente |
| 3 | Cablear el watchdog Obscura | ✅ |
| 4 | Queries cortas (<100 chars), terminología estándar; el LLM principal formula las queries | 🔄 pendiente |
| 5 | Tabla clara hecho/solicitado/falta + garantizar aplicación de BPs | ✅ |
| 6 | BP de descomposición de tareas (¿ya la tenemos?) | ✅ (ver §8) |
| 7 | Informe en disco de todos los hallazgos | ✅ (este documento) |
| 8 | Revisar el repo original del axiomático (origen, funcionamiento, qué rescatar, rol del orquestador, asistente de descomposición) | ✅ (ver §9) |

---

## 4. Lo que falta (gaps G1–G6)

| Gap | Descripción | Causa raíz | VETO-safe |
|---|---|---|---|
| **G1 — Techo por wave** | El "techo" no es el techo real por sub-tarea. w2: 8 waves con score idéntico (0.939×8) y research idéntico (16 findings×8). TALLER: 20 waves con scores casi iguales (0.877–0.903). | El JSON C2 del plan trae `grafo_funciones.nodos` como **strings planos (solo IDs, sin descripción)**. El decomposer arma el objetivo como `"{id} — sub-tarea del plan: {título}"`. | ✅ |
| **G2 — BPs no mandatorias** | `bps_mandatorias` = 0–1 por plan; `mandatorias_pendientes` = 3–7 (todas `BP_MANDATORIA_RECHAZADA`, relevance 0.65–0.93) → pasan a `especificas`. | La relevance de la BP se calcula **contra el título del plan** (texto equivocado, por G1), no contra el contenido de la sub-tarea. El gate 0.95 (VETO) entonces rechaza. | ✅ (fix de G1 lo resuelve) |
| **G3 — Queries (BP-947)** | `research_executor` manda el objetivo crudo (truncado a 300 chars) → GitHub 422 (>256), timeouts SearXNG (8s corto), malos resultados. **Viola BP-947**. | El executor es determinista y no aplica BP-947. | ✅ |
| **G4 — SearXNG** | Google nativo activo (CAPTCHA 24h + 403s); `GRANIAN_BLOCKING_THREADS=4`; contenedor con código viejo. | settings.yml + compose.yml sin parchear; contenedor sin restart. | ✅ |
| **G5 — Falso positivo ISOs** | 22 "invalidos" en el run (bugsearch ×14, vass ×8). | **Type mismatch**: `isos_aplicables` es `list[dict]`, `_validate_iso` hace `str(dict)`. Afecta a `source_validator` + `pre_research_scout`. El patrón ISO/IEC/IEEE en sí está bien; solo faltan prefijos EN/IEC/ANSI. | ✅ |
| **G6 — Auto-cumplimiento** | El axiomático no aplica sus propias BPs en su operación (research executor determinista, no aplica BP-947/948). | Falta incorporar sus BPs en el hot path. | ✅ |

---

## 5. Las 5 garantías pedidas (análisis con evidencia)

| Garantía | Estado | Evidencia |
|---|---|---|
| **G1. Los planes aplican todas las BPs** | ⚠️ Parcial | Las BPs sí se usan (especificas + señales + pool 9–41 por plan). Como mandatorias solo 0–1 por plan. |
| **G2. Correctamente clasificadas** | ⚠️ Parcial | Gate mandatoria 0.95 (VETO) + relevance contra el título del plan (texto equivocado, por G1). |
| **G3. Accesibles por embedding** | ✅ **OK** | **404/404 vigentes (100%)**, 1024 dims, cola vacía. No es el problema. |
| **G4. Aplicadas a cada wave** | ⚠️ Parcial | En código sí (`run_pipeline` por wave), pero los objetivos no están diferenciados (G1) → todas resuelven las mismas BPs. |
| **G5. Techo real (no un techo falso)** | ❌ **No** | El techo = score del título del plan, no de cada sub-tarea (objetivos casi idénticos). |
| **G6. El axiomático cumple BPs en diseño y funcionamiento** | ⚠️ Parcial | BP-954 ✅, BP-974 ✅, **BP-947 ❌ en el hot path**. |
| **G7. Incorpora sus propias BPs en su operativa** | ⚠️ Parcial | 954/974 sí; **947/948 no** (research executor determinista). |

**Aclaración sobre "el axiomático no usa sus BPs":** no es exactamente cierto. Sí las usa
como referencias (especificas + señales + pool). Lo que pasa es que (a) casi ninguna se
convierte en mandatoria (gate 0.95 + relevance contra título equivocado), y (b) no aplica
sus propias BPs (947, 948) en su operación interna.

---

## 6. Causa raíz única

El **JSON C2 del plan** (la estructura machine-readable que consume el axiomático) **no
lleva descripciones por nodo**. Todo lo demás deriva de esto:

```
C2 JSON sin descripción por nodo
  → objetivos de wave casi idénticos (G1)
    → techo = score del título, no de la sub-tarea (G5)
    → relevance de BP contra el título (G2) → mandatorias 0-1
    → queries = objetivo crudo (G3) → viola BP-947
```

---

## 7. Aclaraciones de diseño (g1, g2, descripción por nodo, ISO, auto-cumplimiento)

### g1 — Aplicabilidad jerárquica de BPs

La aplicabilidad de BPs es **jerárquica y contextual**: una BP aplica al **nivel específico
de la sub-tarea**, no solo al plan. Regla:
- **No hace falta** incluir BPs no aplicables (excluirlas está bien).
- **No se puede** excluir BPs legítimamente aplicables.
- **Cada nivel** (plan → wave → tarea → sub-tarea → sub-sub-tarea) debe considerar las BPs
  aplicables **a ese nivel específico**.

Ejemplo (dominio axiomático):
```
dominio: axiomático
└─ subdominio: aplicación de BPs/ISOs/planeamiento
   └─ sub-sub: "ordenar la información" (colocar el plan en disco)
      → BP de gestión de archivos (ISO 15489/23081) aplica AQUÍ
   └─ sub-sub: "hacer prompts para búsquedas en internet"
      → BP de cómo se formulan queries (BP-947) aplica AQUÍ
```

### g2 — Relevancia/techo recursivo

El proceso de relevancia + techo (aplicado en P6 a plan→waves) **debe repetirse dentro de
las waves** para tareas y sub-tareas, **a la profundidad necesaria**. El **techo real** está
en la **hoja** (la sub-tarea más específica), donde aplican las BPs/ISOs específicas. El
score del plan es la agregación de todas las hojas.

### Descripción por nodo: cómo resuelve esto + cuánto interactúa el LLM principal

**La descripción por nodo es necesaria pero NO suficiente.** Resuelve plan→wave, pero no los
niveles más profundos. Se necesita la combinación de tres cosas:

1. **Descripción por nodo en el C2 JSON** (resuelve plan→wave):
   ```json
   "grafo_funciones": {
     "nodos": [
       {"id": "W2.1",
        "descripcion": "Normalizar estados de sesión Akasha: cerrada→closed (81), activa→active (8) + cerrar ~10 stale",
        "metodo": "script Python sobre akasha.db",
        "sub_tareas": [ ... ]}
     ]
   }
   ```
   El decomposer usa `nodo["descripcion"]` como objetivo → objetivos diferenciados →
   relevancia de BP contra el contenido real → mandatorias correctas → techo real por wave.

2. **Descomposición recursiva** (resuelve wave→tarea→sub-tarea): el decomposer descompone
   recursivamente; en cada nodo se resuelven las BPs/ISOs aplicables y se scorea (v3 inmutable).

3. **Interacción del LLM principal** (resuelve el contexto + las queries):

| Rol | Quién | Qué hace |
|---|---|---|
| **Orquestador jerárquico** | **LLM principal** (el que genera el plan) | (a) provee descripciones por nodo a cada nivel; (b) decide la profundidad; (c) formula las queries de research (BP-947); (d) itera nivel a nivel. |
| **Motor determinista** | **Axiomático** | (a) descompone según el C2 JSON; (b) resuelve BPs/ISOs aplicables a cada nodo; (c) scorea (v3 inmutable, VETO BP-954); (d) aplica techo/research con las queries del LLM principal; (e) agrega hacia arriba (gate AAA+ = todas las hojas > 0.95). |

**Hasta qué punto interactúa el LLM principal:** lo suficiente para **conducir la jerarquía**
(profundidad, descripciones, queries), pero **no** para hacer el scoring ni la resolución de
BPs (eso lo hace el axiomático de forma determinista y VETO-protected).

### Falso positivo de ISOs (causa raíz exacta + si se extiende)

**Causa raíz (verificada en el run real):** NO es el patrón. Es un **type mismatch**:
- `facet_classifier.py:89` pobla `isos_aplicables = catalog.isos_for_disciplina(disciplina)` → **`list[dict]`**.
- `source_validator_plugin._get_isos` devuelve esa `list[dict]` tal cual.
- `_validate_iso` hace `iso_str = str(iso_str).strip()` → `"{'iso': 'ISO/IEC 25010:2023', 'titulo': ...}"` → no matchea.

**Los 22 "invalidos" del run son TODOS dicts stringificados.** El patrón ISO/IEC/IEEE en sí
está bien (matchea `ISO 22111:2019`, `ISO/IEC 25010:2023`, `ISO/IEC/IEEE 12207`, etc.).

**Fix (dos partes):**
1. **Primario (type mismatch):** normalizar cada entrada a su código ISO (extraer la clave
   `iso` del dict, fallback `nombre`). Reusar el helper `brechas_categorias_plugin._iso_id()`.
2. **Secundario (amplitud del patrón):** aceptar prefijos `EN` (Eurocode), `IEC` puro,
   `ANSI/ISO` (estándares legítimos que aparecen en BPs).

**¿Se extiende a otros temas? SÍ.** El mismo type mismatch afecta a
`pre_research_scout_plugin.py:246` (`', '.join(str(i) for i in isos)` → el prompt de
research contiene dicts stringificados). Mismo bug, mismo fix. El patrón de BP ID ya fue
corregido antes (acepta id entero canónico + formato legacy); el de URL es estándar.

### Auto-cumplimiento

El axiomático debe **aplicar sus propias BPs en su operación** (auto-referencial):

| BP propia | Qué exige | Estado hoy | Fix |
|---|---|---|---|
| **BP-954** (VETO no-nerfing) | La fórmula v3 es inmutable | ✅ Cumple | — |
| **BP-974** (parametrización SSOT) | Config con SSOT, versionado, fail-open | ✅ Cumple | — |
| **BP-947** (extracción de concepto) | Queries con terminología estándar, cortas | ❌ **Viola en el hot path** | El LLM principal formula las queries → el axiomático las recibe ya conformes |
| **BP-948** (match de dominio) | Validar resultados por match de dominio | ⚠️ Parcial | Completar con la normalización de ISOs + validación de dominio |

---

## 8. BP de descomposición de tareas (¿ya la tenemos?)

**Sí existen BPs relacionadas, pero no hay una canónica única** para la descomposición
jerárquica recursiva con aplicabilidad de BPs/ISOs por nivel. Búsqueda en la BD canónica
(733 BPs, 404 vigentes): **80 BPs** matchean términos de descomposición. Las clave:

| BP | Título | Qué cubre |
|---|---|---|
| **BP-780/779** | `bp_goal_oriented_orchestration` (CORE_PATTERNS/INTENT) | **HTN** (Hierarchical Task Network): descomposición recursiva del macro-objetivo en sub-objetivos; cada sub-objetivo hereda las restricciones del padre. Fundamento teórico (SHOP2, PyHTN, LangGraph). |
| **BP-963** | Spec-Driven Development en pipelines multi-agente | La spec es la entrada; el task_tree se deriva ESTRICTAMENTE de la spec; verificación spec→task_tree (plan_validator C2). |
| **BP-950** | Planificación por waves con estados CDE | Estructura del documento de plan por waves (subwaves, criterios de aceptación, grafo de dependencias, gates, ISOs/BPs, protocolo de sesión). |
| **BP-953** | Plan de waves con grafo de dependencias explícito | Grafo de dependencias (nodos+aristas → camino crítico + orden de ejecución), gates numerados, sesión ejecutable. |
| **BP-847** | `bp_axiomatico_one_shot` | El axiomático es one-shot (no agente persistente); Shambe es el persistente. |
| **BP-817** | `bp_orchestrator_handoff_contract` | Contrato de handoff orquestador→worker. |
| **BP-845** | `bp_agent_dispatch_methods` | Dispatch one-shot vs persistente. |

**Por qué no la descubrí antes:** en el análisis previo me enfoqué en los gaps de
*aplicación* de BPs (gate mandatoria, relevancia, embeddings) y **no hice una búsqueda
dirigida** por una BP de *metodología de descomposición*. Fue un descuido. Al buscarla ahora
confirmo que existen BPs relacionadas pero **dispersas** (HTN teórico, spec-driven, wave
planning) y **ninguna las une** en la metodología jerárquica recursiva específica que se
necesita (plan→wave→tarea→sub-tarea, con BPs/ISOs aplicables por nivel + scoring v3 +
techo/research + rol del LLM principal).

**Recomendación:** crear una **BP canónica nueva** que codifique la descomposición
jerárquica recursiva, basada en HTN (BP-780/779) + spec-driven (BP-963) + wave planning
(BP-950/953), definiendo: (a) la descomposición recursiva a la profundidad necesaria;
(b) la resolución de BPs/ISOs aplicables a cada nivel (contra el objetivo específico de ese
nivel); (c) el scoring con la fórmula v3 inmutable (BP-954); (d) el techo/research con
queries BP-947 del LLM principal; (e) el rol del LLM principal (descripciones, queries,
profundidad) vs el motor determinista (scoring, resolución, techo). ISOs: ISO/IEC/IEEE
12207, ISO 21500, ISO/IEC 25010:2023.

---

## 9. El axiomático original (repo legacy)

**Repo**: `<local-path> Datos\documentos\2025 Arquitectura\0000 Conexión IA para planos`

### 9.1 Cómo nació

El axiomático nació como un **prompt one-shot a un LLM** (S299). El script
`run_axiomatic.py` invocaba `opencode run -m deepseek/deepseek-reasoner` con un prompt que
decía:

> "You are the axiomatic engine for a BIM + multi-agent AI project. Decompose the following
> user requirement into atomic sub-tasks, each with (a) ISO standard(s) applicable, (b) role
> assigned (investigador Gemini / mantenedor GLM-4.7 / inspector Sonnet / reasoner R1 /
> axiomatic), (c) dependencies, (d) deliverable path, (e) 1-line verification criterion.
> OUTPUT: JSON array of sub-tasks with fields [id, title, iso, role, depends_on, deliverable,
> verify]. Plus a totals line: critical_path, total_subtasks."

### 9.2 Cómo trabajaba

El LLM (DeepSeek R1) hacía **toda la descomposición** de forma one-shot. La salida real
(`decomposition_output.json`) era un JSON array de sub-tareas, cada una con:

| Campo | Ejemplo (M1) |
|---|---|
| `id` | M1 |
| `title` | "Modify CLAUDE.md to reference SQLite skill_modelo table..." |
| `iso` | ISO/IEC 12207 |
| `role` | mantenedor GLM-4.7 |
| `dep` | [] (o ["M1"]) |
| `deliverable` | "CLAUDE.md with references to skill_modelo table..." |
| `verify` | "Grep of CLAUDE.md shows zero inline model IDs..." |
| `est_minutes` | 30 |

La descomposición tenía **10 sub-tareas** (M1–M7, D1–D2, V1) con un **grafo de
dependencias** (M2→M1, M3→D1, D2→M3, M4→D2, V1→[M4,M5,M6,M7]) y un **camino crítico**.

### 9.3 El rol del orquestador

El orquestador (gpt-5.4, según `agent-topology.md`) **coordinaba**: tomaba decisiones,
hacía arquitectura y supervisión. **Invocaba el axiomático como subprocess one-shot**,
recibía el JSON de descomposición, y usaba ese JSON para **despachar sub-agentes** por rol
(mantenedor GLM-4.7, reasoner R1, inspector Sonnet). El orquestador NO hacía la
descomposición (esa era del LLM axiomático); la **consumía** para orquestar.

### 9.4 La política de routing de modelos por capacidad

`model-routing.json` (policy 2026-04-03) asignaba modelos por tipo de tarea:

| task_type | modelo | reasoning |
|---|---|---|
| default | gpt-5.4 | medium |
| architecture | gpt-5.4 | high |
| integration | gpt-5.4 | high |
| implementation | gpt-5.3-codex | medium |
| implementation_high_risk | gpt-5.3-codex | high |
| cataloging | gpt-5.4-mini | low |
| quick_context | gpt-5.4-mini | low |

Esto es la doctrina **modelo-por-capacidad**: el modelo se elige por la capacidad que
requiere la tarea, no por convención.

### 9.5 Qué se rescata

1. **El schema de descomposición**: `[id, title, iso, role, dep, deliverable, verify, est_minutes]` —
   es exactamente el schema que el C2 JSON debería llevar por nodo (hoy solo tiene `id`).
2. **La descomposición por LLM**: el LLM (no un parser determinista) es el que descompone y
   asigna ISO/rol/dependencias/entregable/verificación a cada sub-tarea. Esto resuelve el
   gap G1 (objetivos no diferenciados) porque el LLM escribe la descripción de cada nodo.
3. **El rol por sub-tarea**: cada sub-tarea tiene un rol (investigador/mantenedor/inspector/
   reasoner/axiomático) → asignación de modelo por capacidad.
4. **El grafo de dependencias + camino crítico**: ya existía en el diseño original.
5. **El diseño híbrido**: LLM descompone + motor valida. El axiomático actual (pipeline
   determinista) es la capa de validación/scoring; el LLM es la capa de descomposición.

### 9.6 El asistente de descomposición por pasos

El diseño original **YA tenía** un asistente de descomposición: el LLM (DeepSeek R1)
invocado one-shot. La pregunta del usuario ("en qué medida podemos tener un asistente que
pueda ser un modelo de descomposición por pasos") se responde: **sí, y ya existía**. Lo que
cambió es que el axiomático evolucionó de un LLM one-shot a un pipeline determinista
(packages/axiomatico), perdiendo la capa de descomposición por LLM. El fix es **recuperar
la capa de descomposición por LLM** (el LLM principal) y combinarla con el pipeline
determinista (scoring v3 + resolución de BPs/ISOs + techo/research).

---

## 10. Fixes propuestos + diseño híbrido

### Diseño híbrido (LLM descomposición + motor determinista)

```
LLM principal (descomposición por pasos, como el axiomático original):
  1. Recibe el requerimiento.
  2. Descompone recursivamente: plan → wave → tarea → sub-tarea → sub-sub-tarea.
  3. A CADA nodo le asigna: descripcion, iso(s), rol, dep, deliverable, verify, est_minutes.
  4. Produce el C2 JSON con descripciones por nodo (el schema del axiomático original).
  5. Formula las queries de research (BP-947) cuando un nodo toca techo.

Axiomático (motor determinista, pipeline v3 inmutable):
  1. Recibe el C2 JSON con descripciones por nodo.
  2. Descompone según el C2 JSON (recursivo, a la profundidad que el LLM definió).
  3. A CADA nodo: resuelve BPs/ISOs aplicables (contra el objetivo específico de ese nodo).
  4. A CADA nodo: scorea con la fórmula v3 inmutable (VETO BP-954).
  5. A CADA nodo que toca techo: research con las queries del LLM principal + re-score.
  6. Valida fuentes (fix type mismatch ISOs + amplitud EN/IEC/ANSI).
  7. Agrega hacia arriba: score del plan = agregación de hojas; gate AAA+ = todas > 0.95.
  8. Auto-cumplimiento: aplica sus propias BPs (947, 948) en su operación.
```

### Orden de fixes (VETO-safe)

| Paso | Qué | Gaps que resuelve |
|---|---|---|
| **1** | Fix **type mismatch ISOs** (normalizar dicts→código en `source_validator` + `pre_research_scout`, reusar `_iso_id`) + ampliar patrón EN/IEC/ANSI | G5 |
| **2** | Fix **C2 JSON + decomposer**: descripciones por nodo + descomposición recursiva + relevancia BP/ISO por nodo | G1, G2, G5 (techo) |
| **3** | Fix **queries (LLM principal, BP-947)** + **SearXNG** (settings/compose/executor/restart/tests) | G3, G4 |
| **4** | **Auto-cumplimiento**: el axiomático resuelve y aplica sus propias BPs (947, 948) | G6 |
| **5** | **BP canónica de descomposición jerárquica recursiva** (nueva, basada en HTN+spec-driven+wave planning) | Documenta la metodología |
| **6** | **Re-run de la batería** (w2, TALLER, vass, watchdog, items13, g1-wsg) para verificar la mejora | Evidencia |
| **7** | **Commit** P8 + backfill (1.7.1) + SearXNG + watchdog + fixes | Cierre versionado |

---

## 11. Corrida manual (pendiente)

La corrida manual paso a paso (de todo lo que el axiomático debe lograr, determinando gaps
por paso, documentándolos y resolviéndolos) sigue pendiente. Se hará con el plan W2 como
ejemplo, trazando el pipeline completo (input → descomposición recursiva → resolución de
BPs/ISOs por nivel → scoring v3 → techo/research → validación de fuentes → agregación →
auto-cumplimiento → output) y documentando cada gap.

---

## Anexo: Evidencia en disco

- Batería v1.7.0 (run final): `02-informes/.../09-implementacion/bateria-waves-2026-09-30-v1.7.0.json`
- Dumps por plan: `_tmp/bateria-waves-v170/` (bateria-*.json, waves-*.json, db_state.json)
- C2 JSON del plan W2 (nodos strings planos): `02-informes/.../10-plan-waves/W2-plan-v1.0.0.md` (sección "Plan estructurado (GATE C2")
- Axiomático original: `<local-path> Datos\...\0000 Conexión IA para planos\run_axiomatic.py`, `decomposition_output.json`
- Orquestación legacy: `<local-path> Datos\...\0000 Conexión IA para planos\000 000 INFORMES\arqueologia-codex\master codex\orquestacion\` (agent-topology.md, model-routing.json)
- LOG del axiomático (E1, 2026-08-15): `02-informes/.../01-axiomatico/LOG.md`
- Task-tree fundacional: `02-informes/.../01-axiomatico/2026-08-15-2008-axiomatico-task-tree-v1.0.0.md`