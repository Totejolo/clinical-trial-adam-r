# Encargo para Codex: programación de QC independiente (parte A)

Eres el programador de QC. En una CRO, el QC se hace con doble programación: tú derivas los
mismos datasets a partir de la especificación, sin mirar el código de producción, y luego se
comparan. Si tu entorno permite subagentes, úsalos (por ejemplo: uno para ADSL, otro para
ADTTE y TEAE, y un revisor que compruebe tus programas contra la especificación).

## Reglas de independencia

- NO leas nada de `programs/`, `output/`, `R/` ni `legacy_v1/`. Son el código
  de producción.
- Solo puedes leer: `docs/SAP_A_cdiscpilot.md`, `specs/adam_specs_A.csv` y este archivo.
- Escribe todo dentro de `qc/`.
- Usa `dplyr`, `lubridate` y R base. No uses `admiral` (producción lo usa; así el QC es
  realmente independiente).

## Entorno

- Rscript: `C:/Users/Usuario/AppData/Local/Programs/R/R-4.6.1/bin/x64/Rscript.exe`
- Paquetes instalados: `pharmaversesdtm`, `dplyr`, `tidyr`, `lubridate`, `stringr`,
  `survival`, `diffdf`.
- Datos: `pharmaversesdtm::dm`, `ex`, `ae`, `ds`. Convierte cadenas vacías a `NA`.

## Entregables (en `qc/`)

1. `qc_adsl.R` -> `qc/output/qc_adsl.rds`: todas las variables ADSL de la especificación.
2. `qc_adae.R` -> `qc/output/qc_adae.rds`: todas las variables ADAE de la especificación.
3. `qc_adtte.R` -> `qc/output/qc_adtte.rds`: solo `PARAMCD = "TTDE"` (estimando principal),
   con todas las variables ADTTE de la especificación, una fila por sujeto de seguridad.
4. `qc_t14_3_1.R` -> `qc/output/qc_t14_3_1.csv`: número de sujetos por `TRT01A` para cada
   fila de T-14.3.1 (definiciones en la sección 7 del SAP). Columnas: `fila`, `TRT01A`, `n`.
5. `qc/NOTAS_QC.md`: cada regla que hayas tenido que interpretar, y cualquier ambigüedad o
   contradicción que encuentres en el SAP o la especificación.

Ejecuta tus programas con Rscript y comprueba que se generan sin errores. Las fechas como
clase `Date`. Ordena por `USUBJID` (y `AESEQ` en ADAE).
