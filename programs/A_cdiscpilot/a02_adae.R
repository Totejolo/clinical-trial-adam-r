# a02_adae.R
# ADAE: una fila por evento adverso, con fechas de análisis, imputación y marcas del SAP.

suppressPackageStartupMessages({
  library(admiral)
  library(dplyr, warn.conflicts = FALSE)
  library(stringr)
})
source("R/funciones.R")

adsl <- readRDS("output/A/datasets/adsl.rds")
ae <- convert_blanks_to_na(pharmaversesdtm::ae)

adae <- ae %>%
  derive_vars_merged(
    dataset_add = adsl,
    new_vars = exprs(TRTSDT, TRTEDT, LSTEXDT, TRT01A, TRT01AN, SAFFL),
    by_vars = exprs(STUDYID, USUBJID)
  ) %>%
  # Inicio: día ausente -> 1, mes ausente -> enero, nunca antes de TRTSDT si coincide el periodo
  derive_vars_dt(
    new_vars_prefix = "AST",
    dtc = AESTDTC,
    highest_imputation = "M",
    date_imputation = "first",
    flag_imputation = "auto",
    min_dates = exprs(TRTSDT)
  ) %>%
  # Fin: día ausente -> último del mes, mes ausente -> diciembre
  derive_vars_dt(
    new_vars_prefix = "AEN",
    dtc = AEENDTC,
    highest_imputation = "M",
    date_imputation = "last",
    flag_imputation = "none"
  ) %>%
  mutate(
    TRTEMFL = if_else(!is.na(ASTDT) & ASTDT >= TRTSDT & ASTDT <= TRTEDT + 30, "Y", NA_character_),
    ONTRTFL = if_else(!is.na(ASTDT) & ASTDT >= TRTSDT & ASTDT <= LSTEXDT, "Y", NA_character_),
    DERMFL = if_else(
      AEBODSYS == "SKIN AND SUBCUTANEOUS TISSUE DISORDERS" | str_detect(AEDECOD, "^APPLICATION SITE"),
      "Y", NA_character_
    )
  )

specs <- leer_specs()
adae <- adae %>%
  select(all_of(vars_spec(specs, "ADAE"))) %>%
  arrange(USUBJID, AESEQ)

comprobar_clave(adae, c("USUBJID", "AESEQ"), "ADAE")
stopifnot(all(!is.na(adae$ASTDT)))

saveRDS(adae, "output/A/datasets/adae.rds")
cat("ADAE:", nrow(adae), "eventos;", sum(adae$TRTEMFL %in% "Y"), "TEAE;",
    sum(!is.na(adae$ASTDTF)), "con fecha de inicio imputada\n")
