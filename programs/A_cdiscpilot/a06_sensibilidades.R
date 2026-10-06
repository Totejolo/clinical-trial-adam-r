# a06_sensibilidades.R
# Sensibilidades S1 a S5 (SAP, sección 6). Salidas: T-14.3.4 y F-14.3.2.

suppressPackageStartupMessages({
  library(dplyr, warn.conflicts = FALSE)
  library(survival)
  library(tidycmprsk)
  library(ggsurvfit)
  library(ggplot2)
})
source("R/funciones.R")

adtte <- readRDS("output/A/datasets/adtte.rds") %>%
  mutate(EVENTO = 1 - CNSR, TRT01A = factor(TRT01A, levels = BRAZOS_A))

etiquetas <- c(
  TTDE = "Principal: en tratamiento, definición completa",
  TTDE30 = "S1: ventana TEAE (+30 días)",
  TTDESOC = "S2: solo órgano-sistema de piel",
  TTDEIMPL = "S4: fechas parciales al último día",
  TTDEEOS = "S5: fin de estudio si falta TRTEDT"
)

resumir <- function(d) {
  cox <- coxph(Surv(AVAL, EVENTO) ~ TRT01A + AGE, data = d)
  ci <- summary(cox)$conf.int
  km <- survfit(Surv(AVAL, EVENTO) ~ TRT01A, data = d)
  s <- summary(km, times = 84, extend = TRUE)
  inc <- sprintf("%.0f", 100 * (1 - s$surv))
  data.frame(
    eventos = paste(tapply(d$EVENTO, d$TRT01A, sum), collapse = " / "),
    incid_12s = paste(inc, collapse = " / "),
    hr_baja = fmt_ic(ci[1, 1], ci[1, 3], ci[1, 4]),
    hr_alta = fmt_ic(ci[2, 1], ci[2, 3], ci[2, 4])
  )
}

t1434 <- bind_rows(lapply(names(etiquetas), function(p) {
  cbind(Análisis = etiquetas[[p]], resumir(filter(adtte, PARAMCD == p)))
}))

# S3: interrupción del tratamiento sin evento previo como evento competitivo
s3 <- adtte %>%
  filter(PARAMCD == "TTDE") %>%
  mutate(estado = factor(
    case_when(
      CNSR == 0 ~ "Evento dermatológico",
      CNSDTDSC == "TRATAMIENTO COMPLETADO" ~ "Censura",
      TRUE ~ "Interrupción sin evento"
    ),
    levels = c("Censura", "Evento dermatológico", "Interrupción sin evento")
  ))

cif <- cuminc(Surv(AVAL, estado) ~ TRT01A, data = s3)
cif_12 <- tidy(cif, times = c(84, 168)) %>%
  filter(outcome == "Evento dermatológico") %>%
  transmute(
    Brazo = strata, Día = time,
    `Incidencia acumulada AJ (IC 95 %)` = fmt_ic(100 * estimate, 100 * conf.low, 100 * conf.high, dig = 1)
  )
gray <- glance(cif)

km_12 <- survfit(Surv(AVAL, CNSR == 0) ~ TRT01A, data = s3) %>%
  summary(times = 84, extend = TRUE)

fig <- cif %>%
  ggcuminc(outcome = c("Evento dermatológico", "Interrupción sin evento"), linewidth = 0.8) +
  add_confidence_interval() +
  scale_x_continuous(breaks = seq(0, 196, 28), labels = function(x) x / 7) +
  scale_y_continuous(labels = scales::percent, limits = c(0, 1)) +
  labs(
    x = "Semanas desde la primera dosis",
    y = "Incidencia acumulada (Aalen-Johansen)",
    title = "F-14.3.2 Evento dermatológico e interrupción sin evento como riesgos competitivos",
    subtitle = "S3. Línea continua: evento dermatológico; discontinua: interrupción sin evento previo."
  ) +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom")
ggsave("output/A/figuras/f_14_3_2_aalen_johansen.png", fig, width = 8.5, height = 6,
       dpi = 200, bg = "white")

lineas <- c(
  "# T-14.3.4 Análisis de sensibilidad",
  "",
  "Columnas en orden placebo / dosis baja / dosis alta. HR de Cox ajustado por edad frente a placebo.",
  "",
  tabla_md(t1434 %>% rename(
    `Eventos` = eventos, `Incidencia a 12 semanas (1 − KM, %)` = incid_12s,
    `HR dosis baja (IC 95 %)` = hr_baja, `HR dosis alta (IC 95 %)` = hr_alta
  )),
  "",
  "## S3: riesgos competitivos (otro estimando)",
  "",
  "La interrupción del tratamiento sin evento previo se trata como evento competitivo, en",
  "lugar de censura. Responde a: qué proporción tiene un evento de piel antes de interrumpir,",
  "sin suponer que quien interrumpe tendría el mismo riesgo que quien sigue.",
  "",
  tabla_md(cif_12),
  "",
  sprintf("Comparación con 1 − KM a 12 semanas (principal): %s %%.",
          paste(sprintf("%.1f", 100 * (1 - km_12$surv)), collapse = " / ")),
  "",
  sprintf("Test de Gray para el evento dermatológico: p = %s.",
          fmt_p(gray$p.value_1))
)
escribir_md(lineas, "output/A/tlf/t_14_3_4_sensibilidad.md")
cat(lineas, sep = "\n")
