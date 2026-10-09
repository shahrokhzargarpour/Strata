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
  - Source: internal best-practice database, record BP#966, maturity `aprobado`
  - ISO references as declared by the record: ISO 10007:2017; ISO/IEC/IEEE 12207:2017
  - Copied: 2026-10-09
-->

# BP 966 — Gate de versionado pre-modificacion — commit verificado previo + commit posterior (ISO 10007)

# Gate de versionado pre-modificacion — commit verificado previo + commit posterior (ISO 10007)

## Regla normativa
Antes de modificar un sistema versionado en git para una nueva version (N+1), se DEBE confirmar que existe un commit versionado limpio con sus anotaciones de version (punto de retorno). Una vez realizados los cambios, se DEBE crear un nuevo commit versionado (N+1). Solo asi hay control real de versiones: cada version nueva parte de un punto de retorno verificado y deja un punto de retorno para la siguiente.

Aplica a todo sistema versionado en git: skills, BPs, hooks, MCP servers, scripts, config, modelos (manifest).

## Procedimiento verificable
### Pre-modificacion (gate de entrada a la nueva version)
- P1: `git status --porcelain` debe devolver VACIO (arbol limpio, sin cambios sin commit).
- P2: Confirmar HEAD versionado: el mensaje de HEAD sigue `[SXXX] [tipo]: [descripcion]` O existe un tag de version en/cerca de HEAD (`git describe --tags --exact-match HEAD`).
- P3: Si P1 o P2 fallan, commitear el estado actual PRIMERO (crear el punto de retorno) antes de proceder con el trabajo de la nueva version.
Logica: si el arbol no esta limpio o HEAD no esta versionado, NO hay punto de retorno valido. Se crea uno (commit del estado actual) antes de tocar nada.

### Post-modificacion (cierre de la nueva version)
- P4: `git add -A` (o los archivos cambiados); `git status --porcelain` muestra solo los cambios esperados.
- P5: `git commit -m "[SXXX] [tipo]: [descripcion]"` — nuevo commit con anotacion de version.
- P6: Si Major o Minor (clasificacion gitversionado), `git tag vX.Y.Z` (o `SXXX-post`).

### Punto de retorno (rollback)
- P7: El commit/tag verificado en P2-P3 es el punto de retorno. Si el trabajo de la nueva version falla: `git checkout <tag> -- <ruta>` (restaurar archivos) o `git revert <commit>` (invertir el commit).

## Fundamento normativo (evidencia verificable)
- ISO 10007:2017 (Quality management — Guidelines for configuration management, Ed. 3, 2017-03, confirmada 2023, vigente; stage 90.92 a revisar → ISO/WD 10007; TC ISO/TC 176/SC 3). Abstract oficial verbatim: "provides guidance on the use of configuration management within an organization. It is applicable to the support of products and services from concept to disposal." Fuente: http<local-path>
- SEBoK (Systems Engineering Body of Knowledge, sebokwiki.org), citando ISO/IEC/IEEE 15288 6.3.5.1: "The purpose of the configuration management process is to manage system and system element configurations over their life cycle." Actividades CM: CM Planning and Management, Configuration Identification, Configuration Change Management, Configuration Status Accounting. Buenas practicas: identificacion consistente, automatizacion CM, trazabilidad de requisitos.
- ISO/IEC/IEEE 12207 (ciclo de vida de ingenieria de software; edicion 2026 vigente desde abril 2026): la gestion de configuracion es un proceso de soporte (ed. 2017) / uno de los 7 procesos de gestion tecnica (ed. 2026) que exige control de versiones y trazabilidad entre versiones.
- Baselines = puntos de retorno versionados (ISO 10007): el gate P1-P3 garantiza que cada version N+1 parte de un baseline verificado.

## Relacion con el sistema
- Extiende el skill `gitversionado` (checkpoints SXXX-pre/SXXX-post + clasificacion Major/Minor/Patch) agregando el GATE de verificacion explicita ANTES de modificar, que hoy no existe como obligacion verificable.
- El motoraxiomatico la referencia como BP mandatoria para tareas de diseno/mantenimiento/refactor que tocan un sistema versionado (multiarchivo, hooks, skills, MCP, config).
- El ejecutor-secuencial-axiom incluye el gate P1-P3 como primer nodo del task_tree cuando la tarea modifica un sistema versionado.
- Coexiste con commit-safe (S360 pre-commit): gitversionado versiona, esta BP verifica antes de versionar.

## Anti-patrones
- Modificar un sistema versionado sin confirmar punto de retorno previo (arbol sucio o HEAD sin version) → sin rollback posible.
- Acumular cambios de N versiones sin commit intermedio → perdida de trazabilidad.
- WIP legitimo sin commitear como checkpoint SXXX-wip → el gate P1 falla falsamente (mitigacion: commitear el WIP como checkpoint, no descartarlo).
