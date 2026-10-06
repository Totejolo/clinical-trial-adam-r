# 04_analisis.R
# Incidencia acumulada (1 - Kaplan-Meier) por brazo, log-rank y Cox ajustado por edad.

suppressPackageStartupMessages({
  library(dplyr, warn.conflicts = FALSE)
  library(survival)
  library(ggsurvfit)
  library(ggplot2)
})

brazos <- c("Placebo", "Xanomeline Low Dose", "Xanomeline High Dose")

adtte <- readRDS("output/adtte.rds") %>%
  mutate(
    EVENTO = 1 - CNSR,
    SEMANAS = AVAL / 7,
    TRT01A = factor(TRT01A, levels = brazos)
  )

km <- survfit2(Surv(SEMANAS, EVENTO) ~ TRT01A, data = adtte)

figura <- ggsurvfit(km, type = "risk", linewidth = 0.8) +
  add_confidence_interval() +
  add_risktable(risktable_stats = "n.risk") +
  scale_x_continuous(breaks = seq(0, 28, 4)) +
  scale_y_continuous(labels = scales::percent, limits = c(0, 1)) +
  labs(
    x = "Semanas desde el inicio del tratamiento",
    y = "Incidencia acumulada",
    title = "Primer evento adverso dermatológico durante el tratamiento",
    subtitle = "1 - Kaplan-Meier, población de seguridad (datos sintéticos del piloto CDISC)"
  ) +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom")

ggsave("output/incidencia_dermatologica.png", figura, width = 8, height = 6, dpi = 200, bg = "white")

# Resumen por brazo
tab_km <- summary(km)$table
a12 <- summary(km, times = 12, extend = TRUE)
resumen <- adtte %>%
  group_by(TRT01A) %>%
  summarise(n = n(), eventos = sum(EVENTO), .groups = "drop") %>%
  mutate(
    mediana_semanas = round(tab_km[, "median"], 1),
    incidencia_12s = sprintf("%.0f %%", 100 * (1 - a12$surv))
  )

# Contrastes
logrank <- survdiff(Surv(SEMANAS, EVENTO) ~ TRT01A, data = adtte)
p_logrank <- pchisq(logrank$chisq, df = length(logrank$n) - 1, lower.tail = FALSE)

cox <- coxph(Surv(SEMANAS, EVENTO) ~ TRT01A + AGE, data = adtte)
ci <- summary(cox)$conf.int
zph <- cox.zph(cox)

fmt_hr <- function(fila) sprintf("%.2f (%.2f a %.2f)", ci[fila, 1], ci[fila, 3], ci[fila, 4])

lineas <- c(
  "# Resultados",
  "",
  "Población de seguridad, datos sintéticos del piloto CDISC (pharmaversesdtm).",
  "",
  "| Brazo | N | Eventos | Mediana (semanas) | Incidencia a 12 semanas (KM) |",
  "|---|---|---|---|---|",
  sprintf("| %s | %d | %d | %s | %s |", resumen$TRT01A, resumen$n, resumen$eventos,
          ifelse(is.na(resumen$mediana_semanas), "no alcanzada", resumen$mediana_semanas),
          resumen$incidencia_12s),
  "",
  sprintf("Log-rank (3 brazos): p = %s", format.pval(p_logrank, digits = 2, eps = 1e-4)),
  "",
  "Cox ajustado por edad (referencia: placebo)",
  "",
  "| Término | HR (IC 95 %) |",
  "|---|---|",
  sprintf("| Xanomelina dosis baja | %s |", fmt_hr("TRT01AXanomeline Low Dose")),
  sprintf("| Xanomelina dosis alta | %s |", fmt_hr("TRT01AXanomeline High Dose")),
  sprintf("| Edad (por año) | %s |", fmt_hr("AGE")),
  "",
  sprintf("Riesgos proporcionales (cox.zph, test global): p = %s",
          format.pval(zph$table["GLOBAL", "p"], digits = 2, eps = 1e-4))
)
writeLines(lineas, "output/resultados.md", useBytes = TRUE)
cat(lineas, sep = "\n")
