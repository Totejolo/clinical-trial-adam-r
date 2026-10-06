# Independent ADAE QC derived only from SAP, specification, SDTM AE and QC ADSL.
# Run from any working directory with Rscript qc/qc_adae.R.
suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(lubridate))

qc_script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(qc_script_arg) != 1L) stop("Run this program using Rscript --file or Rscript path/to/qc_adae.R")
qc_dir <- dirname(normalizePath(sub("^--file=", "", qc_script_arg), mustWork = TRUE))
qc_root <- dirname(qc_dir)
qc_out <- file.path(qc_dir, "output")
dir.create(qc_out, recursive = TRUE, showWarnings = FALSE)

qc_blank_to_na <- function(x) {
  if (is.character(x)) x[!is.na(x) & trimws(x) == ""] <- NA_character_
  x
}

# Date-only precision is read before any time component. No missing year is imputed.
qc_ae_date <- function(x, end = FALSE) {
  x <- qc_blank_to_na(as.character(x))
  date_text <- sub("T.*$", "", x)
  precision <- ifelse(is.na(date_text), NA_integer_, nchar(date_text))
  valid <- is.na(date_text) | grepl("^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$", date_text)
  if (any(!valid)) stop("Unsupported AE date syntax: ", paste(unique(x[!valid]), collapse = ", "))
  result <- as.Date(rep(NA_character_, length(x)))
  flag <- rep(NA_character_, length(x))
  full <- which(precision == 10L)
  month <- which(precision == 7L)
  year <- which(precision == 4L)
  result[full] <- as.Date(date_text[full], format = "%Y-%m-%d")
  if (anyNA(result[full]) || any(format(result[full], "%Y-%m-%d") != date_text[full])) {
    stop("AE contains an invalid complete calendar date")
  }
  result[month] <- as.Date(paste0(date_text[month], "-01"), format = "%Y-%m-%d")
  if (anyNA(result[month]) || any(format(result[month], "%Y-%m-%d") != paste0(date_text[month], "-01"))) {
    stop("AE contains an invalid year-month date")
  }
  if (end && length(month)) result[month] <- as.Date(ceiling_date(result[month], unit = "month") - days(1))
  result[year] <- as.Date(paste0(date_text[year], if (end) "-12-31" else "-01-01"), format = "%Y-%m-%d")
  flag[month] <- "D"
  flag[year] <- "M"
  if (any(!is.na(x) & is.na(result))) stop("AE contains an invalid calendar date")
  list(date = result, flag = flag)
}

ae <- as.data.frame(pharmaversesdtm::ae, stringsAsFactors = FALSE)
ae[] <- lapply(ae, qc_blank_to_na)
adsl_path <- file.path(qc_out, "qc_adsl.rds")
if (!file.exists(adsl_path)) stop("Run qc_adsl.R first: missing qc/output/qc_adsl.rds")
adsl <- readRDS(adsl_path)
stopifnot(!anyNA(adsl$USUBJID), !anyNA(ae$USUBJID), !anyNA(ae$AESEQ),
          !anyDuplicated(adsl$USUBJID), !anyDuplicated(ae[c("USUBJID", "AESEQ")]))
if (!all(ae$USUBJID %in% adsl$USUBJID)) stop("AE subject absent from QC ADSL")
for (v in c("TRTSDT", "TRTEDT", "LSTEXDT")) {
  if (!inherits(adsl[[v]], "Date")) stop("QC ADSL variable is not Date: ", v)
}
adae <- ae %>% left_join(adsl %>% select(USUBJID, TRT01A, TRT01AN, TRTSDT, TRTEDT, LSTEXDT), by = "USUBJID")
start <- qc_ae_date(adae$AESTDTC)
finish <- qc_ae_date(adae$AEENDTC, end = TRUE)
adae$ASTDT <- start$date
adae$ASTDTF <- start$flag
adae$AENDT <- finish$date
# Clamp only imputed starts; complete pre-treatment dates remain unchanged.
# Month/year are assessed on the date after the stipulated earliest-date imputation.
clamp <- !is.na(adae$ASTDTF) & !is.na(adae$TRTSDT) & !is.na(adae$ASTDT) &
  format(adae$ASTDT, "%Y-%m") == format(adae$TRTSDT, "%Y-%m") & adae$ASTDT < adae$TRTSDT
