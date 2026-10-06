# QC independiente: solo estimando principal TTDE.
suppressPackageStartupMessages(library(dplyr))

file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(file_arg) != 1L) stop("Ejecutar este programa con Rscript")
qc_dir <- dirname(normalizePath(sub("^--file=", "", file_arg)))
out_dir <- file.path(qc_dir, "output")
adsl <- readRDS(file.path(out_dir, "qc_adsl.rds"))
adae <- readRDS(file.path(out_dir, "qc_adae.rds"))
spec <- read.csv(file.path(qc_dir, "..", "specs", "adam_specs_A.csv"),
                 stringsAsFactors = FALSE, check.names = FALSE)
spec <- spec[spec$dataset == "ADTTE", ]
spec <- spec[order(spec$order), ]

stopifnot(!anyDuplicated(adsl$USUBJID),
          !anyDuplicated(adae[c("USUBJID", "AESEQ")]),
          inherits(adsl$TRTSDT, "Date"), inherits(adsl$LSTEXDT, "Date"),
          inherits(adae$ASTDT, "Date"))
safety <- filter(adsl, SAFFL == "Y")
if (anyNA(safety$TRTSDT) || anyNA(safety$LSTEXDT)) {
  stop("No se puede derivar TTDE: sujeto de seguridad sin origen o fin conocido")
}
if (any(safety$LSTEXDT < safety$TRTSDT)) stop("Fin de exposicion anterior al inicio")

# Desempate reproducible: primera ASTDT y, en el mismo dia, menor AESEQ.
events <- adae %>%
  filter(DERMFL == "Y", ONTRTFL == "Y") %>%
  semi_join(safety, by = "USUBJID") %>%
  arrange(USUBJID, ASTDT, AESEQ) %>%
  group_by(USUBJID) %>%
  slice_head(n = 1L) %>%
  ungroup() %>%
  transmute(USUBJID, EVENTDT = ASTDT, EVENTSEQ = AESEQ)
if (anyNA(events$EVENTDT) || anyNA(events$EVENTSEQ)) stop("Evento sin fecha o secuencia")

result <- safety %>%
  left_join(events, by = "USUBJID") %>%
  mutate(
    PARAMCD = "TTDE",
    PARAM = "Tiempo hasta el primer EA dermatologico en tratamiento (dias)",
    STARTDT = TRTSDT,
    CNSR = if_else(!is.na(EVENTDT), 0L, 1L),
    ADT = if_else(CNSR == 0L, EVENTDT, LSTEXDT),
    AVAL = as.numeric(ADT - STARTDT) + 1,
    CNSDTDSC = case_when(
      CNSR == 0L ~ NA_character_,
      EOSSTT == "COMPLETED" ~ "TRATAMIENTO COMPLETADO",
      DCSREAS == "ADVERSE EVENT" ~ "INTERRUPCION POR EA",
      TRUE ~ "OTRA INTERRUPCION"
    ),
    EVNTDESC = if_else(CNSR == 0L, "PRIMER EVENTO DERMATOLOGICO",
                       paste0("CENSURA: ", CNSDTDSC)),
    SRCDOM = if_else(CNSR == 0L, "ADAE", "ADSL"),
    # TTDE no censura en EOSDT; con TRTEDT ausente se usa LSTEXDT.
    SRCVAR = case_when(
      CNSR == 0L ~ "ASTDT",
      !is.na(TRTEDT) ~ "TRTEDT",
      TRUE ~ "LSTEXDT"
    ),
    SRCSEQ = if_else(CNSR == 0L, as.integer(EVENTSEQ), NA_integer_)
  ) %>%
  select(all_of(spec$variable)) %>%
  arrange(USUBJID)

stopifnot(nrow(result) == nrow(safety), !anyDuplicated(result$USUBJID),
          identical(as.character(result$USUBJID), sort(as.character(safety$USUBJID))),
          all(result$PARAMCD == "TTDE"), all(result$AVAL >= 1),
          all(result$ADT <= safety$LSTEXDT[match(result$USUBJID, safety$USUBJID)]),
          all((result$CNSR == 0L) == (result$SRCDOM == "ADAE")),
          all((result$CNSR == 1L) == is.na(result$SRCSEQ)),
          all((result$CNSR == 0L) == is.na(result$CNSDTDSC)))

# Comprueba que ADT coincide con la variable y registro citados.
for (i in seq_len(nrow(result))) {
  if (result$CNSR[i] == 0L) {
    src <- adae[adae$USUBJID == result$USUBJID[i] &
                  adae$AESEQ == result$SRCSEQ[i], ]
    stopifnot(nrow(src) == 1L, src$ASTDT == result$ADT[i],
              src$DERMFL == "Y", src$ONTRTFL == "Y")
  } else {
    j <- match(result$USUBJID[i], adsl$USUBJID)
    stopifnot(adsl[[result$SRCVAR[i]]][j] == result$ADT[i])
  }
}

result <- as.data.frame(result)
for (i in seq_len(nrow(spec))) {
  v <- spec$variable[i]
  if (spec$type[i] == "integer") result[[v]] <- as.integer(result[[v]])
  if (spec$type[i] == "float") result[[v]] <- as.numeric(result[[v]])
  if (spec$type[i] == "date") stopifnot(inherits(result[[v]], "Date"))
  if (spec$type[i] == "text") {
    result[[v]] <- as.character(result[[v]])
    stopifnot(all(is.na(result[[v]]) | nchar(result[[v]], type = "bytes") <= spec$length[i]))
  }
  attr(result[[v]], "label") <- spec$label[i]
  attr(result[[v]], "sas_length") <- as.integer(spec$length[i])
}
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
saveRDS(result, file.path(out_dir, "qc_adtte.rds"))
message("QC ADTTE: ", nrow(result), " sujetos; ", sum(result$CNSR == 0L),
        " eventos; ", sum(result$CNSR == 1L), " censuras")
