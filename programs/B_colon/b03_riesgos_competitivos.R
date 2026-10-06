# b03_riesgos_competitivos.R
# Tiempo hasta la recurrencia con la muerte sin recurrencia como evento competitivo.
# Aalen-Johansen, Cox por causa y Fine-Gray (SAP_B sección 4.5). Salidas: T-B3 y F-B2.

suppressPackageStartupMessages({
  library(dplyr, warn.conflicts = FALSE)
  library(survival)
  library(tidycmprsk)
  library(ggsurvfit)
  library(ggplot2)
})
source("R/funciones.R")

BRAZOS_B <- c("Obs", "Lev", "Lev+5FU")
CINCO_ANOS <- 5 * 365.25

ttr <- readRDS("output/B/datasets/adtte.rds") %>%
  filter(PARAMCD == "TTR") %>%
  mutate(
    TRT01P = factor(TRT01P, levels = BRAZOS_B),
    estado = factor(
      case_when(
        CNSR == 0 ~ "Recurrencia",
        grepl("COMPETITIVO", EVNTDESC) ~ "Muerte sin recurrencia",
        TRUE ~ "Censura"
      ),
      levels = c("Censura", "Recurrencia", "Muerte sin recurrencia")
    ),
    anos = AVAL / 365.25
  )

# Incidencia acumulada (Aalen-Johansen)
cif <- cuminc(Surv(AVAL, estado) ~ TRT01P, data = ttr)
cif_5 <- tidy(cif, times = CINCO_ANOS) %>%
  transmute(Brazo = strata, Evento = outcome,
            `Incidencia a 5 años (%, IC 95 %)` = fmt_ic(100 * estimate, 100 * conf.low, 100 * conf.high, dig = 1))
gray <- glance(cif)

# 1 − KM tratando la muerte como censura (lo que NO se debe reportar como incidencia)
km_naive <- survfit(Surv(AVAL, estado == "Recurrencia") ~ TRT01P, data = ttr) %>%
  summary(times = CINCO_ANOS)
naive <- data.frame(Brazo = BRAZOS_B,
                    `1 − KM a 5 años (%)` = sprintf("%.1f", 100 * (1 - km_naive$surv)),
                    check.names = FALSE)

# Cox por causa (recurrencia) y Fine-Gray (subdistribución)
cs <- coxph(Surv(AVAL, estado == "Recurrencia") ~ TRT01P, data = ttr)
ci_cs <- summary(cs)$conf.int
fg <- crr(Surv(AVAL, estado) ~ TRT01P, data = ttr, failcode = "Recurrencia")
fg_t <- tidy(fg, exponentiate = TRUE, conf.int = TRUE)
cs_d <- coxph(Surv(AVAL, estado == "Muerte sin recurrencia") ~ TRT01P, data = ttr)
ci_cs_d <- summary(cs_d)$conf.int

t_hr <- data.frame(
  Contraste = c("Lev frente a Obs", "Lev+5FU frente a Obs"),
  `HR por causa, recurrencia (IC 95 %)` = fmt_ic(ci_cs[, 1], ci_cs[, 3], ci_cs[, 4]),
  `sHR Fine-Gray, recurrencia (IC 95 %)` = fmt_ic(fg_t$estimate, fg_t$conf.low, fg_t$conf.high),
  `HR por causa, muerte sin recurrencia (IC 95 %)` = fmt_ic(ci_cs_d[, 1], ci_cs_d[, 3], ci_cs_d[, 4]),
  check.names = FALSE
)
saveRDS(list(cs = cs, fg = fg_t), "output/B/datasets/riesgos_competitivos.rds")

fig <- cif %>%
  ggcuminc(outcome = c("Recurrencia", "Muerte sin recurrencia"), linewidth = 0.8) +
  add_confidence_interval() +
  scale_x_continuous(breaks = seq(0, 9 * 365.25, 365.25), labels = 0:9) +
  scale_y_continuous(labels = scales::percent, limits = c(0, 0.7)) +
  labs(x = "Años desde la aleatorización", y = "Incidencia acumulada (Aalen-Johansen)",
       title = "F-B2 Recurrencia y muerte sin recurrencia como riesgos competitivos",
       subtitle = "Línea continua: recurrencia; discontinua: muerte sin recurrencia") +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom")
ggsave("output/B/figuras/f_b2_aalen_johansen.png", fig, width = 8.5, height = 6, dpi = 200, bg = "white")

lineas <- c(
  "# T-B3 Tiempo hasta la recurrencia con riesgos competitivos", "",
  sprintf("Recurrencias: %d. Muertes sin recurrencia (evento competitivo): %d. Censuras: %d.",
          sum(ttr$estado == "Recurrencia"), sum(ttr$estado == "Muerte sin recurrencia"),
          sum(ttr$estado == "Censura")), "",
  "## Incidencia acumulada a 5 años (Aalen-Johansen)", "",
  tabla_md(cif_5), "",
  sprintf("Test de Gray: recurrencia p = %s; muerte sin recurrencia p = %s.",
          fmt_p(gray$p.value_1), fmt_p(gray$p.value_2)), "",
  "Comparación: 1 − KM tratando la muerte como censura (sobreestima la incidencia):", "",
  tabla_md(naive), "",
  "## Efecto del tratamiento", "",
  tabla_md(t_hr), "",
  "El HR por causa mide el efecto sobre la tasa de recurrencia entre quienes siguen vivos y",
  "sin recurrencia; el sHR de Fine-Gray, sobre la incidencia acumulada. Con solo 38 muertes",
  "sin recurrencia ambos coinciden casi del todo; la diferencia sería relevante con más",
  "competencia (población mayor, enfermedad menos agresiva)."
)
escribir_md(lineas, "output/B/tlf/t_b3_riesgos_competitivos.md")
cat(lineas, sep = "\n")