clamp[is.na(clamp)] <- FALSE
adae$ASTDT[clamp] <- adae$TRTSDT[clamp]
qc_y_flag <- function(x) ifelse(!is.na(x) & x, "Y", NA_character_)
# TRTEDT remains missing when unavailable: LSTEXDT applies to ONTRTFL only.
adae$TRTEMFL <- qc_y_flag(adae$ASTDT >= adae$TRTSDT & adae$ASTDT <= adae$TRTEDT + 30)
adae$ONTRTFL <- qc_y_flag(adae$ASTDT >= adae$TRTSDT & adae$ASTDT <= adae$LSTEXDT)
adae$DERMFL <- qc_y_flag(adae$AEBODSYS == "SKIN AND SUBCUTANEOUS TISSUE DISORDERS" |
  startsWith(adae$AEDECOD, "APPLICATION SITE"))

spec <- read.csv(file.path(qc_root, "specs", "adam_specs_A.csv"), stringsAsFactors = FALSE, check.names = FALSE)
spec <- spec[spec$dataset == "ADAE", ]
spec <- spec[order(spec$order), ]
if (!all(spec$variable %in% names(adae))) stop("Required ADAE variable missing")
adae <- as.data.frame(adae[, spec$variable], stringsAsFactors = FALSE)
adae <- adae[order(adae$USUBJID, adae$AESEQ), , drop = FALSE]
rownames(adae) <- NULL
for (i in seq_len(nrow(spec))) {
  v <- spec$variable[i]
  if (spec$type[i] == "text") adae[[v]] <- as.character(adae[[v]])
  if (spec$type[i] == "integer") adae[[v]] <- as.integer(adae[[v]])
  if (spec$type[i] == "date" && !inherits(adae[[v]], "Date")) stop("Invalid date type: ", v)
  if (spec$type[i] == "text" && any(nchar(adae[[v]], type = "bytes") > spec$length[i], na.rm = TRUE)) {
    stop("Value exceeds specification length: ", v)
  }
  attr(adae[[v]], "label") <- spec$label[i]
  attr(adae[[v]], "sas_length") <- as.integer(spec$length[i])
}
stopifnot(nrow(adae) == nrow(ae), !anyDuplicated(adae[c("USUBJID", "AESEQ")]),
          identical(names(adae), spec$variable))
partial_n <- sum(!is.na(adae$ASTDTF))
if (partial_n != 26L) stop("SAP expects 26 partial AE start dates; observed ", partial_n)
if (any(adae$AENDT < adae$ASTDT, na.rm = TRUE)) {
  warning("AE end precedes analysis start in ", sum(adae$AENDT < adae$ASTDT, na.rm = TRUE), " records; source retained")
}
saveRDS(adae, file.path(qc_out, "qc_adae.rds"))
cat("ADAE: ", nrow(adae), " records; ", length(unique(adae$USUBJID)), " subjects\n", sep = "")
cat("Partial starts: ", partial_n, "; D=", sum(adae$ASTDTF == "D", na.rm = TRUE),
    "; M=", sum(adae$ASTDTF == "M", na.rm = TRUE), "; clamped=", sum(clamp), "\n", sep = "")
cat("Flags: TRTEMFL=", sum(adae$TRTEMFL == "Y", na.rm = TRUE),
    "; ONTRTFL=", sum(adae$ONTRTFL == "Y", na.rm = TRUE),
    "; DERMFL=", sum(adae$DERMFL == "Y", na.rm = TRUE), "\n", sep = "")
print(adae[!is.na(adae$ASTDTF), c("USUBJID", "AESEQ", "ASTDT", "ASTDTF", "AENDT")], row.names = FALSE)
