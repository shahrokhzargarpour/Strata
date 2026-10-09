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
  - Source: internal best-practice database, record BP#980, maturity `active`
  - ISO references as declared by the record: ISO 10007:2017; ISO/IEC/IEEE 12207:2017; ISO/IEC 25010:2023
  - Copied: 2026-10-09
-->

# BP 980 — Entrega de una serie de cambios que se integra limpia y verificablemente (merge clean): serie contigua sobre un tag base, paridad de arbol por hash, punto congelado y verificacion previa al PR (ISO 10007/12207/25010)

# Entrega de una serie de cambios que se integra limpia y verificablemente (merge clean)

## Regla normativa
Cuando se entrega una SERIE DE CAMBIOS (a un proyecto de terceros o a una rama propia) que debe integrarse LIMPIA, "merge clean" NO es un boton ni una promesa: es una PROPIEDAD QUE SE CONSTRUYE y se verifica mecanicamente. La serie se apoya en un tag base pinneado, se entrega como parches contiguos sin mezclar tooling, y su criterio de aceptacion no es "las anclas siguen ahi" sino PARIDAD DE ARBOL POR HASH: el arbol resultante de aplicar la serie sobre el tag base debe ser byte-identico al de la referencia que se entrega. El punto de entrega se CONGELA (base, tip, arbol, hashes) y NUNCA se mide contra una rama que siguio creciendo. Antes de proponer la integracion se verifica contra el destino que entra EXACTAMENTE lo esperado. Regla: la integracion limpia se DEMUESTRA con hashes y con una verificacion previa; no se asume por "no hay conflictos".

## Reglas operativas

### R1. Serie contigua sobre un tag base, sin mezclar tooling
- La serie son commits CONTIGUOS sobre un tag pinneado del destino (o sobre una base explicita), no sobre el HEAD vivo.
- La serie que se entrega contiene SOLO los cambios que aporta. El tooling del emisor (lock, verificadores, scripts de reaplicacion, documentacion de entrega) NO viaja dentro de la serie: va al lado, en la carpeta de la entrega.
- Cada commit es una unidad con un asunto que se lee; los cambios de una politica no se reparten entre commits que no la mencionan.
- Evidencia: 10 commits sobre `v0.1.40.1` (delta 1+2, tip `bea20c9`); en el cierre del delta 3 el informe declara "Ningun archivo de tooling entro en la serie" y `patches/` se regenera con `git format-patch <base>..<rama> -o patches`.

### R2. Paridad de ARBOL POR HASH como criterio de aceptacion
- El criterio de que la serie "se aplica limpia" es que el `HEAD^{tree}` del clon (tag base + `git am` de los parches) sea IDENTICO al `<referencia>^{tree}` que se entrega, con el arbol sin cambios sin commitear.
- No alcanza con verificar las anclas ni con "compila": una diferencia de arbol es FALLO — un commit sin exportar, un archivo de mas, o un parche que aplico distinto.
- El validador imprime ambos hashes y la lista de diferencias (`git diff --stat <treeRef>`) y exige exit 0 para dejar el arbol utilizable.
- Evidencia: `apply-layer.ps1` compara `git -C $Dst rev-parse 'HEAD^{tree}'` contra `git -C $PSScriptRoot rev-parse "$Serie^{tree}"` y ademas exige `git status --porcelain` vacio.

### R3. Congelar el punto de entrega; nunca medir un congelado contra una rama viva
- Fijar en un `FROZEN.md` el punto exacto: base upstream + commit, tip de la serie + asunto, arbol resultante y los hashes de los parches.
- El artefacto CONGELADO se mide contra el commit congelado, NO contra la rama de trabajo que siguio avanzando. Medir un congelado contra la rama viva produce un "no coincide" FALSO.
- El validador expone parametros para elegir la referencia (`-Serie <commit>`) y el lock de esa entrega (`-Lock <archivo>`); el default apunta al arbol de trabajo y es correcto solo para el.
- Evidencia: `FROZEN.md` (base `v0.1.40.1`/`82f46a8`, tip `bea20c9`, arbol `e7506b42...`, hashes de los 10 parches) y los parametros `-Serie`/`-Lock` de `apply-layer.ps1`.

