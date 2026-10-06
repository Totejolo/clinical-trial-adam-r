# SAP, parte B: eficacia en el ensayo de quimioterapia adyuvante de colon

Versión 1.0, fijada antes de programar el análisis.

## 1. Datos

- Fuente: `survival::colon`. Datos reales de pacientes del ensayo de levamisol con o sin
  5-fluorouracilo tras resección de cáncer de colon en estadio C (Moertel et al.). 929
  pacientes, dos filas por paciente (recurrencia y muerte).
- Brazos: observación (Obs), levamisol (Lev) y levamisol + 5-FU (Lev+5FU).
- No hay fechas de calendario: los tiempos vienen en días desde la aleatorización. No hay
  SDTM: se construye una estructura ADaM (ADSL, ADTTE) directamente desde los datos
  originales, documentando cada regla (conversión de datos heredados).
- Las cifras publicadas para validar están en `docs/dossier_literatura_colon.md`.

## 2. Variables

| Endpoint | Definición | Censura |
|---|---|---|
| OS (principal) | Muerte por cualquier causa | Último seguimiento |
| RFS | Recurrencia o muerte, lo que ocurra antes | Último seguimiento |
| TTR | Recurrencia; la muerte sin recurrencia es evento competitivo | Último seguimiento |

Covariables basales: edad, sexo, obstrucción, perforación, adherencia a órganos vecinos,
número de ganglios positivos (y > 4), diferenciación, extensión local, tiempo desde la
cirugía hasta el registro.

## 3. Comparaciones

- Principal: Lev+5FU frente a Obs.
- Secundaria: Lev frente a Obs. Exploratoria: Lev+5FU frente a Lev.
- Sin corrección por multiplicidad: solo la comparación principal tiene carácter
  confirmatorio; el resto se presenta como descriptivo.

## 4. Análisis

1. Kaplan-Meier por brazo, log-rank, supervivencia a 5 años con IC 95 %.
2. Cox sin ajustar y ajustado por las covariables basales; HR con IC 95 %.
3. Riesgos proporcionales: residuos de Schoenfeld. Si se violan, HR por periodos
   (0-2 años, > 2 años) y RMST.
4. RMST a 5 años: diferencia de tiempo medio restringido entre brazos, con IC 95 %.
5. TTR con riesgos competitivos: incidencia acumulada de Aalen-Johansen para recurrencia y
   para muerte sin recurrencia; Cox por causa y Fine-Gray.
6. Subgrupos de OS (sexo, edad ≥ 65, > 4 ganglios, obstrucción, extensión, diferenciación):
   HR de Lev+5FU frente a Obs en cada subgrupo y p de interacción. Exploratorio.
7. Validación externa: comparación de las reducciones de riesgo con las publicadas.

## 5. Tablas y figuras

| ID | Contenido |
|---|---|
| T-B1 | Características basales por brazo |
| T-B2 | Resumen de eficacia: eventos, mediana, supervivencia a 5 años, HR, RMST |
| T-B3 | Riesgos competitivos para TTR |
| T-B4 | Comparación con lo publicado |
| F-B1 | Kaplan-Meier de OS y RFS |
| F-B2 | Incidencia acumulada de recurrencia y de muerte sin recurrencia |
| F-B3 | Forest plot de subgrupos |

## Registro de cambios

- v1.0 (2026-10-05): versión inicial.
