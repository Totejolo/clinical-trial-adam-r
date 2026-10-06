# 02_adsl.R
# ADSL: una fila por sujeto con brazo de tratamiento, fechas clave y poblaciones de análisis.

suppressPackageStartupMessages({
  library(admiral)
  library(dplyr, warn.conflicts = FALSE)
  library(lubridate)
  library(stringr)
})

dm <- convert_blanks_to_na(pharmaversesdtm::dm)
ds <- convert_blanks_to_na(pharmaversesdtm::ds)
ex <- convert_blanks_to_na(pharmaversesdtm::ex)

# Brazo planificado (ARM) y brazo realmente recibido (ACTARM)
adsl <- dm %>%
  select(-DOMAIN) %>%
  mutate(TRT01P = ARM, TRT01A = ACTARM)

# Inicio y fin de tratamiento a partir de EX.
# Cuenta como dosis todo registro con dosis > 0, o placebo.
# Si falta la hora se imputa al principio del día en el inicio y al final en el fin.
# La fecha no se imputa nunca.
ex_ext <- ex %>%
  derive_vars_dtm(dtc = EXSTDTC, new_vars_prefix = "EXST") %>%
  derive_vars_dtm(dtc = EXENDTC, new_vars_prefix = "EXEN", time_imputation = "last")

adsl <- adsl %>%
  derive_vars_merged(
    dataset_add = ex_ext,
    filter_add = (EXDOSE > 0 | (EXDOSE == 0 & str_detect(EXTRT, "PLACEBO"))) &
      !is.na(EXSTDTM),
    new_vars = exprs(TRTSDTM = EXSTDTM, TRTSTMF = EXSTTMF),
    order = exprs(EXSTDTM, EXSEQ),
    mode = "first",
    by_vars = exprs(STUDYID, USUBJID)
  ) %>%
  derive_vars_merged(
    dataset_add = ex_ext,
    filter_add = (EXDOSE > 0 | (EXDOSE == 0 & str_detect(EXTRT, "PLACEBO"))) &
      !is.na(EXENDTM),
    new_vars = exprs(TRTEDTM = EXENDTM, TRTETMF = EXENTMF),
    order = exprs(EXENDTM, EXSEQ),
    mode = "last",
    by_vars = exprs(STUDYID, USUBJID)
  ) %>%
  derive_vars_dtm_to_dt(source_vars = exprs(TRTSDTM, TRTEDTM)) %>%
  derive_var_trtdurd()

# Fin de estudio: fecha y estado (completado, abandono o en curso)
ds_ext <- derive_vars_dt(ds, dtc = DSSTDTC, new_vars_prefix = "DSST")

format_eosstt <- function(x) {
  case_when(
    x %in% "COMPLETED" ~ "COMPLETED",
    x %in% "SCREEN FAILURE" ~ NA_character_,
    TRUE ~ "DISCONTINUED"
  )
}

adsl <- adsl %>%
  derive_vars_merged(
    dataset_add = ds_ext,
    by_vars = exprs(STUDYID, USUBJID),
    new_vars = exprs(EOSDT = DSSTDT),
    filter_add = DSCAT == "DISPOSITION EVENT" & DSDECOD != "SCREEN FAILURE"
  ) %>%
  derive_vars_merged(
    dataset_add = ds,
    by_vars = exprs(STUDYID, USUBJID),
    filter_add = DSCAT == "DISPOSITION EVENT",
    new_vars = exprs(EOSSTT = format_eosstt(DSDECOD)),
    missing_values = exprs(EOSSTT = "ONGOING")
  ) %>%
  derive_vars_merged(
    dataset_add = ds_ext,
    filter_add = DSDECOD == "RANDOMIZED",
    by_vars = exprs(STUDYID, USUBJID),
    new_vars = exprs(RANDDT = DSSTDT)
  )

# Población de seguridad: al menos una dosis (de fármaco o placebo)
adsl <- adsl %>%
  derive_var_merged_exist_flag(
    dataset_add = ex,
    by_vars = exprs(STUDYID, USUBJID),
    new_var = SAFFL,
    condition = (EXDOSE > 0 | (EXDOSE == 0 & str_detect(EXTRT, "PLACEBO"))),
    false_value = "N",
    missing_value = "N"
  )

# Grupo de edad, con los mismos cortes que el ADSL de referencia
adsl <- adsl %>%
  mutate(AGEGR1 = case_when(
    AGE < 18 ~ "<18",
    AGE <= 64 ~ "18-64",
    AGE > 64 ~ ">64"
  ))

dir.create("output", showWarnings = FALSE)
saveRDS(adsl, "output/adsl.rds")

cat("ADSL:", nrow(adsl), "sujetos,", sum(adsl$SAFFL == "Y"), "en población de seguridad\n")
print(count(adsl, TRT01A, SAFFL))
