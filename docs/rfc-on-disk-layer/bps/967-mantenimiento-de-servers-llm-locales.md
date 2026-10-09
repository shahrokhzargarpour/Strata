<!--
INTERNAL BEST PRACTICE — provenance note

This is an internal best practice (BP) of StudioZ, the project that produced
the on-disk conversation-cache layer on this branch. It is NOT a rule of the
destination repository and nothing here binds its maintainers.

It is published because it explains WHY the layer is shaped the way it is
(pinned base tag, pattern anchors, a verifier that fails loudly, delivery as a
proposal rather than a merge). Where it conflicts with the destination's own
conventions, the destination's conventions win.

  - Written in Spanish (working language of the producing project).
  - Local absolute paths were replaced with `<local-path>` before publishing.
  - Source: internal best-practice database, record BP#967, maturity `aprobado`
  - ISO references as declared by the record: ISO/IEC/IEEE 12207:2017; ISO/IEC 25010:2023; ISO/IEC 20000-1:2018; ISO 10007:2017
  - Copied: 2026-10-09
-->

# BP 967 — Mantenimiento operacional de servers LLM locales (asistentes): watchdog + lazy start + monitor + config controlada (ISO 12207/25010/20000-1/10007)

# Mantenimiento operacional de servers LLM locales (asistentes)

## Cuando aplica
- Configurar watchdog y lazy start para el server de un asistente (puerto, health, relanz con la misma config).
- Actualizar el launcher de un asistente: MTP, proyector, cuantizacion, cap de hilos.
- Crear o revisar el monitor de health de un server (ventanas, slots, alerta C5).
- Migrar un runtime flotante (scripts/runtime) a unidad canonica con config versionada.
- Decidir autostart vs on-demand de un asistente (lifecycle en runtime.json).

## Regla normativa
Los servers de inferencia LLM locales (asistentes en <local-path>) se mantienen disponibles y correctos con el patron **watchdog determinista + lazy start + monitor de ventanas + configuracion como item de configuracion versionado**. El watchdog SOLO relanza con la MISMA configuracion canonica (nunca cambia modelo/cuantizacion/parametros); cualquier cambio de configuracion es un cambio de version controlado (ISO 10007). La calidad del servicio se mide contra el modelo de calidad ISO/IEC 25010 (fiabilidad: madurez, tolerancia a fallos, recuperabilidad; mantenibilidad).

