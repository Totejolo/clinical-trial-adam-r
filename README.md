# Clinical trial analysis end to end in R (pharmaverse)

Two public trials, analysed the way a CRO would: statistical analysis plan first, variable
specification, ADaM datasets, tables and figures, SAS transport files, sensitivity analyses
and independent double programming.

| Part | Data | Question |
|---|---|---|
| A. Safety | CDISC pilot study (`pharmaversesdtm`, synthetic): xanomeline patch vs placebo, 254 treated subjects | Time to first dermatologic adverse event |
| B. Efficacy | Adjuvant colon cancer trial (`survival::colon`, real patient-level data): 929 stage III patients, observation vs levamisole vs levamisole + 5-FU | Overall survival, recurrence-free survival, time to recurrence with competing death |

## Key results

**Part A**
- Hazard ratios vs placebo (Cox, age-adjusted): low dose 4.30 (2.74 to 6.74), high dose 5.47 (3.46 to 8.66). High vs low dose: 1.27 (0.89 to 1.82), p = 0.18, so a dose gradient is not established.
- How discontinuation is handled changes the answer: at week 12 in the low-dose arm, 1 − Kaplan-Meier (discontinuation as censoring) estimates 78.6 %; Aalen-Johansen with discontinuation without a prior event as a competing event estimates 59.4 %. They answer different questions; the gap shows how much rests on the censoring assumption.
- The event definition matters more than any other choice: counting only the skin system organ class (without application-site reactions) cuts events from 29/63/60 to 19/37/39.

**Part B, validated against the final report** (Moertel et al., Ann Intern Med 1995)

| Comparison | Endpoint | Published reduction | This analysis (1 − HR) |
|---|---|---|---|
| Lev+5FU vs observation | Recurrence | 40 % | 40 % |
| Lev+5FU vs observation | Death | 33 % | 31 % |
| Levamisole vs observation | Recurrence | 2 % | 2 % |
| Levamisole vs observation | Death | 6 % | 3 % |

An independent literature check (Claude Science, `docs/claude_science/`) confirmed the
published figures against PubMed and CrossRef, reran the Cox models on the same data with
identical hazard ratios, and found citation errors in the `survival` 3.8.12 help page for
`colon` (NEJM volume 332 instead of 322; final report described as stage II, 1991 instead of
stage III, 1995).

## Quality control

Production code uses `{admiral}`. An independent QC programmer (Codex) derived ADSL, ADAE,
ADTTE and the TEAE summary table from the SAP and specification only, with `dplyr` and base
R, without access to production code. The first comparison exposed three underspecified
variables; the specification was clarified (v1.1, logged in the SAP) and all four
deliverables now match value by value (`diffdf`). See `output/A/qc/informe_qc.md`.

## Structure

```
docs/       Statistical analysis plans (A, B) and literature dossier
specs/      ADaM variable specification (part A)
programs/   A_cdiscpilot (a01-a08) and B_colon (b01-b04)
qc/         Independent double programming and QC notes
output/     Datasets (.rds, .xpt), tables, figures, QC report
tests/      testthat checks of the critical derivation rules
legacy_v1/  First version, kept for traceability
```

## Run

```r
# from the project folder
source("run_all.R")
```

Packages: admiral, pharmaversesdtm, pharmaverseadam, dplyr, tidyr, lubridate, stringr,
survival, ggsurvfit, tidycmprsk, rtables, tern, xportr, diffdf, forestploter, testthat.

## How this was built

The code was written by AI agents (Claude Code for production, Codex as independent QC
programmer) under the direction of Jorge Sánchez Germán. Every analytical decision is
written down in the SAPs before the code that implements it. Synthetic and public data
only; no real patient data from any hospital.
