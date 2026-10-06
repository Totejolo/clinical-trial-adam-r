# 03_adtte.R
# ADTTE: tiempo hasta el primer evento adverso dermatológico durante el tratamiento.
#
# Decisiones (explicadas en GUIA.md):
# - Evento dermatológico = SOC "SKIN AND SUBCUTANEOUS TISSUE DISORDERS" o cualquier
#   reacción en el lugar de aplicación ("APPLICATION SITE ..."), porque el fármaco va en parche.
# - Solo cuentan eventos que empiezan entre el inicio y el fin del tratamiento.
# - Quien no tiene evento se censura en la fecha de fin de tratamiento. Dos sujetos no
#   tienen fecha de fin en EX (abandonaron la primera semana, sin eventos adversos):
#   se censuran en su fecha de fin de estudio.
# - Población: seguridad (SAFFL = "Y").

suppressPackageStartupMessages({
  library(admiral)
  library(dplyr, warn.conflicts = FALSE)
  library(stringr)
})

adsl <- readRDS("output/adsl.rds")
ae <- convert_blanks_to_na(pharmaversesdtm::ae)

# ADAE mínimo: fecha de inicio (imputando día y mes si faltan) y marcas del evento
adae <- ae %>%
  derive_vars_merged(
    dataset_add = adsl,
    new_vars = exprs(TRTSDT, TRTEDT),
    by_vars = exprs(STUDYID, USUBJID)
  ) %>%
  derive_vars_dt(
    new_vars_prefix = "AST",
    dtc = AESTDTC,
    highest_imputation = "M"
  ) %>%
  mutate(
    DERMFL = if_else(
      AEBODSYS == "SKIN AND SUBCUTANEOUS TISSUE DISORDERS" |
        str_detect(AEDECOD, "^APPLICATION SITE"),
      "Y", NA_character_
    ),
    ONTRTFL = if_else(
      !is.na(ASTDT) & ASTDT >= TRTSDT & ASTDT <= TRTEDT,
      "Y", NA_character_
    )
  )

evento_derm <- event_source(
  dataset_name = "adae",
  filter = DERMFL == "Y" & ONTRTFL == "Y",
  date = ASTDT,
  order = exprs(AESEQ),
  set_values_to = exprs(
    EVNTDESC = "PRIMER EVENTO DERMATOLOGICO",
    SRCDOM = "ADAE",
    SRCVAR = "ASTDT",
    SRCSEQ = AESEQ
  )
)

censura_fin_tto <- censor_source(
  dataset_name = "adsl",
  date = TRTEDT,
  set_values_to = exprs(
    EVNTDESC = "FIN DE TRATAMIENTO",
    SRCDOM = "ADSL",
    SRCVAR = "TRTEDT"
  )
)

censura_fin_estudio <- censor_source(
  dataset_name = "adsl",
  filter = is.na(TRTEDT),
  date = EOSDT,
  set_values_to = exprs(
    EVNTDESC = "FIN DE ESTUDIO (SIN FECHA DE FIN DE TRATAMIENTO)",
    SRCDOM = "ADSL",
    SRCVAR = "EOSDT"
  )
)

adtte <- derive_param_tte(
  dataset_adsl = filter(adsl, SAFFL == "Y"),
  source_datasets = list(adsl = adsl, adae = adae),
  start_date = TRTSDT,
  event_conditions = list(evento_derm),
  censor_conditions = list(censura_fin_tto, censura_fin_estudio),
  set_values_to = exprs(
    PARAMCD = "TTDE",
    PARAM = "Tiempo hasta el primer evento dermatologico (dias)"
  )
) %>%
  derive_vars_duration(
    new_var = AVAL,
    start_date = STARTDT,
    end_date = ADT
  ) %>%
  derive_vars_merged(
    dataset_add = adsl,
    new_vars = exprs(TRT01A, AGE, SEX, AGEGR1),
    by_vars = exprs(STUDYID, USUBJID)
  )

saveRDS(adae, "output/adae_min.rds")
saveRDS(adtte, "output/adtte.rds")

cat("ADTTE:", nrow(adtte), "sujetos\n")
print(count(adtte, TRT01A, EVENTO = CNSR == 0))
stopifnot(
  nrow(adtte) == sum(adsl$SAFFL == "Y"),
  !anyNA(adtte$AVAL),
  all(adtte$AVAL >= 1)
)
