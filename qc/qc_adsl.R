# Independent ADSL QC derived only from the SAP, ADaM specification, DM, EX and DS.
# Run with Rscript qc/qc_adsl.R from any working directory.
options(stringsAsFactors = FALSE)
suppressPackageStartupMessages(library(dplyr))

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_arg) != 1L) stop("Run this program using Rscript.")
qc_dir <- dirname(normalizePath(sub("^--file=", "", script_arg), mustWork = TRUE))
root_dir <- dirname(qc_dir)
out_dir <- file.path(qc_dir, "output")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

clean_domain <- function(x) {
  x <- as.data.frame(x)
  x[] <- lapply(x, function(v) {
    if (is.character(v)) v[!is.na(v) & trimws(v) == ""] <- NA_character_
    v
  })
  x
}

# Only complete calendar dates are used. A time suffix is harmless; partial dates
# remain missing, as required for exposure dates (no imputation).
complete_date <- function(x) {
  out <- as.Date(rep(NA_character_, length(x)))
  ok <- !is.na(x) & grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}($|T)", x)
  if (any(ok)) {
    z <- substr(x[ok], 1L, 10L)
    parsed <- as.Date(z, format = "%Y-%m-%d")
    if (any(is.na(parsed) | format(parsed, "%Y-%m-%d") != z)) {
      stop("Invalid complete source date.")
    }
    out[ok] <- parsed
  }
  out
}
date_min <- function(x) if (all(is.na(x))) as.Date(NA) else min(x, na.rm = TRUE)
date_max <- function(x) if (all(is.na(x))) as.Date(NA) else max(x, na.rm = TRUE)

dm <- clean_domain(pharmaversesdtm::dm)
ex <- clean_domain(pharmaversesdtm::ex)
ds <- clean_domain(pharmaversesdtm::ds)
stopifnot(!anyNA(dm$USUBJID), !anyDuplicated(dm$USUBJID))
stopifnot(all(ex$USUBJID %in% dm$USUBJID), all(ds$USUBJID %in% dm$USUBJID))

# Placebo administrations qualify even if EXDOSE is zero.
eligible <- ex %>%
  filter((!is.na(EXDOSE) & EXDOSE > 0) |
           (!is.na(EXTRT) & toupper(trimws(EXTRT)) == "PLACEBO")) %>%
  mutate(ex_start = complete_date(EXSTDTC), ex_end = complete_date(EXENDTC))
ex_summary <- eligible %>%
  group_by(USUBJID) %>%
  summarise(TRTSDT = date_min(ex_start), TRTEDT = date_max(ex_end),
            last_start = date_max(ex_start), SAFFL = "Y", .groups = "drop") %>%
  mutate(LSTEXDT = coalesce(TRTEDT, last_start)) %>%
  select(-last_start)

disposition <- ds %>% filter(DSCAT == "DISPOSITION EVENT")
# A duplicate disposition needs an explicit SAP rule; do not silently pick one.
if (anyDuplicated(disposition$USUBJID)) {
  stop("Multiple disposition events; selection is unspecified for: ",
       paste(unique(disposition$USUBJID[duplicated(disposition$USUBJID)]), collapse = ", "))
}
disposition <- disposition %>%
  transmute(USUBJID, has_disposition = TRUE,
            EOSSTT = case_when(DSDECOD == "SCREEN FAILURE" ~ NA_character_,
                               DSDECOD == "COMPLETED" ~ "COMPLETED",
                               TRUE ~ "DISCONTINUED"),
            EOSDT = if_else(DSDECOD == "SCREEN FAILURE", as.Date(NA), complete_date(DSSTDTC)),
            DCSREAS = if_else(!is.na(DSDECOD) &
                               !(DSDECOD %in% c("COMPLETED", "SCREEN FAILURE")),
                             DSDECOD, NA_character_))