### R4. Verificar ANTES de proponer, contra el destino real
- Antes de abrir el PR o pedir la integracion, consultar el compare del destino (API de GitHub: `status`, `total_commits`, `ahead_by`, `behind_by`, lista de archivos) para confirmar que entran EXACTAMENTE los commits esperados y NINGUN archivo de otro frente/delta.
- `behind_by: 0` significa que no falta ningun commit del destino; `ahead_by` igual al numero de commits esperados confirma que no se cuela nada.
- No se abre el PR "a ciegas": se verifica primero que el boton sea el correcto.
- Evidencia: sesion S813 (2026-10-07) — `GET http<local-path>` -> `status: ahead`, `total_commits: 10`, `ahead_by: 10`, `behind_by: 0`, 24 archivos "todos de la serie", y "delta 3: nada" (sin `stage_plan.hpp`/`head_device`/`test_setup_head_device`).

### R5. Un "merge clean" no se fuerza: auto-merge apagado
- Que el destino diga "changes can be cleanly merged" solo significa que HOY no hay conflictos; NO autoriza a fusionar.
- En un PR contra el repo de un tercero, el auto-merge lo gobiernan las reglas de SU repo y podria fusionarse solo: para una aportacion, eso es PRESUMIR. Se deja sin tildar; la fusion la decide el mantenedor.
- Coherente con BP#979 R9 (la entrega es una propuesta, no el merge).
- Evidencia: sesion S813 (2026-10-07) — se identifico el recuadro de auto-merge de GitHub y se recomendo dejarlo sin tildar.

### R6. Serie aditiva y reversible: un modo reproduce el comportamiento previo byte a byte
- Se conserva un modo que reproduce el comportamiento PREVIO byte a byte, de modo que el integrador pueda tomar una parte y descartar el resto sin cambiar el default.
- Los cambios de comportamiento nuevos nacen INERTES (detras de un flag apagado); sin los flags, el destino se comporta como su base.
- Evidencia: `--conversation-cache-spill-on evict` reproduce el delta 1 byte a byte; `park` es el modo nuevo y sin `--conversation-cache-spill-dir` ninguno de los dos hace nada.

### R7. Terminaciones de linea fijadas para que la serie se aplique en cualquier clon
- Los parches se leen byte a byte con `git am`: hay que marcar la carpeta de parches para que git NO convierta sus terminaciones (`patches/** -text` en `.gitattributes`).
- Sin esa marca, un checkout con `core.autocrlf=true` reescribe la serie a CRLF y un clon limpio NO puede aplicarla (73.365 -> 72.137 bytes).
- Evidencia: el `.gitattributes` del arbol de la capa incluye `patches/** -text`; `FROZEN.md` lo declara.

### R8. Declarar lo NO medido en vez de dejarlo leerse como terminado
- La serie que no fue ejercitada end-to-end se dice como tal (fila 🟡), separada de lo medido, y no se cuenta como verificada.
- Lo "especificado pero no ejecutado" se distingue de "implementado y medido".
- Evidencia: `FROZEN.md` seccion "Lo que NO incluye" (delta 3 fuera; CUDA 13 especificada no ejecutada; colapso/compactacion/cancelacion no medidos end-to-end). Comparte la convencion con BP#979 R3/R8.

### R9. Un flag que no puede tumbar el motor
- Si una funcion opt-in es inelegible, se APAGA con el motivo en el arranque; en runtime se sirve SIN la funcion, nunca se sale con error.
- Antes de servir, si el tipo no corre, se libera lo asignado y se sigue; los sitios de fallo DEGRADAN en vez de matar el proceso.
- Evidencia: informe delta 3 §2.3 — "Los cinco sitios de fallo pasaron de matar el proceso a degradar: `--batch-mtp` es opt-in y un flag no puede tumbar el motor"; el defecto de la prueba en vivo (`MTP admission ... exit 1`) se diagnostico y se arreglo a degradacion.

