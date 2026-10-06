# Funciones comunes del proyecto

suppressPackageStartupMessages({
  library(dplyr, warn.conflicts = FALSE)
})

# Especificación de variables ADaM (parte A)
leer_specs <- function(path = "specs/adam_specs_A.csv") {
  read.csv(path, stringsAsFactors = FALSE, encoding = "UTF-8")
}

# Variables de un dataset en el orden de la especificación
vars_spec <- function(specs, dataset) {
  s <- specs[specs$dataset == dataset, ]
  s$variable[order(s$order)]
}

# Falla si hay claves duplicadas
comprobar_clave <- function(df, claves, nombre) {
  dup <- df %>%
    count(across(all_of(claves))) %>%
    filter(n > 1)
  if (nrow(dup) > 0) {
    stop(nombre, ": ", nrow(dup), " claves duplicadas en ", paste(claves, collapse = ", "))
  }
  invisible(TRUE)
}

# Tabla en markdown a partir de un data.frame
tabla_md <- function(df) {
  df[] <- lapply(df, function(x) ifelse(is.na(x), "", as.character(x)))
  c(
    paste0("| ", paste(names(df), collapse = " | "), " |"),
    paste0("|", paste(rep("---", ncol(df)), collapse = "|"), "|"),
    apply(df, 1, function(r) paste0("| ", paste(r, collapse = " | "), " |"))
  )
}

escribir_md <- function(lineas, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  con <- file(path, open = "w", encoding = "UTF-8")
  on.exit(close(con))
  writeLines(lineas, con)
}

# Formatos
fmt_n_pct <- function(n, total) sprintf("%d (%.1f %%)", n, 100 * n / total)
fmt_ic <- function(est, lo, hi, dig = 2) {
  sprintf(paste0("%.", dig, "f (%.", dig, "f a %.", dig, "f)"), est, lo, hi)
}
fmt_p <- function(p) format.pval(p, digits = 2, eps = 1e-4)

# Orden de los brazos en todas las salidas
BRAZOS_A <- c("Placebo", "Xanomeline Low Dose", "Xanomeline High Dose")
