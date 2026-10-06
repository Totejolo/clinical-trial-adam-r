# QC: independent double programming

The programs in this folder were written by Codex acting as an independent QC programmer.
It read only `docs/SAP_A_cdiscpilot.md`, `specs/adam_specs_A.csv` and the brief
(`encargo_qc_codex.md`, `encargo_qc_codex_v1_1.md`), never the production code, and it used
`dplyr` and base R instead of `admiral`.

Codex's sandbox could not launch Rscript, so `NOTAS_QC.md` says the programs had not been run.
They were then run unmodified with Rscript (they are part of `run_all.R`), and the comparison
with production is in `output/A/qc/informe_qc.md`: after the v1.1 specification update, ADSL,
ADAE, ADTTE (TTDE) and T-14.3.1 match value by value.

`NOTAS_QC.md` is kept as written because it records every rule the QC programmer had to
interpret, which is the most useful output of a QC round.
