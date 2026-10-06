# a07_export_xpt.R
# Exporta ADSL, ADAE y ADTTE a SAS transport v5 (.xpt) con tipos, longitudes, etiquetas,
# formatos y orden de la especificación, como en una entrega a regulador.

suppressPackageStartupMessages({
  library(dplyr, warn.conflicts = FALSE)
  library(xportr)
})
source("R/funciones.R")

specs <- leer_specs() %>%
  mutate(
    type = recode(type, text = "character", integer = "numeric", float = "numeric", date = "numeric"),
    format = if_else(.data$type == "numeric" & grepl("DT$", variable), "DATE9.", NA_character_)
  )
etiquetas_ds <- data.frame(
  dataset = c("ADSL", "ADAE", "ADTTE"),
  label = c("Subject-Level Analysis Dataset", "Adverse Events Analysis Dataset",
            "Time-to-Event Analysis Dataset")
)

dir.create("output/A/xpt", recursive = TRUE, showWarnings = FALSE)
for (ds in c("ADSL", "ADAE", "ADTTE")) {
  datos <- readRDS(file.path("output/A/datasets", paste0(tolower(ds), ".rds")))
  meta <- filter(specs, dataset == ds)
  datos %>%
    xportr_type(meta, domain = ds, verbose = "message") %>%
    xportr_length(meta, domain = ds, verbose = "message") %>%
    xportr_label(meta, domain = ds, verbose = "message") %>%
    xportr_format(meta, domain = ds) %>%
    xportr_order(meta, domain = ds, verbose = "message") %>%
    xportr_df_label(etiquetas_ds, domain = ds) %>%
    xportr_write(file.path("output/A/xpt", paste0(tolower(ds), ".xpt")))
  cat(ds, "->", paste0(tolower(ds), ".xpt"), "\n")
}

# Lectura de vuelta para comprobar que el fichero es válido y conserva filas y etiquetas
chk <- haven::read_xpt("output/A/xpt/adtte.xpt")
stopifnot(nrow(chk) == nrow(readRDS("output/A/datasets/adtte.rds")))
cat("Etiqueta de AVAL en el XPT:", attr(chk$AVAL, "label"), "\n")
