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
  - Source: internal best-practice database, record BP#979, maturity `active`
  - ISO references as declared by the record: ISO 9001:2015; ISO 10007:2017; ISO/IEC/IEEE 12207:2017
  - Copied: 2026-10-09
-->

# BP 979 — Entrega de un aporte de software a un proyecto de terceros (propuesta al mantenedor): documento de entrega con resumen ejecutivo, estado explicito, no-afirmaciones y decisiones delegadas (ISO 9001/10007/12207)

# Entrega de un aporte de software a un proyecto de terceros (propuesta al mantenedor)

## Regla normativa
Cuando se propone un aporte de software a un proyecto de TERCEROS (un mantenedor ajeno que decide si lo adopta), el artefacto NO es el PR ni el codigo: es un DOCUMENTO DE ENTREGA autocontenido que (a) abre con un resumen ejecutivo que se lee en ~2 minutos y hace la pregunta honesta '¿te conviene?', (b) declara su estado sin adornos ('listo para REVISION, NO para merge'), (c) separa lo MEDIDO de lo NO medido, (d) enumera sus NO-AFIRMACIONES, y (e) deja explicito que la decision de adoptar es del mantenedor. Regla: el aporte se PROPONE de forma honesta y revisable; no se impone ni se sobre-afirma. La entrega es un acto de comunicacion tecnica, no la fusion del codigo.

## Reglas operativas

### R1. Resumen ejecutivo primero, con la pregunta honesta
- El documento abre con un resumen legible en ~2 minutos: que contiene, para que sirve y cuanto cuesta revisarlo (bajo si es aditivo e inerte, con tests).
- Incluye la pregunta honesta al mantenedor: '¿te conviene? y si no, decilo'. Se le ofrece explicitamente la salida de RECHAZAR el aporte y se explica cuando conviene hacerlo (p. ej., si prefiere que esa politica viva FUERA del motor, como decidio llama.cpp: el server da el mecanismo, el cliente la politica).
- Prohibido enterrar la decision al final: el mantenedor es el recurso escaso.

