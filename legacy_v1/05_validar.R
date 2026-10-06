# 05_validar.R
# Doble programación ligera: compara el ADSL propio con el de referencia de pharmaverseadam,
# variable a variable, como se hace en una CRO antes de entregar un dataset.

suppressPackageStartupMessages(library(dplyr, warn.conflicts = FALSE))

propio <- readRDS("output/adsl.rds")
ref <- pharmaverseadam::adsl

vars <- c("TRT01P", "TRT01A", "TRTSDT", "TRTEDT", "TRTDURD", "SAFFL",
          "AGEGR1", "EOSSTT", "EOSDT", "RANDDT")

junto <- inner_join(
  select(propio, USUBJID, all_of(vars)),
  select(ref, USUBJID, all_of(vars)),
  by = "USUBJID",
  suffix = c(".propio", ".ref")
)

difs <- sapply(vars, function(v) {
  a <- junto[[paste0(v, ".propio")]]
  b <- junto[[paste0(v, ".ref")]]
  sum(!(a == b | (is.na(a) & is.na(b))), na.rm = TRUE) + sum(xor(is.na(a), is.na(b)))
})

lineas <- c(
  "# Validación del ADSL frente a pharmaverseadam::adsl",
  "",
  sprintf("Sujetos: propio %d, referencia %d, en común %d.", nrow(propio), nrow(ref), nrow(junto)),
  "",
  "| Variable | Sujetos con diferencias |",
  "|---|---|",
  sprintf("| %s | %d |", names(difs), difs)
)
writeLines(lineas, "output/validacion.md", useBytes = TRUE)
cat(lineas, sep = "\n")
