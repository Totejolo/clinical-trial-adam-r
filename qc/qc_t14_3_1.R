suppressPackageStartupMessages(library(dplyr))

args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
if (length(file_arg) != 1L) stop("Ejecutar este programa con Rscript")
qc_dir <- dirname(normalizePath(sub("^--file=", "", file_arg)))
out_dir <- file.path(qc_dir, "output")

adsl <- readRDS(file.path(out_dir, "qc_adsl.rds"))
adae <- readRDS(file.path(out_dir, "qc_adae.rds"))

safety <- adsl %>%
  filter(SAFFL == "Y") %>%
  select(USUBJID, TRT01A, DCSREAS)

if (anyDuplicated(safety$USUBJID)) stop("ADSL contiene sujetos de seguridad duplicados")
if (anyNA(safety$TRT01A)) stop("Hay sujetos de seguridad sin TRT01A")
if (anyDuplicated(adae[c("USUBJID", "AESEQ")])) stop("ADAE contiene claves duplicadas")
if (anyNA(adsl$USUBJID) || anyNA(adae$USUBJID) || anyNA(adae$AESEQ)) {
  stop("Clave ausente en las entradas de QC")
}
if (!all(adae$USUBJID %in% adsl$USUBJID)) stop("AE sin sujeto en ADSL")

teae <- adae %>%
  semi_join(safety, by = "USUBJID") %>%
  filter(TRTEMFL == "Y")

rows <- list(
  "Cualquier TEAE" = unique(teae$USUBJID),
  "TEAE grave" = unique(teae$USUBJID[!is.na(teae$AESER) & teae$AESER == "Y"]),
  "TEAE relacionado" = unique(teae$USUBJID[!is.na(teae$AEREL) & teae$AEREL %in% c("POSSIBLE", "PROBABLE")]),
  "Interrupción del estudio por evento adverso" = unique(safety$USUBJID[!is.na(safety$DCSREAS) & safety$DCSREAS == "ADVERSE EVENT"]),
  "TEAE mortal" = unique(teae$USUBJID[!is.na(teae$AEOUT) & teae$AEOUT == "FATAL"])
)

arms <- sort(unique(safety$TRT01A))
result <- do.call(rbind, lapply(names(rows), function(row_name) {
  data.frame(
    fila = row_name,
    TRT01A = arms,
    n = vapply(arms, function(arm) {
      sum(safety$TRT01A == arm & safety$USUBJID %in% rows[[row_name]])
    }, integer(1)),
    stringsAsFactors = FALSE
  )
}))
rownames(result) <- NULL

denominators <- table(safety$TRT01A)
stopifnot(nrow(result) == length(rows) * length(arms),
          !anyDuplicated(result[c("fila", "TRT01A")]),
          all(result$n >= 0L),
          all(result$n <= as.integer(denominators[result$TRT01A])))
for (arm in arms) {
  counts <- result[result$TRT01A == arm, ]
  n_any <- counts$n[counts$fila == "Cualquier TEAE"]
  stopifnot(all(counts$n[counts$fila %in%
    c("TEAE grave", "TEAE relacionado", "TEAE mortal")] <= n_any))
}

dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
write.csv(result, file.path(out_dir, "qc_t14_3_1.csv"), row.names = FALSE,
          na = "", fileEncoding = "UTF-8")
message("QC T-14.3.1: ", nrow(result), " filas; sujetos unicos por tratamiento")
