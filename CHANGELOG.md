# CHANGELOG — capa Strata (tooling de la capa, NO va en la serie de parches)

Capa aditiva sobre Strata `v0.1.40.1`. **Con los flags ausentes el comportamiento es idéntico a la base.**
Este archivo es el registro de cambios de la capa; vive con el tooling (`upstream.lock`, `verify-layer.ps1`,
`apply-layer.ps1`, `patches/`, la nota de entrega) y por eso **no** forma parte de la serie de parches contra
upstream.

## delta 5a — archivar (no borrar) la copia de parking

**Fecha:** 2026-10-08 · **Base:** `layer/delta4-d7` · **Rama:** `layer/delta5a` · **Gate:** G-H APROBADO (humano, 2026-10-07)

Qué cambia. Los tres caminos que hoy **destruyen** el estado de una conversación en el tier de disco pasan a
**archivar** la copia (moverla a un subdirectorio propio) cuando el archivo está encendido:

1. **Compactación** (`discard_diverged_impl`): la copia cuya cola reescribió el cliente se movía/borraba.
2. **Superseded** (`drop_superseded`): la copia que un re-park reemplaza.
3. **Cancelación** (park provisional): el estado **pre-revert** de un pedido cancelado, que antes no publicaba
   ninguna copia, ahora se archiva (sólo ids/imágenes) antes del revert.

Flags nuevos (todos opt-in): `--conversation-cache-archive-mode off|ids|state` (**default `off`**),
`--conversation-cache-archive-dir` (default `<spill-dir>\archive`), `--conversation-cache-archive-mib`
(default 2048, presupuesto **propio**), `--conversation-cache-archive-keep` (default 4, copias por conversación),
`--conversation-cache-archive-max-age-days` (default 0 = sin retención por edad). Contadores nuevos: `archived=N` y
`archived_bytes=` en la línea periódica del tier, junto a las de park.

### Riesgo y retención (auditoría neutral C8)

- El archivo guarda lo que el tier habría borrado: `.meta` (ids de tokens + claves de imágenes) y, en `state`, el
  `.sess` completo con el K/V. Es **texto plano: no hay cifrado** y `std::filesystem::remove` es un **unlink
  normal (sin borrado seguro)**. La carpeta del archivo debe tratarse **igual de privada** que la del spill
  (volumen privado, permisos restrictivos) — ISO/IEC 27040.
- **Retención explícita:** `-keep` (copias por conversación) + `-mib` (total de bytes) + `-max-age-days` (opcional).
  Con `-max-age-days 0` (default) **no hay borrado por tiempo**: una copia persiste mientras quepa. No hay otra
  política (ISO 15489-1 / 23081-1).
- El tope **no se puede superar** por una sola copia: una conversación cuya copia archivada exceda por sí sola
  `-mib` **no se archiva** (se descarta como sin el archivo) y el GC del presupuesto es estricto al reabrir.
- **O2 (robustez):** si el MOVE del `.sess` falla en modo `state`, `archive_entry` revierte lo que ya llegó al
  archivo y **deja la entrada del tier intacta** (el descarte no ocurre): el tier nunca queda peor que antes. El
  rollback cubre también un fallo **después** de un MOVE exitoso (F3 del addendum, `D5a/relocate-multi`).
- **F2 (docs):** la fila de `--conversation-cache-archive-mode` documenta ahora que la cancelación nunca guarda
  K/V (sólo los ids pre-revert) y la referencia cruzada de `SPILL_AND_PROMPT_CACHE.md` se ajustó a eso.

### Garantía dura

> **Apagado = byte por byte idéntico.** Con el modo `off` (el default) no se crea ningún directorio, no se escribe
> ningún byte nuevo y los contadores quedan en 0: el tier de disco se comporta **exactamente** como en delta 4.
> Verificado host-only (`D5a/off` en `conversation_spill_test`).

### Invariantes preservados

- **Una copia por conversación** en el tier vivo (el archivo puede retener historial, el tier vivo no).
- La **identidad** (modelo+config, `SessionFileIdentity`) sigue mandando; el archivo conserva el formato del
  session file.
- **El archivo NUNCA es candidato de reuso**: sus entradas no entran en el índice del tier, así que `best()` no
  puede devolver una (atención causal). Es evidencia/recuperación, no caché.
- **Presupuesto y GC separados**: `--conversation-cache-archive-mib` y el GC del archivo (`enforce_archive`,
  más viejo primero) no tocan `bytes_`, `disk_evictions()` ni `enforce_age()` del tier.
- El subdirectorio de archivo **no cuenta como `stale`** en el escaneo del tier.
- **Sólo el GC borra**: el del tier para el tier vivo, el del archivo para el archivo.

### Refinamientos del gate (obligatorios, implementados)

- (a) La cancelación archiva **pre-revert** (archivar después del revert guardaría una copia idéntica).
- (b) El subdirectorio de archivo no contamina el diagnóstico del tier (salto explícito de directorios).
- (c) El presupuesto y el GC del archivo van separados de los del tier.

### Verificación

- `conversation_spill_test` host-only: **277 checks** (169 previos + 80 del delta v1.0.0 + 28 de C8/O2), todos
  verdes.
- Build CUDA (`NATIVE_EXPERTS=ON`, `arch 86;89`) que **enlaza** (`strata.exe`, exit 0).
- `verify-layer.ps1 -Exe`: **44 anclas OK** y todos los flags presentes (incluidos los **5** nuevos del archivo).

### No afirmado

- El delta **no** se midió end-to-end con el modelo cargado (el archivo, la compactación y la cancelación).
- **No** acelera la lectura posterior a la compactación: sólo recupera trabajo y permite restaurar en modo `state`.
- El modo `state` cuesta como un session file por copia (~30 KB/token medido en producción); hay que acotarlo con
  `--conversation-cache-archive-mib`.

## delta 4 / delta 3 / delta 2 / delta 1

Ver las notas de entrega y los informes en
`02-informes/auditoria-sistema-2026-08-15/09-implementacion/` (`PR-DELTA2.md` en el árbol de la capa cubre delta 2).
