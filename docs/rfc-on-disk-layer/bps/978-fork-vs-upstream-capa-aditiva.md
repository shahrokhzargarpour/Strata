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
  - Source: internal best-practice database, record BP#978, maturity `active`
  - ISO references as declared by the record: ISO 10007:2017; ISO/IEC/IEEE 12207:2017; ISO/IEC 25010:2023
  - Copied: 2026-10-09
-->

# BP 978 — Mantenimiento de un fork/capa local contra los releases de un proyecto de terceros (upstream): pin de base en lock, anclas por patron, verificador que falla ruidosamente y reaplicacion scriptada (ISO 10007/12207/25010)

# Mantenimiento de un fork/capa local contra los releases de un proyecto de terceros (upstream)

## Regla normativa
Cuando se mantiene una capa ADITIVA propia sobre un proyecto de terceros que publica releases (un fork vivo, no un fork congelado), la capa NO se edita sobre una rama que sigue el HEAD ajeno. La capa se construye ENCIMA de un tag pinneado del upstream, se declara contra ese tag en un lock versionado, y se reaplica de forma scriptada y verificable sobre cada tag nuevo. La verdad de la capa son sus PARCHES + sus ANCLAS + su VERIFICADOR, no el estado de un arbol de trabajo. Regla: pinnear la base, anclar por patron, verificar antes de confiar, y reaplicar sin perder atribucion.

## Reglas operativas

### R1. Pin de la base en un lock (upstream + tag + commit + ramas)
- Un archivo de lock (`upstream.lock`) declara el upstream, el tag base, el commit exacto y las ramas de trabajo (base y capa).
- La capa se construye ENCIMA de ese tag, no de `main`/HEAD.
- Invariante por defecto: con los flags de la capa AUSENTES, el comportamiento debe ser IDENTICO al del tag base (capa INERTE). Si no, la capa no es aditiva.

### R2. Anclas por PATRON, nunca por numero de linea
- Cada punto del upstream que la capa toca se declara como un ancla: {id, archivo, PATRON, que_protege}.
- El ancla es un texto buscable (nombre de funcion, literal de formato, cadena del parser), NO un numero de linea: los numeros de linea derivan con cada release y rompen la verificacion en silencio.
- El verificador (R3) y la reaplicacion (R4) dependen de que las anclas usen patron.

### R3. Verificador que FALLA RUIDOSAMENTE
- Un verificador (`verify-layer.ps1` o equivalente) comprueba cada ancla contra el arbol y cada flag contra el binario (`--help`), y sale con exit 1 (no 0) si algo se movio o falta.
- Prohibido "aplicar el parche y seguir": si un ancla se movio, el arbol NO es utilizable hasta resolverlo. Fallar ruidosamente ES la funcion del verificador.
- Cuando la capa declara flags que aun NO estan implementados, el verificador debe reportarlos como faltantes: eso prueba que el verificador realmente verifica.

### R4. Reaplicacion scriptada sobre cada tag nuevo
- Actualizar = clonar el tag nuevo -> aplicar `patches/*.patch` con `git am --3way` -> correr el verificador. Si hay deriva, NO se entrega el arbol.
- Los parches se exportan desde la capa con `git format-patch <tag_base>..<rama_capa> -o patches`; la rama base del upstream se deja limpia (== tag).
- `git am --3way` absorbe el movimiento del contexto sin reescribir a mano.

### R5. Un flag desconocido es error FATAL
- En muchos parsers (p. ej. el de Strata) un flag desconocido aborta. Corolario: un flag NUEVO jamas puede ir en el config de un motor/binario VIEJO; romperia el arranque.
- Por eso la capa activa su comportamiento SOLO con flags presentes y con default APAGADO (inerte). La config de produccion vieja sigue siendo valida.

### R6. Aporte al upstream: unidades chicas, inertes por defecto, con el formato del destino
- Un aporte que se propone al upstream se entrega en unidades PEQUENAS, INERTES POR DEFECTO (detras de un flag apagado) y respetando el FORMATO/TESTS/ESTILO del proyecto destino. No se cambia el comportamiento por defecto ni el contrato existente.
- Se manda primero el test que reproduce; los cambios de API son puramente ADITIVOS (no rompen firmas existentes).

### R7. Preservar la atribucion del trabajo ajeno absorbido
- Los PR ajenos que se absorben en la capa se aplican con `cherry-pick -x` y, si hay que reescribir el mensaje, con `--author` explicito, preservando el autor original Y dejando la URL del PR en el mensaje.
- El autor del PR sigue siendo el autor del commit; la maquina local queda como committer (auditable). No se borra la autoria para "limpiar" el historial.