Aplica a: servers llama.cpp/tabbyAPI de asistentes (9b :18999, 4b :19004, e2b :19005, g9v3 :8998, ldr :8085, bonsai :8081, flash-next :5001, embedding :8082).
NO aplica a: :5000 tabbyAPI principal (fuera de alcance C2, lo gobierna protector5000), MCPBus/daemons/DLQ (BP#393 + skill mantenedor-sistema).

## Reglas operativas (spec usuario 2026-09-27)

### R1. Watchdog por server
- Tarea programada Windows (AtLogOn, elevada) por server: poll de health cada N segundos (default 15s).
- 3 fallos consecutivos -> matar el proceso del puerto + relanzar con los parametros ESTANDAR desde la config canonica de la unidad (NUNCA con parametros ad-hoc).
- Single-instance: lock de archivo + mutex con nombre (evita watchdogs duplicados).
- Log append-only (watchdog.log de la unidad): timestamp, evento (ok/fallo/relanz), PID.
- El watchdog NO diagnostica ni cambia configuracion: detecta y relanza lo mismo. El diagnostico es del monitor (R3) y del humano.

### R2. Lazy start
- Los asistentes arrancan bajo demanda (primera peticion del orquestador/hook), NO al boot — salvo dependencias criticas (embedding :8082 para Akasha, que SI arranca con el watchdog AtLogOn).
- Declarado en runtime.json de la unidad: lifecycle: "on-demand" vs "autostart".
- El lazy start reduce RAM/VRAM en reposo y evita competir por CPU con otras sesiones (restriccion ComfyUI).

### R3. Monitor de ventanas
- Verificacion periodica por server: health URL + /v1/models + slots esperados + (opcional) ping de inferencia minimo.
- Fallo sostenido (>=2 ventanas) -> alerta C5 (canal de decision), NO auto-reparacion silenciosa.
- El monitor emite reporte JSON determinista (health score por server) consumible por el skill mantenedor-sistema.

### R4. MTP / proyector (config declarada)
- La configuracion de MTP (multi-token prediction) y mmproj (proyector de vision) es parte de la config canonica de la unidad — declarada en el launcher/config de la unidad, NO en comandos ad-hoc.
- Cambio de MTP/proyector = cambio de version (R7).

### R5. Regla Q8+
- Los asistentes corren con cuantizacion Q8_0 o superior (piso de calidad).
- Excepciones solo con registro justificado (patron C4 del fleet manager: excepcion_q8 en config, eval local manual, nunca swap automatico).

### R6. Cap de 8 hilos CPU
- Inferencia CPU limitada a 8 hilos (leccion S405: oversubscription OpenBLAS — los threads OMP del BLAS + los -t de llama se disputan y colapsan el throughput).
- Prefill concurrencia limitada en el binario (v2: --max-concurrent-prefills 2; >2 jobs de prefill grande satura los 8 hilos y bloquea todos los slots, verificado 2026-09-05).

### R7. Asistentes, no runtimes (unidad canonica)
- Cada asistente es una UNIDAD canonica (monorepo git propio en <local-path><nombre>-<puerto>\) con: README (mermaid de interconexiones), versionado semantico, installer (tarea programada + registro), tests, config canonica (runtime.json), entry en registry.json raiz.
- El repo raiz de asistentes trackea SOLO el indice (registry.json + README + install-all); cada unidad es git propio (no submodules).
- Prohibido: procesos de inferencia "flotantes" sin unidad canonica (sin config versionada, sin health, sin watchdog).

### R8. Links de escritorio
- Cada unidad expone un link de escritorio (launcher .ps1/.cmd) para operacion manual: arrancar, parar, health, log.
- El link de escritorio invoca el MISMO launcher que el watchdog (una sola fuente de verdad de parametros).

## Fundamento normativo (evidencia verbatim, 2026-09-27)
- ISO/IEC/IEEE 12207:2017 (VERIFIED): Scope 1.1 verbatim: "This document establishes a common framework for software life cycle processes, with well-defined terminology, that can be referenced by the software industry. It contains processes, activities, and tasks that are applicable during the acquisition, supply, development, operation, maintenance or disposal of software systems, products, and services." + TOC: "6.4.12 Operation process", "6.4.13 Maintenance process". => El mantenimiento de servers es un proceso de ciclo de vida de primera clase, no actividad ad-hoc.
- ISO/IEC 25010:2023 (PARTIAL): Scope verbatim: "This document defines a product quality model, which is applicable to ICT (information and communication technology) products and software products. The product quality model is composed of nine characteristics (which are further subdivided into subcharacteristics) that relate to quality properties of the products." + Foreword verbatim: "Usability and portability have been replaced with interaction capability and flexibility respectively." => La calidad del server (fiabilidad: madurez/tolerancia/recuperabilidad; mantenibilidad) se evalua contra el modelo de 9 caracteristicas. (La lista completa de caracteristicas, clausula 4, esta fuera del preview oficial.)
- ISO/IEC 20000-1:2018 (VERIFIED): Scope 1.1 verbatim: "This document specifies requirements for an organization to establish, implement, maintain and continually improve a service management system (SMS). The requirements specified in this document include the planning, design, transition, delivery and improvement of services to meet the service requirements and deliver value." + TOC: "8.6.1 Incident management", "8.6.3 Problem management", "8.7.1 Service availability management", "8.7.2 Service continuity management". => El watchdog es el mecanismo de disponibilidad (8.7.1), el monitor de ventanas es el detector de incidentes (8.6.1), y la regla "relanzar lo mismo" preserva continuidad (8.7.2).
- ISO 10007:2017 (VERIFIED): Introduction verbatim: "This document outlines the responsibilities and authorities before describing the configuration management process that includes configuration management planning, configuration identification, change control, configuration status accounting and configuration audit." => La config del launcher (MTP/proyector/cuantizacion/hilos) es un item de configuracion: identificada (R7), con control de cambios (R4/R5), estado (registry.json) y auditoria (git).

Etiqueta de fuente: contenido = documento oficial ISO en preview gratuito (standards.iteh.ai); iso.org bloqueado por Cloudflare managed challenge en este entorno (curl 403, headless sin resolver). Informe DR: 02-informes/auditoria-sistema-2026-08-15/08-investigaciones/2026-09-27-ldr-mantenimiento-servers-iso-v1.0.0.md (seccion 8).

## Relaciones con otras BPs
- BP#393 (bp_mantenimiento_sistema, dim14): infraestructura multi-agente (MCPBus/daemons/DLQ) — COMPLEMENTARIA (esta BP = servers de inferencia).
- BP#389 (bp_recableado_safe_refactor, dim14): refactoring seguro — aplica a la migracion de launchers scripts/runtime -> unidades canonicas.
- BP#966 (Gate de versionado, dim01): los cambios de config/launcher se versionan con punto de retorno verificado.
- BP#965 (Fleet Manager, draft): el fleet elige los modelos; esta BP mantiene los servers que los ejecutan.

## Evidencia empirica (plataforma)
- Watchdog de embedding :8082 (scripts/embedding-watchdog.ps1 + tarea StudioZ_Embedding_Watchdog AtLogOn elevada): poll 15s, 3 fallos -> kill+relanz, single-instance lock+mutex, cola de embeddings retiene el trabajo (docs/akasha-embedding-flow.md).
- Leccion S405 (2026-08-04): oversubscription OpenBLAS en embedding server -> rebuild build-cpu-native (GGML_BLAS=OFF) + cap de hilos; corto 84ms->36ms, medio >60s->746ms/406tps.
- Leccion 2026-09-05: prefill de 7k-15k tokens con >2 jobs concurrentes satura 8 hilos (prefill hasta 15 min, /slots bloqueado) -> binario v2 --max-concurrent-prefills 2.
- Patron de unidad canonica: 17 unidades en <local-path> (registry.json) con README+mermaid+installer+tests+git propio.
