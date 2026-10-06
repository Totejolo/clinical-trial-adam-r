# a05_tte_principal.R
# Análisis principal del tiempo hasta el primer EA dermatológico (SAP, sección 5).
# Salidas: T-14.3.3 y F-14.3.1.

suppressPackageStartupMessages({
  library(dplyr, warn.conflicts = FALSE)
  library(survival)
  library(ggsurvfit)
  library(ggplot2)
})
source("R/funciones.R")

dir.create("output/A/tlf", recursive = TRUE, showWarnings = FALSE)
dir.create("output/A/figuras", recursive = TRUE, showWarnings = FALSE)

adtte <- readRDS("output/A/datasets/adtte.rds") %>%
  filter(PARAMCD == "TTDE") %>%
  mutate(
    EVENTO = 1 - CNSR,
    TRT01A = factor(TRT01A, levels = BRAZOS_A)
  )

# 1. Incidencia acumulada con IC 95 % y sujetos en riesgo a las semanas 12 y 24
km <- survfit(Surv(AVAL, EVENTO) ~ TRT01A, data = adtte)
tiempos <- c(semana_12 = 84, semana_24 = 168)
s <- summary(km, times = tiempos, extend = TRUE)
incid <- data.frame(
  TRT01A = sub("TRT01A=", "", as.character(s$strata)),
  dia = s$time,
  en_riesgo = s$n.risk,
  incidencia = fmt_ic(100 * (1 - s$surv), 100 * (1 - s$upper), 100 * (1 - s$lower), dig = 1)
)

# 2. Eventos y censuras por motivo
eventos <- adtte %>%
  group_by(TRT01A) %>%
  summarise(
    N = n(),
    eventos = sum(EVENTO),
    cens_completado = sum(CNSDTDSC %in% "TRATAMIENTO COMPLETADO"),
    cens_interrupcion_ea = sum(CNSDTDSC %in% "INTERRUPCION POR EA"),
    cens_otra = sum(CNSDTDSC %in% "OTRA INTERRUPCION"),
    .groups = "drop"
  )

# 3. Log-rank, Cox, contraste entre dosis y tendencia con la dosis
lr <- survdiff(Surv(AVAL, EVENTO) ~ TRT01A, data = adtte)
p_lr <- pchisq(lr$chisq, df = length(lr$n) - 1, lower.tail = FALSE)

cox <- coxph(Surv(AVAL, EVENTO) ~ TRT01A + AGE, data = adtte)
b <- coef(cox)
v <- vcov(cox)
ci <- summary(cox)$conf.int
hr_fila <- function(nombre) fmt_ic(ci[nombre, 1], ci[nombre, 3], ci[nombre, 4])

# Dosis alta frente a dosis baja a partir de los coeficientes del mismo modelo
hi <- "TRT01AXanomeline High Dose"
lo <- "TRT01AXanomeline Low Dose"
d <- b[hi] - b[lo]
se_d <- sqrt(v[hi, hi] + v[lo, lo] - 2 * v[hi, lo])
hr_alta_baja <- fmt_ic(exp(d), exp(d - 1.96 * se_d), exp(d + 1.96 * se_d))
p_alta_baja <- 2 * pnorm(-abs(d / se_d))

# Tendencia: dosis (0, 54, 81 mg) como variable continua, HR por cada 27 mg
cox_dosis <- coxph(Surv(AVAL, EVENTO) ~ I(TRT01AN / 27) + AGE, data = adtte)
ci_d <- summary(cox_dosis)$conf.int
p_tend <- summary(cox_dosis)$coefficients[1, "Pr(>|z|)"]

# 4. Riesgos proporcionales
zph <- cox.zph(cox)
png("output/A/figuras/f_schoenfeld_ttde.png", width = 1600, height = 600, res = 150)
par(mfrow = c(1, 2))
plot(zph[1], main = "Brazo (residuos de Schoenfeld)")
plot(zph[2], main = "Edad (residuos de Schoenfeld)")
dev.off()

# F-14.3.1
fig <- survfit2(Surv(AVAL / 7, EVENTO) ~ TRT01A, data = adtte) %>%
  ggsurvfit(type = "risk", linewidth = 0.8) +
  add_confidence_interval() +
  add_risktable(risktable_stats = c("n.risk", "cum.event"),
                stats_label = list(n.risk = "En riesgo", cum.event = "Eventos acumulados")) +
  scale_x_continuous(breaks = seq(0, 28, 4)) +
  scale_y_continuous(labels = scales::percent, limits = c(0, 1)) +
  labs(
    x = "Semanas desde la primera dosis",
    y = "Incidencia acumulada (1 - KM)",
    title = "F-14.3.1 Primer evento adverso dermatológico en tratamiento",
    subtitle = "Población de seguridad. Censura al terminar el tratamiento."
  ) +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom")
ggsave("output/A/figuras/f_14_3_1_incidencia_ttde.png", fig, width = 8.5, height = 6.5,
       dpi = 200, bg = "white")

# T-14.3.3
lineas <- c(
  "# T-14.3.3 Tiempo hasta el primer evento adverso dermatológico en tratamiento",
  "",
  "Población de seguridad. Estimando principal (*while on treatment*), SAP sección 2.",
  "",
  "## Eventos y censuras",
  "",
  tabla_md(eventos %>% rename(
    Brazo = TRT01A, Eventos = eventos, `Censura: completó` = cens_completado,
    `Censura: interrupción por EA` = cens_interrupcion_ea, `Censura: otra interrupción` = cens_otra
  )),
  "",
  "## Incidencia acumulada (1 − KM, %, IC 95 %)",
  "",
  tabla_md(incid %>% rename(Brazo = TRT01A, Día = dia, `En riesgo` = en_riesgo,
                            `Incidencia (IC 95 %)` = incidencia)),
  "",
  "Con pocos sujetos en riesgo la estimación es inestable: véase la columna En riesgo.",
  "",
  "## Contrastes",
  "",
  tabla_md(data.frame(
    Contraste = c("Log-rank, 3 brazos", "Dosis baja frente a placebo (Cox, ajustado por edad)",
                  "Dosis alta frente a placebo (Cox, ajustado por edad)",
                  "Dosis alta frente a dosis baja (mismo modelo)",
                  "Tendencia con la dosis, por cada 27 mg", "Edad, por año"),
    `HR (IC 95 %)` = c("", hr_fila(lo), hr_fila(hi), hr_alta_baja,
                       fmt_ic(ci_d[1, 1], ci_d[1, 3], ci_d[1, 4]), hr_fila("AGE")),
    p = c(fmt_p(p_lr), fmt_p(summary(cox)$coefficients[lo, 5]),
          fmt_p(summary(cox)$coefficients[hi, 5]), fmt_p(p_alta_baja), fmt_p(p_tend),
          fmt_p(summary(cox)$coefficients["AGE", 5])),
    check.names = FALSE
  )),
  "",
  "## Riesgos proporcionales (residuos de Schoenfeld)",
  "",
  tabla_md(data.frame(Término = rownames(zph$table), p = fmt_p(zph$table[, "p"]))),
  "",
  "Un p alto indica falta de evidencia contra la proporcionalidad, no que esté demostrada.",
  "Gráficos en `figuras/f_schoenfeld_ttde.png`."
)
escribir_md(lineas, "output/A/tlf/t_14_3_3_ttde.md")
cat(lineas, sep = "\n")