### R2. 'Que estas revisando': inventario de bloques con archivos y estado
- Una tabla por bloque: que incluye, QUE ARCHIVOS toca y el ESTADO por bloque (✅ implementado / 🟡 en curso).
- Declara el alcance TOTAL y lo que el aporte NO incluye.
- Cada bloque nace INERTE por defecto (apagado por flag): sin los flags, el comportamiento del destino es el suyo. (Comparte esta regla con BP#978 R6.)

### R3. Estado explicito, sin adornos
- Declara el estado en una linea, arriba y sin ambiguedad: 'completa y lista para REVISION - NO lista para merge'; y explica POR QUE (puntos en curso + propuesta especificada pero no ejecutada).
- Tabla de verificacion: que se probo, CON QUE CRITERIO y el RESULTADO. Lo no verificado se marca 🟡 y NO se cuenta como verificado.
- Regla dura: no hay afirmacion sin medicion. Lo que no esta medido se dice como no medido. Se distingue 'especificado y completo' de 'ejecutado'.

### R4. No-afirmaciones explicitas
- Lista lo que el aporte NO promete, para que el mantenedor no asuma comportamiento no soportado (p. ej. la atencion causal: no se reutiliza la cola bajo un system prompt distinto).
- Se declara el riesgo residual ANTES de que el otro lo descubra midiendo (p. ej. diferencia numerica entre toolchains; por eso el criterio es paridad de tokens, no 'compila y listo').
- Se separa lo que es 'propuesta para revisar' de lo que es 'implementado y medido'.

### R5. Las decisiones que se le dejan al mantenedor
- Enumerar explicitamente las decisiones que NO se toman unilateralmente y se difieren al dueño del proyecto destino: nombres de flags, si un elemento entra o no en la identidad del formato, alcance no cubierto, politica que quiza pertenece al cliente y no al motor.
- Decir, para cada una, que cambiaria si el mantenedor decide distinto.
- Prohibido decidir por el destino lo que es del destino.

### R6. Unidades revisables e independientes + verificador que falla ruidosamente
- Entregar en una SERIE DE PARCHES pequena e INDEPENDIENTE entre si: el mantenedor puede tomar un bloque y dejar el resto.
- Acompanar con un script que clona el tag base, aplica los parches y VERIFICA las anclas antes de dejar un arbol a medias: si el codigo del destino se movio, FALLA RUIDOSAMENTE (exit 1), no entrega un parche a medias. (Mecanismo de anclas del BP#978.)
- Respetar el FORMATO/tests/estilo del destino: no se inventa un segundo formato ni un contrato paralelo; los cambios de API son puramente aditivos.

### R7. Atribucion del trabajo ajeno preservada
- El trabajo de terceros absorbido en el aporte va ATRIBUIDO a su autor: cherry-pick -x y, si hay que reescribir el mensaje, --author explicito, preservando la URL del PR original.
- El autor original sigue siendo el autor del commit; la maquina local queda como committer (auditable). No se borra la autoria para 'limpiar' el historial.

### R8. Convencion de marcado y creditos con fecha
- Lo NO verificado va con marca (🟡) y SE LEE COMO NO TERMINADO; nunca se cuenta como verificado.
- Creditos al final, con fecha: quien planteo el problema, quien fijo los requisitos, quien reviso cada entrega y que asistente participo; y la declaracion de que todo lo verificable esta en disco (informes, evidencia cruda y series de parches).

### R9. La entrega no es el merge
- Reiterar que el artefacto es una PROPUESTA: el mantenedor decide si adopta y COMO. El aporte no se empuja al destino ni se asume aceptado.
- Coherente: no se manda un PR hasta que 'la matriz cierre' (los 🟡 esten verdes).

## Fundamento y evidencia (artefacto en disco)
- Artefacto de referencia: <local-path> (2026-10-06), aporte sobre Niko1221/Strata tag v0.1.40.1 (commit 82f46a8).
- Estructura observada y verificable en el documento: 'Resumen (leé esto y nada más si tenés 2 minutos)' con la pregunta '¿Te conviene?'; 'Qué estás revisando' con tabla bloques/archivos/estado; 'ESTADO DE LA PROPUESTA: completa y lista para REVISIÓN — NO lista para merge'; '3. Estado de verificación (sin adornos)' y '3-bis. Batería de pruebas' con criterio y resultado; '4. Cosas que quizá quieras decidir vos'; '5. Cómo lo aplicarías' (serie de parches + verificador); '6. Propuesta ... CUDA 13 ... completa para revisar, no ejecutada'; y creditos finales con fecha.
- Marcado de no terminado con 🟡 ('lo que no está medido está marcado 🟡 y dicho como tal'; 'no vamos a mandarte un PR hasta que la matriz cierre').
- Atribucion de trabajo ajeno preservada (cherry-pick -x con URL del PR), declarada en el propio documento y en el upstream.lock del BP#978.
- Mecanismo de verificacion ruidosa: verify-layer.ps1 (anclas + flags; exit 1 si algo se movio) y apply-layer.ps1 (clona tag -> git am --3way -> verifica), artefactos del BP#978.

## Limites y no-afirmaciones
- Esta BP describe COMO se entrega y presenta el aporte; NO afirma que el aporte sea aceptado ni que el mantenedor lo adopte.
- No sustituye el juicio del mantenedor: el documento existe precisamente para informar SU decision.
- La convencion 🟡 es una practica observada en un artefacto; no esta impuesta por una herramienta ni por un linter.
- No hay evidencia en disco, a esta fecha, de la respuesta del mantenedor de Strata al aporte (no se afirma aceptacion ni rechazo).
- El ejemplo 'CUDA 13 especificado pero no ejecutado' ilustra la distincion 'especificado vs ejecutado'; no se afirma que el build CUDA 13 se haya corrido.
- Referencias ISO (9001:2015 cl. 7.5; 10007:2017; ISO/IEC/IEEE 12207:2017) provienen de BPs adyacentes ya vigentes (BP#946, BP#978); no se re-verifico el texto verbatim en esta curacion.

## Relaciones con otras BPs
- BP#978 (mantenimiento de un fork/capa local contra releases de un tercero, dim19): COMPLEMENTARIA. 978 es el MANTENIMIENTO del fork (pin de base, anclas, reaplicacion); esta BP es el ARTEFACTO DE ENTREGA al mantenedor (documento, estado, no-afirmaciones, decisiones delegadas). Ambas comparten las reglas de aporte en unidades pequenas/inertes (978 R6) y de atribucion (978 R7), pero el objeto es distinto: mantener la capa vs presentar el aporte.
- BP#946 (control de documentos ISO 9001:2015 cl. 7.5 para artefactos de agentes, dim15): COMPLEMENTARIA. 946 fija la convencion de control documental (nombre, versionado semantico, metadatos de proveniencia); esta BP fija el CONTENIDO y la honestidad de UN artefacto concreto: el documento de entrega de un aporte a un tercero.
- BP#951 (protocolo S360 commit-safe, dim20): COMPLEMENTARIA pero NO aplicable al destino. S360 rige NUESTROS commits productivos; un aporte a un tercero se entrega como propuesta/parches, y su aceptacion no es un commit nuestro.
- BP#966 (gate de versionado pre-modificacion, dim01): COMPLEMENTARIA. Nuestro lado del aporte se versiona con punto de retorno verificado.
- BP#974 (parametrizacion de variables, dim12) y BP#2 (cambios aditivos y retrocompatibles, dim12): COMPLEMENTARIAS. Sostienen la regla 'flag nuevo nunca en config viejo' y 'cambio aditivo con contrato estable'.
- BP#389 (safe refactor, dim14): COMPLEMENTARIA. Transiciones aditivas.

## Fuentes primarias
- Artefacto de entrega: <local-path> (2026-10-06).
- Upstream destino: http<local-path> (tag v0.1.40.1, commit 82f46a8).
- PRs ajenos atribuidos: http<local-path> (ANBAL534), http<local-path> (pspranger-throw).
- Mecanismo de capa (anclas + verificador): upstream.lock, verify-layer.ps1, apply-layer.ps1 (BP#978).
- Informe F2: 02-informes\auditoria-sistema-2026-08-15\09-implementacion\2026-10-06-f2-arbol-dev-y-delta1-v1.0.0.md.