## Fundamento y evidencia (artefactos en disco)
- Validador de paridad de arbol: `<local-path>` (y su copia congelada en `<local-path>`).
- Punto de entrega congelado: `<local-path>` (base `v0.1.40.1`/`82f46a8c...`, tip `bea20c98...`, arbol `e7506b4270e527953ec76b9b96b4ce1819c38c99`).
- Documento de entrega: `<local-path>` y `PR-DELTA2.md`.
- Marco de terminaciones de linea: `.gitattributes` del arbol de la capa (`patches/** -text`).
- Verificacion previa al PR (compare de la API): sesion Akasha S813, 2026-10-07 (`mensajes_raw` ids 141557/141559) -> `status ahead`, `total_commits 10`, `ahead_by 10`, `behind_by 0`, 24 archivos de la serie, sin archivos del delta 3.
- Leccion del flag que no tumba el motor: `02-informes\auditoria-sistema-2026-08-15\09-implementacion\2026-10-07-delta3-batch-mtp-y-head-v1.0.0.md` §2.3.

## Limites y no-afirmaciones
- Esta BP describe COMO construir y verificar que una serie se integra limpia; NO afirma que el destino la acepte ni que el merge se haga.
- "Paridad de arbol por hash" prueba que la serie REPRODUCE el punto entregado; no prueba que ese punto FUNCIONE sirviendo (eso lo da la bateria del destino; BP#978: verificador de anclas != verificacion de runtime).
- La verificacion previa con el compare de la API toma el estado del momento; el destino puede moverse despues (hay que re-verificar al abrir el PR).
- El modo "reversible byte a byte" se verifico para el delta 1 con `evict`; no se afirma reversibilidad de TODA la serie por construccion.
- La marca `patches/** -text` se observo en el arbol de la capa; no se re-verifico el comportamiento en un clon con `core.autocrlf=true` a esta fecha (el dato 73.365 -> 72.137 bytes es el registrado en el aporte).
- Los ids de Akasha (141557/141559) son de `mensajes_raw`: se citan como evidencia de la practica, no como fuente normativa externa.
- ISO 10007/12207/25010 se declaran como marco ya usado por BPs adyacentes (BP#978/979/974) en este dominio; no se cita texto verbatim en esta curacion.

## Relaciones con otras BPs
- BP#979 (entrega de un aporte de software a un proyecto de terceros, dim19): COMPLEMENTARIA. 979 es el DOCUMENTO de entrega (que se comunica, estado explicito, no-afirmaciones, decisiones delegadas); esta BP es la MECANICA de integracion (paridad de arbol por hash, freeze, verificacion previa al PR, reversibilidad). Ambas comparten "la entrega no es el merge"; esta BP agrega R5 (auto-merge apagado) y el criterio por hash.
- BP#978 (mantenimiento de un fork/capa local contra releases upstream, dim19): COMPLEMENTARIA. 978 sostiene la capa contra releases (pin, anclas, verificador fail-loud, reaplicacion); esta BP fija como se ENTREGA/PRUEBA que la serie se integra limpia (paridad de arbol por hash + freeze + compare previo). La paridad por hash es un ENDURECIMIENTO del `apply-layer` de 978: de "las anclas siguen ahi" a "el arbol es identico".
- BP#951 (protocolo S360 commit-safe, dim20): COMPLEMENTARIA pero NO aplicable al destino. S360 rige NUESTROS commits productivos; la serie se entrega como propuesta/parches.
- BP#946 (control de documentos ISO 9001:2015 cl. 7.5, dim15): COMPLEMENTARIA. 946 fija nombre/versionado/proveniencia del artefacto; esta BP fija la EVIDENCIA mecanica (hashes, freeze, compare).
- BP#966 (gate de versionado pre-modificacion, dim01) y BP#2 (cambios aditivos y retrocompatibles, dim12): COMPLEMENTARIAS. Sostienen "punto de retorno verificado" y "cambio aditivo con contrato estable".
- BP#389 (safe refactor, dim14): COMPLEMENTARIA. Transiciones aditivas; esta BP las hace verificables por hash al integrar.

## Fuentes primarias
- Validador: `<local-path>` · copia congelada `<local-path>`.
- Entrega congelada: `<local-path>`.
- Destino: http<local-path> (tag v0.1.40.1, commit 82f46a8).
- Compare verificado (2026-10-07): http<local-path>
- Leccion del flag: `02-informes\auditoria-sistema-2026-08-15\09-implementacion\2026-10-07-delta3-batch-mtp-y-head-v1.0.0.md`.
- Mecanismo de capa (ancestral): `upstream.lock`, `verify-layer.ps1` (BP#978).
