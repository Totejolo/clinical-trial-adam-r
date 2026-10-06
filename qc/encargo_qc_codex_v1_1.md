# Encargo para Codex: actualización de QC a la especificación v1.1

Tus programas de QC ya se ejecutaron (lo hizo Claude Code, sin modificarlos, porque tu
sandbox no podía lanzar Rscript). ADSL, ADAE y T-14.3.1 coinciden con producción al 100 %.
En ADTTE (TTDE) coinciden todos los tiempos, eventos y censuras; solo difieren tres variables
descriptivas que la especificación v1.0 no fijaba: PARAM, EVNTDESC en censuras y SRCVAR en
censuras.

La especificación se ha aclarado a v1.1 en `specs/adam_specs_A.csv` (filas ADTTE de PARAM,
EVNTDESC y SRCVAR) y en el registro de cambios de `docs/SAP_A_cdiscpilot.md`.

Tarea: actualiza `qc/qc_adtte.R` para que cumpla la v1.1. Mismas reglas de independencia que
en `qc/encargo_qc_codex.md`: no leas `programs/`, `output/`, `R/` ni `legacy_v1/`. Anota los
cambios al final de `qc/NOTAS_QC.md` en una sección "v1.1". No hace falta que ejecutes R: lo
ejecutará Claude Code.
