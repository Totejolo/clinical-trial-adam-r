# SAP, parte A: seguridad dermatológica en CDISCPILOT01

Versión 1.0, fijada antes de programar el análisis. Cualquier cambio posterior se
documenta al final con fecha y motivo.

## 1. Datos y estudio

- Fuente: `pharmaversesdtm` (datos públicos y sintéticos del piloto CDISC). Dominios DM,
  EX, AE y DS.
- Ensayo: xanomelina en parche transdérmico (dosis baja 54 mg, dosis alta 81 mg) frente a
  placebo, en enfermedad de Alzheimer.
- Población de análisis: seguridad (`SAFFL = "Y"`, al menos una dosis), analizada por
  tratamiento recibido (`TRT01A`).

## 2. Estimando principal (ICH E9(R1))

| Atributo | Definición |
|---|---|
| Tratamiento | Xanomelina dosis baja o alta frente a placebo |
| Población | Pacientes que recibieron al menos una dosis |
| Variable | Tiempo desde la primera dosis hasta el primer evento adverso dermatológico |
| Evento intercurrente | Fin o interrupción del tratamiento: estrategia *while on treatment* (solo cuenta lo ocurrido en tratamiento; se censura al terminarlo) |
| Medida resumen | Incidencia acumulada a las semanas 12 y 24 (1 − Kaplan-Meier) y hazard ratio de Cox frente a placebo |

## 3. Definiciones

- **Evento adverso dermatológico:** `AEBODSYS = "SKIN AND SUBCUTANEOUS TISSUE DISORDERS"` o
  `AEDECOD` que empieza por `"APPLICATION SITE"`. Las reacciones en el lugar de aplicación
  se incluyen porque el fármaco se administra en parche.
- **En tratamiento:** fecha de inicio del evento entre `TRTSDT` y `TRTEDT`, ambos incluidos.
- **Evento emergente (TEAE):** inicio entre `TRTSDT` y `TRTEDT + 30` días. Se usa en las
  tablas de seguridad y en la sensibilidad S1.
- **Fecha de inicio parcial:** día ausente → día 1; mes ausente → enero; nunca antes de
  `TRTSDT` si el mes y el año coinciden con el inicio del tratamiento. Se marca con `ASTDTF`.
- **Fin de exposición ausente:** si `TRTEDT` falta, el último día conocido en tratamiento es
  la fecha de inicio de la última administración registrada en EX.

## 4. Censura

- Sin evento: censura en `TRTEDT` (o en la regla anterior si falta).
- Cada censura lleva su motivo: tratamiento completado, interrupción por evento adverso,
  otra interrupción.

## 5. Análisis

1. Incidencia acumulada por brazo (1 − KM) con IC 95 %, en riesgo a las semanas 12 y 24.
2. Log-rank de los tres brazos.
3. Cox con brazo y edad; HR frente a placebo con IC 95 %. Contraste dosis alta frente a
   dosis baja. Tendencia con la dosis (0, 54, 81 mg) como variable continua.
4. Riesgos proporcionales: residuos de Schoenfeld por término y global.

## 6. Sensibilidades

| Código | Cambio respecto al principal | Pregunta |
|---|---|---|
| S1 | Ventana TEAE (+30 días) y censura en `TRTEDT + 30` o fin de estudio, lo que ocurra antes | ¿Depende el resultado de la ventana? |
| S2 | Solo el órgano-sistema de piel, sin reacciones en el lugar de aplicación | ¿Depende de la definición de evento? |
| S3 | Interrupción del tratamiento sin evento previo como evento competitivo; incidencia acumulada de Aalen-Johansen | Proporción con evento de piel antes de interrumpir, sin suponer censura no informativa |
| S4 | Fechas parciales imputadas al último día posible | ¿Depende de la imputación? |
| S5 | Fin de exposición ausente: fin de estudio en lugar de última administración | ¿Depende de la regla de los dos sujetos sin fecha de fin? |

S3 responde a otro estimando: la interrupción del tratamiento sin evento previo se trata
como evento competitivo (riesgos competitivos), en lugar de como censura. Se presenta como
complemento, no como sustituto.

## 7. Tablas, listados y figuras

| ID | Contenido |
|---|---|
| T-14.1.1 | Características basales por brazo (edad, grupo de edad, sexo, raza) |
| T-14.3.1 | Resumen de TEAE: cualquiera, graves, relacionados, que llevan a interrupción, mortales |
| T-14.3.2 | TEAE por órgano-sistema y término preferente (≥ 5 % en algún brazo) |
| T-14.3.3 | Tiempo hasta el primer evento dermatológico: eventos, censuras por motivo, incidencia a semanas 12 y 24, HR |
| T-14.3.4 | Sensibilidades S1 a S5 |
| F-14.3.1 | Incidencia acumulada por brazo con tabla de sujetos en riesgo |
| F-14.3.2 | Curvas de Aalen-Johansen (S3) |

Definiciones de T-14.3.1 (sujetos, población de seguridad, TEAE según la sección 3):
cualquier TEAE; TEAE grave (`AESER = "Y"`); TEAE relacionado (`AEREL` en `POSSIBLE` o
`PROBABLE`); TEAE mortal (`AEOUT = "FATAL"`); interrupción del estudio por evento adverso
(`DCSREAS = "ADVERSE EVENT"` en ADSL, porque `AEACN` está vacío en estos datos). 26
registros de AE tienen fecha de inicio parcial.

## 8. Control de calidad

- Doble programación independiente de ADSL, ADTTE y T-14.3.1 (Codex, sin acceso al código
  de producción), comparada con `diffdf`.
- Comprobaciones automáticas: unicidad de claves, rangos de fechas, correspondencia entre
  `CNSR` y su fuente, recuentos.
- ADSL, ADAE y ADTTE exportados a XPT v5 con etiquetas, tipos y longitudes de la
  especificación (`xportr`).

## Registro de cambios

- v1.0 (2026-10-05): versión inicial.
- v1.1 (2026-10-06): tras la doble programación, la especificación fija los literales de
  PARAM y EVNTDESC y la regla de SRCVAR en censuras (TRTEDT cuando existe; LSTEXDT solo
  cuando se sustituye; EOSDT cuando la fecha sale de ahí). No cambia ningún tiempo, evento ni
  censura. Se aclara también que S3 es un análisis de riesgos competitivos (Aalen-Johansen),
  no una estrategia compuesta.
