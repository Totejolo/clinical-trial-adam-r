# a01_adsl.R
# ADSL: una fila por sujeto. Reglas en specs/adam_specs_A.csv y docs/SAP_A_cdiscpilot.md.

suppressPackageStartupMessages({
  library(admiral)
  library(dplyr, warn.conflicts = FALSE)
  library(lubridate)
  library(stringr)
})
source("R/funciones.R")

dm <- convert_blanks_to_na(pharmaversesdtm::dm)
ds <- convert_blanks_to_na(pharmaversesdtm::ds)
ex <- convert_blanks_to_na(pharmaversesdtm::ex)

dosis_n <- c("Placebo" = 0, "Xanomeline Low Dose" = 54, "Xanomeline High Dose" = 81)

adsl <- dm %>%
  select(-DOMAIN) %>%
  mutate(
    TRT01P = ARM,
    TRT01A = ACTARM,
    TRT01PN = unname(dosis_n[TRT01P]),
    TRT01AN = unname(dosis_n[TRT01A])
  )

# Exposición: cuenta como dosis todo registro con dosis > 0, o placebo.
# La hora ausente se imputa al principio (inicio) o al final (fin) del día; la fecha nunca.
ex_ext <- ex %>%
  filter(EXDOSE > 0 | (EXDOSE == 0 & str_detect(EXTRT, "PLACEBO"))) %>%
  derive_vars_dtm(dtc = EXSTDTC, new_vars_prefix = "EXST") %>%
  derive_vars_dtm(dtc = EXENDTC, new_vars_prefix = "EXEN", time_imputation = "last") %>%
  mutate(EXSTDT = as.Date(EXSTDTM))

adsl <- adsl %>%
  derive_vars_merged(
    dataset_add = ex_ext,
    filter_add = !is.na(EXSTDTM),
    new_vars = exprs(TRTSDTM = EXSTDTM),
    order = exprs(EXSTDTM, EXSEQ),
    mode = "first",
    by_vars = exprs(STUDYID, USUBJID)
  ) %>%
  derive_vars_merged(
    dataset_add = ex_ext,
    filter_add = !is.na(EXENDTM),
    new_vars = exprs(TRTEDTM = EXENDTM),
    order = exprs(EXENDTM, EXSEQ),
    mode = "last",
    by_vars = exprs(STUDYID, USUBJID)
  ) %>%
  # Última administración conocida, para los sujetos sin fecha de fin en EX
  derive_vars_merged(
    dataset_add = ex_ext,
    filter_add = !is.na(EXSTDT),
    new_vars = exprs(LSTEXSDT = EXSTDT),
    order = exprs(EXSTDT, EXSEQ),
    mode = "last",
    by_vars = exprs(STUDYID, USUBJID)
  ) %>%
  derive_vars_dtm_to_dt(source_vars = exprs(TRTSDTM, TRTEDTM)) %>%
  derive_var_trtdurd() %>%
  mutate(LSTEXDT = coalesce(TRTEDT, LSTEXSDT))

# Disposición: fin de estudio, estado y motivo de abandono
ds_disp <- ds %>%
  filter(DSCAT == "DISPOSITION EVENT") %>%
  derive_vars_dt(dtc = DSSTDTC, new_vars_prefix = "DSST")

adsl <- adsl %>%
  derive_vars_merged(
    dataset_add = ds_disp,
    filter_add = DSDECOD != "SCREEN FAILURE",
    new_vars = exprs(EOSDT = DSSTDT),
    by_vars = exprs(STUDYID, USUBJID)
  ) %>%
  derive_vars_merged(
    dataset_add = ds_disp,
    new_vars = exprs(EOSSTT = case_when(
      DSDECOD == "COMPLETED" ~ "COMPLETED",
      DSDECOD == "SCREEN FAILURE" ~ NA_character_,
      TRUE ~ "DISCONTINUED"
    )),
    missing_values = exprs(EOSSTT = "ONGOING"),
    by_vars = exprs(STUDYID, USUBJID)
  ) %>%
  derive_vars_merged(
    dataset_add = ds_disp,
    filter_add = !(DSDECOD %in% c("COMPLETED", "SCREEN FAILURE")),
    new_vars = exprs(DCSREAS = DSDECOD),
    by_vars = exprs(STUDYID, USUBJID)
  ) %>%
  derive_vars_merged(
    dataset_add = derive_vars_dt(ds, dtc = DSSTDTC, new_vars_prefix = "DSST"),
    filter_add = DSDECOD == "RANDOMIZED",
    new_vars = exprs(RANDDT = DSSTDT),
    by_vars = exprs(STUDYID, USUBJID)
  )

# Población de seguridad y grupo de edad
adsl <- adsl %>%
  derive_var_merged_exist_flag(
    dataset_add = ex_ext,
    by_vars = exprs(STUDYID, USUBJID),
    new_var = SAFFL,
    condition = TRUE,
    false_value = "N",
    missing_value = "N"
  ) %>%
  mutate(AGEGR1 = case_when(AGE <= 64 ~ "18-64", AGE > 64 ~ ">64"))

specs <- leer_specs()
adsl <- adsl %>% select(all_of(vars_spec(specs, "ADSL")))

comprobar_clave(adsl, "USUBJID", "ADSL")
stopifnot(
  all(adsl$SAFFL == "Y" | adsl$TRT01A == "Screen Failure"),
  all(!is.na(adsl$LSTEXDT[adsl$SAFFL == "Y"])),
  all(adsl$LSTEXDT >= adsl$TRTSDT, na.rm = TRUE)
)

dir.create("output/A/datasets", recursive = TRUE, showWarnings = FALSE)
saveRDS(adsl, "output/A/datasets/adsl.rds")
cat("ADSL:", nrow(adsl), "sujetos;", sum(adsl$SAFFL == "Y"), "en seguridad;",
    sum(is.na(adsl$TRTEDT) & adsl$SAFFL == "Y"), "sin TRTEDT\n")
