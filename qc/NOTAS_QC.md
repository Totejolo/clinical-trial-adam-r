# NOTAS_QC — programación independiente, parte A

Fecha: 2026-10-05.

## Estado real de entrega y ejecución

Están preparados `qc_adsl.R`, `qc_adae.R`, `qc_adtte.R` y el programa existente `qc_t14_3_1.R`, revisado y reforzado. La revisión estática está realizada, pero **la ejecución y la generación de los tres RDS y el CSV no están completadas**: Windows devuelve `Acceso denegado` al iniciar `C:/Users/Usuario/AppData/Local/Programs/R/R-4.6.1/bin/x64/Rscript.exe`, antes de entrar en R. No se han observado los dominios ni confirmado recuentos. Ninguna comprobación implementada debe interpretarse como superada en ejecución.

`qc/run_qc.ps1` ejecuta los cuatro programas en orden con `Rscript --vanilla`, detiene el proceso ante el primer error y registra el resultado en `qc/output/ejecucion_qc.log`, con un log por programa iniciado. Se puede lanzar desde la raíz con:

```powershell
& .\qc\run_qc.ps1
```

El intento de iniciar este lanzador también quedó bloqueado por PowerShell (`PSSecurityException / UnauthorizedAccess`: ejecución de scripts deshabilitada), antes de iniciar el transcript; el fallo se registró directamente en el log. No cambia permisos ni instala paquetes. La finalización requiere que el entorno permita ejecutar la instalación de R indicada y acceder a sus paquetes. No se fabrican salidas en sustitución de una ejecución real.

## Independencia y alcance

- Las fuentes de reglas son exclusivamente `docs/SAP_A_cdiscpilot.md`, `specs/adam_specs_A.csv` y `qc/encargo_qc_codex.md`. Se revisó además el programa QC preexistente, como pidió el usuario, y los archivos generados por este trabajo dentro de `qc/`.
- No se leyó código ni resultados de `programs/`, `output/` de la raíz, `R/` o `legacy_v1/`. `qc/output/` contiene únicamente salidas del QC. No se hizo comparación con producción: corresponde a una fase posterior y exigiría acceso fuera de esta independencia.
- Se repartieron ADSL, ADAE y revisión entre subagentes; el coordinador implementó ADTTE, revisó T-14.3.1 y consolidó las decisiones. Todas las escrituras se limitan a `qc/`.
- Los programas consumen DM, EX, AE y DS de `pharmaversesdtm` y usan R base, `dplyr` y `lubridate`; no usan `admiral`.
- El alcance es los cinco entregables del encargo, con ADTTE únicamente `TTDE`. No se programan las sensibilidades, modelos, otras tablas ni XPT mencionados en el SAP general. Se conservan las etiquetas y longitudes de la especificación como atributos R `label` y `sas_length`; no se truncan textos ni se confunde un RDS con una exportación XPT.

## Interpretaciones comunes y de ADSL

1. Cadenas vacías y cadenas que solo contienen espacios se convierten en `NA`. Las columnas de fechas son `Date`; las variables integer se convierten a `integer`, las de texto a `character` y AVAL a numeric. Se ordenan las variables por `order` del CSV y los registros por `USUBJID`, añadiendo `AESEQ` en ADAE.
2. ADSL conserva todos los sujetos de DM, aunque no sean de seguridad. Edad ausente da `AGEGR1` ausente; se aplica literalmente `AGE <= 64` para `18-64` sin imponer un límite inferior no especificado.
3. Tratamiento planificado y recibido proceden literalmente de DM.ARM y DM.ACTARM. No se infiere el brazo de EX. Valores no contemplados por el mapa de dosis detienen el programa.
4. EX admisible significa `EXDOSE > 0` o `EXTRT` igual a `PLACEBO`, ignorando mayúsculas y espacios exteriores solo para esta identificación. Una dosis cero de tratamiento activo no es placebo. SAFFL depende de que exista una administración admisible, aunque sus fechas estén ausentes; los demás sujetos tienen `SAFFL=N`.
5. Las fechas completas se extraen a precisión de día, ignorando la hora. Las fechas parciales de EX no se imputan. TRTSDT es el mínimo inicio completo y TRTEDT el máximo final completo entre registros admisibles. Un EX final sin fecha no anula un final conocido de otro EX: el reemplazo por último inicio se aplica solo cuando TRTEDT del sujeto está ausente.
6. TRTEDT conserva su ausencia; LSTEXDT usa TRTEDT si existe y, si no, el máximo inicio admisible. TRTDURD usa TRTEDT de forma literal y queda ausente si este falta.
7. Se interpreta «disposition event» como `DSCAT=DISPOSITION EVENT`. Se exige un único registro de disposición por sujeto; múltiples registros detienen el proceso con los sujetos afectados, pues no hay regla para priorizarlos. Lo mismo se aplica a múltiples registros RANDOMIZED.
8. COMPLETED da EOSSTT COMPLETED; SCREEN FAILURE da EOSSTT, EOSDT y DCSREAS ausentes; otra disposición da DISCONTINUED y su DSDECOD como DCSREAS; ausencia de registro da ONGOING. Una disposición sin DSDECOD cae en la categoría residual DISCONTINUED con motivo ausente, conforme a «other»; no se inventa el motivo.
9. EOSDT y RANDDT usan DSSTDTC completo sin imputación: no existe regla para sus fechas parciales. RANDOMIZED se identifica por DSDECOD con independencia de DSCAT.