### R8. Registrar lo absorbido y declarar invariantes / no-afirmaciones
- El lock lista los PR ajenos absorbidos (pr, autor, titulo, url, en que rama se aplico).
- El lock declara ademas INVARIANTES (que debe seguir siendo cierto) y NO-AFIRMACIONES (que la capa NO promete), p. ej. una limitacion por atencion causal.

## Por que anclas + verificador en vez de merge/rebase
- Hacer `merge`/`rebase` de la rama de la capa sobre el HEAD ajeno arrastra todo el estado del arbol y no dice QUE se rompio donde. El patron de anclas + verificador dice, por cada punto, si sigue existiendo, ANTES de compilar.
- El lock no reemplaza a los tests del destino: se corren ambos (la bateria host-only del proyecto + el verificador de anclas).

## Fundamento y evidencia (artefactos en disco)
- Capa de referencia: `<local-path>` (capa aditiva sobre `Niko1221/Strata` tag v0.1.40.1, commit 82f46a8c8f475f001ad76d92f58f4a4f8ffb0253).
- `upstream.lock`: base (upstream + tag + commit + ramas) + 2 PRs ajenos absorbidos + 9 anclas {id, archivo, patron, que_protege} + invariantes + no_afirmaciones.
- `verify-layer.ps1`: comprueba anclas (patron) y flags (via `--help`); exit 1 con la lista de faltantes. Reporto como faltantes los flags de `--system-prompt-cache*`, que efectivamente no estan implementados -> el verificador funciona.
- `apply-layer.ps1`: clona el tag -> `git am --3way` los `patches\*.patch` -> corre el verificador; si falla, no deja arbol utilizable.
- Informe F2: `02-informes\auditoria-sistema-2026-08-15\09-implementacion\2026-10-06-f2-arbol-dev-y-delta1-v1.0.0.md` (los PR #1271 y #1269 se absorbieron con `cherry-pick -x`, autor original preservado + URL en el mensaje).
- Ancla critica A6 de Strata: `src/program/generate.cpp` :: `unknown argument` -> "un flag desconocido es error fatal". Es la razon por la que un flag nuevo NUNCA va en el config de un motor viejo.

## Limites y no-afirmaciones
- Verificador de anclas != verificacion de runtime: que las anclas existan y el binario compile NO prueba que el camino funcione sirviendo. (En F2 el layer-split real con 2 GPUs NO se ejecuto.)
- El lock debe ACTUALIZARSE cuando el tag nuevo mueve el parser de args (base.tag/commit y las anclas/flags del parser).
- No se afirma compatibilidad binaria entre builds/versiones distintas del upstream.
- La capa es inerte SOLO si sus flags estan ausentes; con flags presentes el comportamiento depende de la version del binario.
- Las anclas cubren los puntos conocidos; un cambio del upstream fuera de esos puntos no lo detecta el verificador (se detecta por compilacion/tests).

## Relaciones con otras BPs
- BP#966 (Gate de versionado, dim01): COMPLEMENTARIA. La 966 versiona NUESTROS commits; esta BP trata de absorber releases de un TERCERO sin perder la capa.
- BP#974 (Parametrizacion de variables, dim12): COMPLEMENTARIA. La 974 fija el config como SSOT; esta BP explica por que un flag nuevo no entra en el config viejo.
- BP#957 (Unificacion de asistentes + registry versionado, dim19): COMPLEMENTARIA. Ambas usan un lock/registry versionado como fuente de verdad de la capa.
- BP#389 (safe refactor, dim14): COMPLEMENTARIA. Transiciones aditivas; esta BP las aplica a un upstream ajeno.
- BP#967 (mantenimiento de servers LLM locales, dim14): COMPLEMENTARIA (mismo dominio Strata/llama.cpp).
- Skill `gitversionado` (ISO 10007): la capa se versiona como cualquier artefacto propio; esta BP agrega el pin de base + anclas + verificador.
- BP#823 (git workflow selectivo) / BP#824 (versionado semantico): COMPLEMENTARIAS; rigen NUESTRO workflow, no la relacion fork-upstream.

## Fuentes primarias
- Upstream: http<local-path> (tag v0.1.40.1, commit 82f46a8; declarado en `upstream.lock`).
- PRs ajenos absorbidos: http<local-path> (ANBAL534), http<local-path> (pspranger-throw).
- Artefactos locales: `upstream.lock`, `verify-layer.ps1`, `apply-layer.ps1`, informe F2 (rutas arriba).
- Marco normativo: ISO 10007:2017 (gestion de configuracion: identificacion, control de cambios, baselines), ISO/IEC/IEEE 12207:2017 (mantenimiento / gestion de configuracion), ISO/IEC 25010:2023 (mantenibilidad: modularidad, modificabilidad).
