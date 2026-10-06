# Notas independientes de ADAE

Fuentes leídas: encargo, SAP y especificación. No se ha accedido a producción. ADAE utiliza `pharmaversesdtm::ae` y `qc/output/qc_adsl.rds`, derivado independientemente por QC.

- Se conservan todas las filas de AE: el filtro de seguridad corresponde a los análisis, no a la definición de ADAE.
- Las cadenas vacías o compuestas solo por espacios se convierten en `NA`. Las flags `TRTEMFL`, `ONTRTFL` y `DERMFL` usan `Y` o `NA`; la especificación solo define la condición de `Y`, sin definir el valor contrario. `ASTDTF` queda ausente cuando no se imputa.
- Para `ASTDT`, año-mes imputa el día 1 y usa `ASTDTF=D`; año solo imputa enero y día 1 y usa `ASTDTF=M`. No se imputa el año ni una fecha totalmente ausente. La corrección a `TRTSDT` solo se aplica a fechas parciales anteriores a `TRTSDT` cuyo mes y año, después de imputar, coincidan con los de `TRTSDT`. No se alteran fechas completas pretratamiento. El SAP no especifica explícitamente si el mes que debe coincidir puede ser un enero imputado: se interpreta como el mes de la fecha imputada.
- Para `AENDT`, año-mes imputa el último día real de ese mes; año solo imputa el 31 de diciembre. Los componentes horarios, si existen, no forman parte de las fechas de análisis. No se solicita una flag de imputación del final.
- La definición general «en tratamiento» del SAP menciona `TRTEDT`; se aplica su excepción por fin de exposición ausente mediante `LSTEXDT`, tal como exige explícitamente `ONTRTFL` en la especificación.
- `TRTEMFL` se deriva literalmente con `TRTEDT + 30`. Si falta `TRTEDT`, no se sustituye por `LSTEXDT` y no se asigna `Y`. La regla de último día conocido permite la imputación para el análisis principal y `ONTRTFL`, pero no especifica inequívocamente su extensión a la ventana TEAE. Esta ambigüedad puede afectar a los recuentos de seguridad y requiere quedar visible en la comparación.
- `DERMFL` incluye el SOC exacto de piel y cualquier término preferente que empiece por `APPLICATION SITE`, conforme a ambas fuentes.
- Los tipos R son `character`, `integer` y `Date`; se conservan el orden de variables, etiquetas `label` y longitudes `sas_length` indicadas en el CSV. Las longitudes se validan sin truncar valores.

## Comprobaciones y estado de ejecución

El programa comprueba claves AE y ADSL únicas, correspondencia de sujetos AE/ADSL, clases Date en ADSL, fechas de calendario válidas, cardinalidad conservada, variables y orden exactos, longitudes máximas y las 26 fechas de inicio parciales indicadas en el SAP. Informa el reparto D/M, las correcciones a TRTSDT, los tres recuentos de flags y lista las fechas parciales. Si algún final precede al inicio, emite una advertencia conservando las fechas derivadas para que la anomalía pueda investigarse.

El intento de ejecutar el Rscript indicado en el encargo produjo `Acceso denegado` antes de iniciar R. Por ello no se han observado aún los datos ni confirmado empíricamente las 26 fechas parciales, y no se ha generado el RDS desde este agente. Las comprobaciones anteriores están implementadas y pendientes de ejecución; no constituyen resultados superados.
