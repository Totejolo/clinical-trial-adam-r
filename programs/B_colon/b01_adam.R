# b01_adam.R
# Conversión de datos heredados a estructura ADaM: ADSL y ADTTE (OS, RFS, TTR).
# Fuente: survival::colon (dos filas por paciente: etype 1 = recurrencia, 2 = muerte).
# Reglas en docs/SAP_B_colon.md.

suppressPackageStartupMessages({
  library(dplyr, warn.conflicts = FALSE)
  library(tidyr)
})
source("R/funciones.R")

colon <- survival::colon

# Comprobaciones de la fuente antes de derivar nada
stopifnot(
  all(table(colon$id) == 2),
  all(sort(unique(colon$etype)) == c(1, 2))
)

pacientes <- colon %>%
  select(id, rx, sex, age, obstruct, perfor, adhere, nodes, node4, differ, extent, surg) %>%
  distinct()
stopifnot(nrow(pacientes) == n_distinct(colon$id))

adsl_b <- pacientes %>%
  transmute(
    STUDYID = "COLON-STAGEIII",
    USUBJID = sprintf("COL-%04d", id),
    TRT01P = as.character(rx),
    TRT01PN = match(TRT01P, c("Obs", "Lev", "Lev+5FU")) - 1,
    ITTFL = "Y",
    AGE = age,
    AGEGR1 = if_else(age >= 65, ">=65", "<65"),
    SEX = if_else(sex == 1, "Hombre", "Mujer"),
    OBSTRUCT = if_else(obstruct == 1, "Sí", "No"),
    PERFOR = if_else(perfor == 1, "Sí", "No"),
    ADHERE = if_else(adhere == 1, "Sí", "No"),
    NODES = nodes,
    NODE4 = if_else(node4 == 1, ">4 ganglios", "1-4 ganglios"),
    DIFFER = factor(differ, levels = 1:3, labels = c("Bien", "Moderada", "Pobre")),
    EXTENT = factor(extent, levels = 1:4,
                    labels = c("Submucosa", "Muscular", "Serosa", "Estructuras contiguas")),
    SURG = if_else(surg == 1, "Largo", "Corto")
  ) %>%
  arrange(USUBJID)

# Una fila por paciente con recurrencia y muerte
tiempos <- colon %>%
  mutate(USUBJID = sprintf("COL-%04d", id),
         tipo = if_else(etype == 1, "rec", "dth")) %>%
  select(USUBJID, tipo, time, status) %>%
  pivot_wider(names_from = tipo, values_from = c(time, status))

# La ausencia de recurrencia comparte tiempo con la muerte o el último seguimiento
stopifnot(all(tiempos$time_rec <= tiempos$time_dth))

adtte_b <- bind_rows(
  tiempos %>% transmute(
    USUBJID, PARAMCD = "OS", PARAM = "Supervivencia global (dias)",
    AVAL = time_dth, CNSR = 1 - status_dth,
    EVNTDESC = if_else(status_dth == 1, "MUERTE", "CENSURA: ULTIMO SEGUIMIENTO")
  ),
  tiempos %>% transmute(
    USUBJID, PARAMCD = "RFS", PARAM = "Supervivencia libre de recurrencia (dias)",
    AVAL = if_else(status_rec == 1, time_rec, time_dth),
    CNSR = as.numeric(status_rec == 0 & status_dth == 0),
    EVNTDESC = case_when(
      status_rec == 1 ~ "RECURRENCIA",
      status_dth == 1 ~ "MUERTE SIN RECURRENCIA",
      TRUE ~ "CENSURA: ULTIMO SEGUIMIENTO"
    )
  ),
  # TTR: la muerte sin recurrencia es evento competitivo (CNSR = 1 y EVNTDESC lo distingue)
  tiempos %>% transmute(
    USUBJID, PARAMCD = "TTR", PARAM = "Tiempo hasta la recurrencia (dias)",
    AVAL = if_else(status_rec == 1, time_rec, time_dth),
    CNSR = as.numeric(status_rec == 0),
    EVNTDESC = case_when(
      status_rec == 1 ~ "RECURRENCIA",
      status_dth == 1 ~ "MUERTE SIN RECURRENCIA (COMPETITIVO)",
      TRUE ~ "CENSURA: ULTIMO SEGUIMIENTO"
    )
  )
) %>%
  left_join(select(adsl_b, USUBJID, STUDYID, TRT01P, TRT01PN), by = "USUBJID") %>%
  relocate(STUDYID, USUBJID) %>%
  arrange(PARAMCD, USUBJID)

comprobar_clave(adsl_b, "USUBJID", "ADSL colon")
comprobar_clave(adtte_b, c("USUBJID", "PARAMCD"), "ADTTE colon")
stopifnot(all(adtte_b$AVAL > 0), all(table(adtte_b$PARAMCD) == nrow(adsl_b)))

dir.create("output/B/datasets", recursive = TRUE, showWarnings = FALSE)
saveRDS(adsl_b, "output/B/datasets/adsl.rds")
saveRDS(adtte_b, "output/B/datasets/adtte.rds")

cat("ADSL colon:", nrow(adsl_b), "pacientes\n")
print(table(adsl_b$TRT01P))
print(adtte_b %>% count(PARAMCD, EVNTDESC))
cat("Valores ausentes:\n")
print(colSums(is.na(adsl_b))[colSums(is.na(adsl_b)) > 0])
