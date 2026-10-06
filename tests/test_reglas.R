# Tests de las reglas críticas del SAP. Se ejecutan con testthat::test_dir("tests")
# desde la carpeta del proyecto, después de generar los datasets.

library(testthat)
suppressPackageStartupMessages(library(dplyr, warn.conflicts = FALSE))

raiz <- if (file.exists("output/A/datasets/adsl.rds")) "." else ".."
leer <- function(p) readRDS(file.path(raiz, p))

adsl <- leer("output/A/datasets/adsl.rds")
adae <- leer("output/A/datasets/adae.rds")
adtte <- leer("output/A/datasets/adtte.rds")

test_that("ADTTE: una fila por sujeto de seguridad y parámetro", {
  expect_equal(nrow(adtte), 5 * sum(adsl$SAFFL == "Y"))
  expect_equal(anyDuplicated(adtte[, c("USUBJID", "PARAMCD")]), 0)
})

test_that("CNSR: 0 es evento con origen en ADAE; 1 es censura con motivo", {
  expect_true(all(adtte$SRCDOM[adtte$CNSR == 0] == "ADAE"))
  expect_true(all(!is.na(adtte$CNSDTDSC[adtte$CNSR == 1])))
  expect_true(all(is.na(adtte$CNSDTDSC[adtte$CNSR == 0])))
})

test_that("AVAL cuenta el primer día y nunca es negativo", {
  expect_true(all(adtte$AVAL == as.numeric(adtte$ADT - adtte$STARTDT) + 1))
  expect_true(all(adtte$AVAL >= 1))
})

test_that("Los eventos del principal son dermatológicos y en tratamiento", {
  ev <- adtte %>%
    filter(PARAMCD == "TTDE", CNSR == 0) %>%
    left_join(adae, by = c("USUBJID", "SRCSEQ" = "AESEQ"))
  expect_true(all(ev$DERMFL == "Y" & ev$ONTRTFL == "Y"))
  expect_true(all(ev$ADT == ev$ASTDT))
})

test_that("Los dos sujetos sin TRTEDT entran en el análisis", {
  sin_fin <- adsl$USUBJID[adsl$SAFFL == "Y" & is.na(adsl$TRTEDT)]
  expect_length(sin_fin, 2)
  expect_true(all(sin_fin %in% adtte$USUBJID[adtte$PARAMCD == "TTDE"]))
})

test_that("Parte B: OS, RFS y TTR para los 929 pacientes", {
  b <- leer("output/B/datasets/adtte.rds")
  expect_equal(as.integer(table(b$PARAMCD)), rep(929L, 3))
  rfs <- filter(b, PARAMCD == "RFS")
  os <- filter(b, PARAMCD == "OS")
  expect_true(all(rfs$AVAL <= os$AVAL[match(rfs$USUBJID, os$USUBJID)]))
})