## Interpretaciones y ambigüedades de ADAE

1. ADAE conserva todas las filas de AE. La seguridad se aplica en ADTTE y T-14.3.1, no al construir ADAE.
2. ASTDT: año-mes imputa día 1 y `ASTDTF=D`; año solo imputa enero 1 y `ASTDTF=M`. Una fecha totalmente ausente sigue ausente; no se imputa un año desconocido. Sintaxis distintas de año, año-mes o fecha completa detienen la derivación.
3. Solo un inicio **imputado**, anterior a TRTSDT y con igual mes/año, se eleva a TRTSDT. Las fechas completas pretratamiento se conservan. Mes/año se evalúan después de imputar: un año solo puede acotarse a TRTSDT si este cae en enero. El SAP no precisa cómo comparar un mes ausente; esta decisión queda explícita para la comparación posterior.
4. AENDT: año-mes usa el último día real del mes, incluidos años bisiestos; año solo usa diciembre 31. No se pide flag de imputación final. Si AENDT precede a ASTDT se emite una advertencia y se conserva el resultado, sin corregir la fuente silenciosamente.
5. Flags TRTEMFL, ONTRTFL y DERMFL usan `Y` cuando cumplen la condición y `NA` en otro caso, ya que la especificación no fija un valor negativo. ASTDTF es ausente para fechas no imputadas. Esto es distinto de SAFFL, cuyo `N` sí está especificado.
6. DERMFL utiliza el SOC exacto indicado o cualquier AEDECOD que empiece por APPLICATION SITE. No se restringe a gravedad ni causalidad.
7. La definición general «en tratamiento» del SAP cita TRTEDT, pero su excepción de final ausente y la especificación de ONTRTFL usan LSTEXDT. Se aplica LSTEXDT, con ambos extremos incluidos, para ONTRTFL y TTDE.
8. **Ambigüedad de TEAE sin TRTEDT:** TRTEMFL se deriva literalmente con `TRTSDT <= ASTDT <= TRTEDT + 30`. No se sustituye TRTEDT por LSTEXDT y, si falta el primero, no se asigna Y. La regla general de último día conocido del SAP podría interpretarse como extensible a TEAE, pero la fórmula explícita de ADAE no lo hace. Se prioriza esa fórmula; la diferencia puede afectar T-14.3.1 y debe revisarse al comparar. No se cuantifica un efecto sin ejecutar los datos.

## Interpretaciones de ADTTE

1. Se produce una fila TTDE por sujeto con SAFFL Y. Si falta TRTSDT o LSTEXDT, o el final precede al inicio, el programa se detiene: no existe origen ni censura válida que permita inventar un tiempo.
2. Evento = primer ASTDT con DERMFL Y y ONTRTFL Y. Empates en el mismo día se resuelven por menor AESEQ, regla no fijada en el SAP que afecta trazabilidad pero no el tiempo ni CNSR.
3. Sin evento se censura en LSTEXDT. SRCVAR es TRTEDT cuando existe y LSTEXDT cuando se utiliza el reemplazo; SRCDOM es ADSL. En eventos la fuente es ADAE/ASTDT y SRCSEQ es AESEQ. SRCSEQ es ausente para censuras.
4. AVAL es ADT menos TRTSDT más 1; un evento o censura el primer día vale 1. Eventos tienen CNSR 0; censuras, 1. No se añade EOSDT como límite al estimando principal.
5. El SAP pide motivos de fin de **tratamiento**, pero ADSL aporta estado/motivo de fin de **estudio**, sin una regla específica de correspondencia. Se usa el proxy disponible: EOSSTT COMPLETED → TRATAMIENTO COMPLETADO; DCSREAS ADVERSE EVENT → INTERRUPCION POR EA; resto → OTRA INTERRUPCION. Si aparece ONGOING también cae en el residual; esa etiqueta sería semánticamente limitada, pues no demuestra interrupción. No se crea una cuarta categoría no especificada.
6. CNSDTDSC queda ausente en eventos. EVNTDESC es PRIMER EVENTO DERMATOLOGICO en eventos y repite el motivo en censuras: el literal para EVNTDESC censurado no está prescrito.
7. PARAM no tiene literal obligatorio; se fija `Tiempo hasta el primer evento adverso dermatologico`. PARAMCD siempre es TTDE.

