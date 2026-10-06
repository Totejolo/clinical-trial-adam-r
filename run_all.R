# run_all.R
# Ejecuta el proyecto completo en orden, desde la carpeta del proyecto:
#   Rscript run_all.R
# La QC independiente (qc/) se ejecuta antes de la comparación a08.

ejecutar <- function(f) {
  cat("\n==== ", f, " ====\n", sep = "")
  source(f, echo = FALSE, encoding = "UTF-8", local = new.env())
}

parte_a <- c("a01_adsl.R", "a02_adae.R", "a03_adtte.R", "a04_tlf_seguridad.R",
             "a05_tte_principal.R", "a06_sensibilidades.R", "a07_export_xpt.R")
for (f in parte_a) ejecutar(file.path("programs/A_cdiscpilot", f))

# Los programas de QC se lanzan como procesos aparte, igual que los escribió su autor
rscript <- file.path(R.home("bin"), "Rscript")
for (f in c("qc_adsl.R", "qc_adae.R", "qc_adtte.R", "qc_t14_3_1.R")) {
  cat("\n==== qc/", f, " ====\n", sep = "")
  if (system2(rscript, file.path("qc", f)) != 0) stop("Falló la QC: ", f)
}
ejecutar("programs/A_cdiscpilot/a08_qc_comparacion.R")

parte_b <- c("b01_adam.R", "b02_eficacia.R", "b03_riesgos_competitivos.R",
             "b04_subgrupos_validacion.R")
for (f in parte_b) ejecutar(file.path("programs/B_colon", f))

testthat::test_dir("tests", reporter = "summary")