randomization <- ds %>% filter(DSDECOD == "RANDOMIZED")
if (anyDuplicated(randomization$USUBJID)) {
  stop("Multiple randomization records; selection is unspecified for: ",
       paste(unique(randomization$USUBJID[duplicated(randomization$USUBJID)]), collapse = ", "))
}
randomization <- randomization %>% transmute(USUBJID, RANDDT = complete_date(DSSTDTC))

dose_map <- c("Placebo" = 0L, "Xanomeline Low Dose" = 54L,
              "Xanomeline High Dose" = 81L, "Screen Failure" = NA_integer_)
unknown_arms <- setdiff(na.omit(unique(c(dm$ARM, dm$ACTARM))), names(dose_map))
if (length(unknown_arms)) stop("Treatment mapping missing for: ", paste(unknown_arms, collapse = ", "))

adsl <- dm %>%
  select(STUDYID, USUBJID, SUBJID, SITEID, AGE, AGEU, SEX, RACE, ARM, ACTARM) %>%
  mutate(AGEGR1 = case_when(is.na(AGE) ~ NA_character_, AGE <= 64 ~ "18-64", TRUE ~ ">64"),
         TRT01P = ARM, TRT01PN = unname(dose_map[TRT01P]),
         TRT01A = ACTARM, TRT01AN = unname(dose_map[TRT01A])) %>%
  left_join(ex_summary, by = "USUBJID") %>%
  left_join(disposition, by = "USUBJID") %>%
  left_join(randomization, by = "USUBJID") %>%
  mutate(SAFFL = coalesce(SAFFL, "N"),
         TRTDURD = as.integer(TRTEDT - TRTSDT + 1),
         EOSSTT = if_else(is.na(has_disposition), "ONGOING", EOSSTT)) %>%
  arrange(USUBJID)

spec <- read.csv(file.path(root_dir, "specs", "adam_specs_A.csv"),
                 check.names = FALSE, fileEncoding = "UTF-8")
spec <- spec[spec$dataset == "ADSL", ]
spec <- spec[order(spec$order), ]
stopifnot(nrow(spec) == 24L, all(spec$variable %in% names(adsl)))
adsl <- as.data.frame(adsl[, spec$variable])
for (i in seq_len(nrow(spec))) {
  nm <- spec$variable[i]
  if (spec$type[i] == "integer") adsl[[nm]] <- as.integer(adsl[[nm]])
  if (spec$type[i] == "text") {
    adsl[[nm]] <- as.character(adsl[[nm]])
    if (any(nchar(adsl[[nm]], type = "bytes") > spec$length[i], na.rm = TRUE)) {
      stop("Specified character length exceeded: ", nm)
    }
  }
  if (spec$type[i] == "date" && !inherits(adsl[[nm]], "Date")) stop("Date class missing: ", nm)
  attr(adsl[[nm]], "label") <- spec$label[i]
  attr(adsl[[nm]], "sas_length") <- as.integer(spec$length[i])
}

stopifnot(nrow(adsl) == nrow(dm), !anyDuplicated(adsl$USUBJID),
          !is.unsorted(adsl$USUBJID),
          sum(adsl$SAFFL == "Y") == n_distinct(eligible$USUBJID),
          all(adsl$TRTEDT >= adsl$TRTSDT, na.rm = TRUE),
          all(adsl$LSTEXDT >= adsl$TRTSDT, na.rm = TRUE),
          all(adsl$EOSDT >= adsl$TRTSDT, na.rm = TRUE),
          all(is.na(adsl$TRTDURD[is.na(adsl$TRTEDT)])))
saveRDS(adsl, file.path(out_dir, "qc_adsl.rds"), version = 2)
cat("ADSL QC:", nrow(adsl), "subjects;", sum(adsl$SAFFL == "Y"),
    "safety subjects;", sum(adsl$SAFFL == "Y" & is.na(adsl$TRTEDT)),
    "safety subjects without TRTEDT.\n")
print(table(adsl$TRT01A, adsl$SAFFL, useNA = "ifany"))