## T-14.3.1 y otras contradicciones documentales

- Se mantienen cinco filas y las columnas `fila`, `TRT01A`, `n`. Se cuentan sujetos únicos, no registros, y se incluyen ceros para cada brazo presente en la población de seguridad.
- Cualquiera, grave (AESER Y), relacionado (AEREL POSSIBLE/PROBABLE) y mortal (AEOUT FATAL) exigen TRTEMFL Y y SAFFL Y.
- Interrupción del estudio por EA se cuenta directamente con DCSREAS ADVERSE EVENT en toda la población de seguridad. No exige un TEAE asociado ni utiliza AEACN: se aplica la definición expresa de SAP §7, aunque el título general de la tabla hable de TEAE.
- Orden de filas: cualquiera, graves, relacionados, interrupciones, mortales, siguiendo el cuadro de §7 y el script existente. El párrafo de definiciones intercambia las dos últimas; no cambia los recuentos.
- SAP §6 llama «estrategia compuesta» a S3 y a la vez la describe como riesgos competitivos/Aalen-Johansen. Esa terminología necesita aclaración para S3, pero no modifica TTDE ni pertenece a esta entrega.
- Las afirmaciones del SAP sobre 26 fechas AE parciales y dos sujetos sin final de exposición son expectativas documentales, **no hallazgos empíricos de este QC**. ADAE comprueba las 26 fechas y detiene la ejecución si difieren; ADSL informa el número observado sin TRTEDT.

## Controles implementados, pendientes de ejecución

ADSL comprueba unicidad de sujetos, pertenencia de EX/DS a DM, multiplicidad DS, cardinalidad, clases, longitudes, rango de fechas y correspondencia de SAFFL con EX. ADAE comprueba claves, relación con ADSL, preservación de filas, fechas válidas e imputaciones parciales, tipos y longitudes. ADTTE comprueba una fila por sujeto de seguridad, tiempos positivos, fechas dentro de exposición, coherencia CNSR/fuente y coincidencia de ADT con el registro y variable citados. T-14.3.1 comprueba claves, una fila por combinación, recuentos entre cero y el denominador del brazo, y que graves/relacionados/mortales no excedan cualquier TEAE.

La revisión estática cruzada detectó una comparación de orden sensible a atributos R y se corrigió comparando USUBJID como character; se homogeneizó ADTTE a data.frame. Los controles de ejecución y los resultados finales siguen pendientes del acceso a R.

## v1.1

- Se actualizó el literal de `PARAM` para TTDE a `Tiempo hasta el primer EA dermatologico en tratamiento (dias)`, tal como fija `specs/adam_specs_A.csv`.
- En eventos, `EVNTDESC` sigue siendo `PRIMER EVENTO DERMATOLOGICO`. En censuras ahora es `CENSURA: ` seguido de `CNSDTDSC`. Esto sustituye las interpretaciones anteriores de `PARAM` y `EVNTDESC` en las notas de ADTTE (puntos 6 y 7).
- La regla aclarada de `SRCVAR` ya estaba implementada para TTDE: `ASTDT` en eventos, `TRTEDT` en censuras cuando existe y `LSTEXDT` solo si falta `TRTEDT`. `EOSDT` corresponde a otra modalidad de censura y no se usa en TTDE. Se conserva la verificación de que la variable citada contiene `ADT`.
- La v1.1 no cambia `ADT`, `AVAL`, `CNSR` ni la selección de sujetos y eventos. Esta actualización se revisó de forma estática; no se ejecutó R por indicación del encargo v1.1.
