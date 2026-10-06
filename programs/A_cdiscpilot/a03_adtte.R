# a03_adtte.R
# ADTTE: tiempo hasta el primer evento adverso dermatológico.
# Un parámetro principal (TTDE) y cuatro de sensibilidad (SAP, sección 6).

suppressPackageStartupMessages({
  library(admiral)
  library(dplyr, warn.conflicts = FALSE)
  library(stringr)
})
source("R/funciones.R")

adsl <- readRDS("output/A/datasets/adsl.rds")
adae <- readRDS("output/A/datasets/adae.rds")
ae <- convert_blanks_to_na(pharmaversesdtm::ae)

# Motivo de censura y fechas de censura de cada análisis
adsl_tte <- adsl %>%
  filter(SAFFL == "Y") %>%
  mutate(
    CNSDTDSC = case_when(
      EOSSTT == "COMPLETED" ~ "TRATAMIENTO COMPLETADO",
      DCSREAS == "ADVERSE EVENT" ~ "INTERRUPCION POR EA",
      TRUE ~ "OTRA INTERRUPCION"
    ),
    CNS_TTDE = LSTEXDT,
    CNS_TTDE30 = pmin(LSTEXDT + 30, coalesce(EOSDT, LSTEXDT + 30)),
    CNS_TTDEEOS = coalesce(TRTEDT, EOSDT)
  )

# Fecha de inicio imputada al último día posible (S4)
ast_ultima <- ae %>%
  derive_vars_dt(
    new_vars_prefix = "ASTL",
    dtc = AESTDTC,
    highest_imputation = "M",
    date_imputation = "last",
    flag_imputation = "none"
  ) %>%
  select(USUBJID, AESEQ, ASTLDT)

# Marcas de evento de cada análisis
adae_tte <- adae %>%
  inner_join(
    select(adsl_tte, USUBJID, TRTSDT, LSTEXDT, CNS_TTDE30, CNS_TTDEEOS),
    by = "USUBJID"
  ) %>%
  left_join(ast_ultima, by = c("USUBJID", "AESEQ")) %>%
  mutate(
    SKINFL = AEBODSYS == "SKIN AND SUBCUTANEOUS TISSUE DISORDERS",
    EV_TTDE = DERMFL %in% "Y" & ONTRTFL %in% "Y",
    EV_TTDE30 = DERMFL %in% "Y" & ASTDT >= TRTSDT & ASTDT <= CNS_TTDE30,
    EV_TTDESOC = SKINFL & ONTRTFL %in% "Y",
    EV_TTDEIMPL = DERMFL %in% "Y" & ASTLDT >= TRTSDT & ASTLDT <= LSTEXDT,
    EV_TTDEEOS = DERMFL %in% "Y" & ASTDT >= TRTSDT & ASTDT <= CNS_TTDEEOS
  )

derivar_tte <- function(paramcd, param, marca_ev, fecha_ev, fecha_cens) {
  evento <- event_source(
    dataset_name = "adae",
    filter = !!rlang::sym(marca_ev) == TRUE,
    date = !!rlang::sym(fecha_ev),
    order = exprs(AESEQ),
    set_values_to = exprs(
      EVNTDESC = "PRIMER EVENTO DERMATOLOGICO",
      SRCDOM = "ADAE",
      SRCVAR = !!fecha_ev,
      SRCSEQ = AESEQ
    )
  )
  censura <- censor_source(
    dataset_name = "adsl",
    date = !!rlang::sym(fecha_cens),
    set_values_to = exprs(
      EVNTDESC = paste("CENSURA:", CNSDTDSC),
      CNSDTDSC = CNSDTDSC,
      SRCDOM = "ADSL",
      SRCVAR = "LSTEXDT"
    )
  )
  derive_param_tte(
    dataset_adsl = adsl_tte,
    source_datasets = list(adsl = adsl_tte, adae = adae_tte),
    start_date = TRTSDT,
    event_conditions = list(evento),
    censor_conditions = list(censura),
    set_values_to = exprs(PARAMCD = !!paramcd, PARAM = !!param)
  )
}

adtte <- bind_rows(
  derivar_tte("TTDE", "Tiempo hasta el primer EA dermatologico en tratamiento (dias)",
              "EV_TTDE", "ASTDT", "CNS_TTDE"),
  derivar_tte("TTDE30", "Tiempo hasta el primer EA dermatologico, ventana TEAE +30 dias (dias)",
              "EV_TTDE30", "ASTDT", "CNS_TTDE30"),
  derivar_tte("TTDESOC", "Tiempo hasta el primer EA de piel, solo SOC (dias)",
              "EV_TTDESOC", "ASTDT", "CNS_TTDE"),
  derivar_tte("TTDEIMPL", "Tiempo hasta el primer EA dermatologico, imputacion al ultimo dia (dias)",
              "EV_TTDEIMPL", "ASTLDT", "CNS_TTDE"),
  derivar_tte("TTDEEOS", "Tiempo hasta el primer EA dermatologico, sin TRTEDT censura en EOSDT (dias)",
              "EV_TTDEEOS", "ASTDT", "CNS_TTDEEOS")
) %>%
  # Variable de ADSL de la que sale cada fecha de censura, sujeto a sujeto
  left_join(select(adsl_tte, USUBJID, TRTEDT, EOSDT, LSTEXDT), by = "USUBJID") %>%
  mutate(SRCVAR = case_when(
    CNSR == 0 ~ SRCVAR,
    PARAMCD == "TTDE30" & ADT == EOSDT & ADT != LSTEXDT + 30 ~ "EOSDT",
    PARAMCD == "TTDEEOS" & is.na(TRTEDT) ~ "EOSDT",
    !is.na(TRTEDT) ~ "TRTEDT",
    TRUE ~ "LSTEXDT"
  )) %>%
  select(-TRTEDT, -EOSDT, -LSTEXDT) %>%
  derive_vars_duration(new_var = AVAL, start_date = STARTDT, end_date = ADT) %>%
  derive_vars_merged(
    dataset_add = adsl,
    new_vars = exprs(TRT01A, TRT01AN, AGE),
    by_vars = exprs(STUDYID, USUBJID)
  )

specs <- leer_specs()
adtte <- adtte %>%
  select(all_of(vars_spec(specs, "ADTTE"))) %>%
  arrange(PARAMCD, USUBJID)

comprobar_clave(adtte, c("USUBJID", "PARAMCD"), "ADTTE")
n_saf <- sum(adsl$SAFFL == "Y")
stopifnot(
  all(table(adtte$PARAMCD) == n_saf),
  !anyNA(adtte$AVAL),
  all(adtte$AVAL >= 1),
  all(is.na(adtte$CNSDTDSC) == (adtte$CNSR == 0)),
  all(adtte$SRCDOM[adtte$CNSR == 0] == "ADAE")
)

saveRDS(adtte, "output/A/datasets/adtte.rds")
print(adtte %>% count(PARAMCD, TRT01A, EVENTO = CNSR == 0) %>%
        tidyr::pivot_wider(names_from = EVENTO, values_from = n, names_prefix = "evento_"))
