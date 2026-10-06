# a08_qc_comparacion.R
# Compara producción con la doble programación independiente de qc/ (escrita por Codex sin
# acceso al código de producción). Salida: output/A/qc/informe_qc.md

suppressPackageStartupMessages({
  library(dplyr, warn.conflicts = FALSE)
  library(diffdf)
})
source("R/funciones.R")

# Solo se comparan valores: se quitan atributos (etiquetas, longitudes) y se igualan clases
normalizar <- function(df) {
  df <- as.data.frame(df)
  df[] <- lapply(df, function(x) {
    attributes(x) <- attributes(x)[intersect(names(attributes(x)), "class")]
    if (is.factor(x)) x <- as.character(x)
    if (is.integer(x)) x <- as.numeric(x)
    x
  })
  df
}

comparar <- function(nombre, prod, qc, claves) {
  comunes <- intersect(names(prod), names(qc))
  res <- diffdf(
    normalizar(prod[, comunes, drop = FALSE]),
    normalizar(qc[, comunes, drop = FALSE]),
    keys = claves,
    suppress_warnings = TRUE
  )
  list(
    nombre = nombre,
    filas = sprintf("%d / %d", nrow(prod), nrow(qc)),
    variables = length(comunes),
    solo_prod = paste(setdiff(names(prod), names(qc)), collapse = ", "),
    solo_qc = paste(setdiff(names(qc), names(prod)), collapse = ", "),
    ok = !diffdf_has_issues(res),
    detalle = capture.output(print(res))
  )
}

t_prod <- read.csv("output/A/tlf/t_14_3_1_resumen_teae.csv", encoding = "UTF-8") %>%
  mutate(fila = sub(" \\(posible o probable\\)", "", fila))
t_qc <- read.csv("qc/output/qc_t14_3_1.csv", encoding = "UTF-8")

resultados <- list(
  comparar("ADSL", readRDS("output/A/datasets/adsl.rds"), readRDS("qc/output/qc_adsl.rds"),
           "USUBJID"),
  comparar("ADAE", readRDS("output/A/datasets/adae.rds"), readRDS("qc/output/qc_adae.rds"),
           c("USUBJID", "AESEQ")),
  comparar("ADTTE (TTDE)",
           filter(readRDS("output/A/datasets/adtte.rds"), PARAMCD == "TTDE"),
           readRDS("qc/output/qc_adtte.rds"),
           c("USUBJID", "PARAMCD")),
  comparar("T-14.3.1", t_prod, t_qc, c("fila", "TRT01A"))
)

resumen <- do.call(rbind, lapply(resultados, function(r) data.frame(
  Entregable = r$nombre,
  `Filas producción / QC` = r$filas,
  `Variables comparadas` = r$variables,
  `Solo en producción` = r$solo_prod,
  `Solo en QC` = r$solo_qc,
  Resultado = ifelse(r$ok, "Coinciden", "Diferencias"),
  check.names = FALSE
)))

lineas <- c(
  "# Informe de QC: doble programación independiente (parte A)",
  "",
  "Producción: `programs/A_cdiscpilot/` (admiral). QC: `qc/` (dplyr y R base, escrito por",
  "Codex solo a partir del SAP y la especificación, sin ver el código de producción).",
  "Se comparan valores con `diffdf`; las etiquetas y longitudes se revisan en el XPT.",
  "",
  tabla_md(resumen),
  ""
)
for (r in resultados[!sapply(resultados, `[[`, "ok")]) {
  lineas <- c(lineas, paste("##", r$nombre), "", "```", head(r$detalle, 80), "```", "")
}
escribir_md(lineas, "output/A/qc/informe_qc.md")
cat(lineas, sep = "\n")
