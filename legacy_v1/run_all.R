# run_all.R
# Ejecuta el proyecto completo en orden. Lanzar desde la carpeta del proyecto.

for (f in c("02_adsl.R", "03_adtte.R", "04_analisis.R", "05_validar.R")) {
  cat("\n==== ", f, " ====\n", sep = "")
  source(f, echo = FALSE, encoding = "UTF-8")
}
