# 01_explorar_sdtm.R
# Primer contacto con datos SDTM (CDISC) del ensayo piloto incluido en pharmaversesdtm.

library(dplyr)

dm <- pharmaversesdtm::dm
ae <- pharmaversesdtm::ae
ex <- pharmaversesdtm::ex

# DM (demografía): una fila por sujeto
glimpse(dm)
dm |> count(ARM)

# AE (eventos adversos): una fila por evento y sujeto
glimpse(ae)
ae |> count(AEBODSYS, sort = TRUE) |> head(10)

# Un sujeto concreto, para ver cómo se relacionan los dominios
id <- dm$USUBJID[dm$ARM != "Screen Failure"][1]
dm |> filter(USUBJID == id) |> select(USUBJID, ARM, RFSTDTC, RFENDTC, AGE, SEX)
ex |> filter(USUBJID == id) |> select(USUBJID, EXTRT, EXDOSE, EXSTDTC, EXENDTC)
ae |> filter(USUBJID == id) |> select(USUBJID, AEDECOD, AEBODSYS, AESTDTC, AESER)

# Contesta las tres preguntas del README antes de pasar al paso 2.
