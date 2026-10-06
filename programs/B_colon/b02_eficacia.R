# b02_eficacia.R
# T-B1 características basales, T-B2 resumen de eficacia (OS y RFS), F-B1 Kaplan-Meier.
# SAP_B secciones 4.1 a 4.4.

suppressPackageStartupMessages({
  library(dplyr, warn.conflicts = FALSE)
  library(survival)
  library(ggsurvfit)
  library(ggplot2)
  library(rtables)
  library(tern)
})
source("R/funciones.R")

BRAZOS_B <- c("Obs", "Lev", "Lev+5FU")
CINCO_ANOS <- 5 * 365.25

adsl <- readRDS("output/B/datasets/adsl.rds") %>%
  mutate(TRT01P = factor(TRT01P, levels = BRAZOS_B))
adtte <- readRDS("output/B/datasets/adtte.rds") %>%
  mutate(EVENTO = 1 - CNSR, TRT01P = factor(TRT01P, levels = BRAZOS_B)) %>%
  left_join(select(adsl, -STUDYID, -TRT01P, -TRT01PN), by = "USUBJID")

dir.create("output/B/tlf", recursive = TRUE, showWarnings = FALSE)
dir.create("output/B/figuras", recursive = TRUE, showWarnings = FALSE)

# T-B1 Características basales
lyt <- basic_table(title = "T-B1 Características basales por brazo") %>%
  split_cols_by("TRT01P") %>%
  add_overall_col("Total") %>%
  analyze_vars(
    vars = c("AGE", "SEX", "NODES", "NODE4", "DIFFER", "EXTENT", "OBSTRUCT", "PERFOR",
             "ADHERE", "SURG"),
    var_labels = c("Edad (años)", "Sexo", "Ganglios positivos", "Ganglios", "Diferenciación",
                   "Extensión local", "Obstrucción", "Perforación", "Adherencia a órganos",
                   "Tiempo cirugía-registro"),
    .stats = c("n", "mean_sd", "median", "count_fraction")
  )
t_b1 <- build_table(lyt, adsl %>% mutate(across(c(SEX, NODE4, OBSTRUCT, PERFOR, ADHERE, SURG), factor)))
export_as_txt(t_b1, file = "output/B/tlf/t_b1_basales.txt", paginate = FALSE)

# Resumen de eficacia de un endpoint
resumen_endpoint <- function(pc) {
  d <- filter(adtte, PARAMCD == pc)
  km <- survfit(Surv(AVAL, EVENTO) ~ TRT01P, data = d)
  s5 <- summary(km, times = CINCO_ANOS)
  tab <- summary(km, rmean = CINCO_ANOS)$table
  med <- tab[, "median"] / 365.25

  por_brazo <- data.frame(
    Brazo = BRAZOS_B,
    N = as.integer(table(d$TRT01P)),
    Eventos = as.integer(tapply(d$EVENTO, d$TRT01P, sum)),
    `Mediana (años)` = ifelse(is.na(med), "no alcanzada", sprintf("%.1f", med)),
    `A 5 años (KM, %, IC 95 %)` = fmt_ic(100 * s5$surv, 100 * s5$lower, 100 * s5$upper, dig = 1),
    `RMST a 5 años (años)` = sprintf("%.2f", tab[, "rmean"] / 365.25),
    check.names = FALSE
  )

  # Cox sin ajustar y ajustado; contrastes frente a Obs y Lev+5FU frente a Lev
  cox_u <- coxph(Surv(AVAL, EVENTO) ~ TRT01P, data = d)
  cox_a <- coxph(Surv(AVAL, EVENTO) ~ TRT01P + AGE + SEX + OBSTRUCT + PERFOR + ADHERE +
                   NODE4 + DIFFER + EXTENT + SURG, data = d)
  hr <- function(m, a, b = NULL) {
    cf <- coef(m); v <- vcov(m)
    est <- unname(cf[a] - if (is.null(b)) 0 else cf[b])
    se <- sqrt(v[a, a] + if (is.null(b)) 0 else v[b, b] - 2 * v[a, b])
    c(hr = exp(est), lo = exp(est - 1.96 * se), hi = exp(est + 1.96 * se), p = 2 * pnorm(-abs(est / se)))
  }
  contr <- list(
    "Lev frente a Obs" = list("TRT01PLev", NULL),
    "Lev+5FU frente a Obs" = list("TRT01PLev+5FU", NULL),
    "Lev+5FU frente a Lev" = list("TRT01PLev+5FU", "TRT01PLev")
  )
  hrs <- bind_rows(lapply(names(contr), function(n) {
    u <- hr(cox_u, contr[[n]][[1]], contr[[n]][[2]])
    a <- hr(cox_a, contr[[n]][[1]], contr[[n]][[2]])
    data.frame(Contraste = n,
               `HR sin ajustar (IC 95 %)` = fmt_ic(u["hr"], u["lo"], u["hi"]),
               p = fmt_p(u["p"]),
               `HR ajustado (IC 95 %)` = fmt_ic(a["hr"], a["lo"], a["hi"]),
               `p ajustado` = fmt_p(a["p"]),
               check.names = FALSE)
  }))

  # RMST: diferencia frente a Obs (grupos independientes)
  se_col <- grep("se\\(rmean\\)", colnames(tab), value = TRUE)
  rmst <- bind_rows(lapply(2:3, function(i) {
    dif <- (tab[i, "rmean"] - tab[1, "rmean"]) / 365.25
    se <- sqrt(tab[i, se_col]^2 + tab[1, se_col]^2) / 365.25
    data.frame(Contraste = paste(BRAZOS_B[i], "frente a Obs"),
               `Diferencia de RMST a 5 años (años, IC 95 %)` = fmt_ic(dif, dif - 1.96 * se, dif + 1.96 * se),
               p = fmt_p(2 * pnorm(-abs(dif / se))),
               check.names = FALSE)
  }))

  lr <- survdiff(Surv(AVAL, EVENTO) ~ TRT01P, data = d)
  zph <- cox.zph(cox_u)

  list(km = km, por_brazo = por_brazo, hrs = hrs, rmst = rmst,
       p_lr = pchisq(lr$chisq, 2, lower.tail = FALSE),
       p_ph = zph$table["GLOBAL", "p"], n_ajustado = cox_a$n, cox_u = cox_u)
}

res <- list(OS = resumen_endpoint("OS"), RFS = resumen_endpoint("RFS"))
saveRDS(lapply(res, function(r) r$cox_u), "output/B/datasets/cox_sin_ajustar.rds")

# F-B1
titulos <- c(OS = "Supervivencia global", RFS = "Supervivencia libre de recurrencia")
for (pc in names(res)) {
  fig <- survfit2(Surv(AVAL / 365.25, EVENTO) ~ TRT01P, data = filter(adtte, PARAMCD == pc)) %>%
    ggsurvfit(linewidth = 0.8) +
    add_confidence_interval() +
    add_risktable(risktable_stats = "n.risk", stats_label = list(n.risk = "En riesgo")) +
    scale_x_continuous(breaks = 0:9) +
    scale_y_continuous(labels = scales::percent, limits = c(0, 1)) +
    labs(x = "Años desde la aleatorización", y = "Probabilidad",
         title = paste("F-B1", titulos[[pc]]),
         subtitle = "Cáncer de colon estadio III, 929 pacientes (survival::colon)") +
    theme_minimal(base_size = 11) +
    theme(legend.position = "bottom")
  ggsave(sprintf("output/B/figuras/f_b1_km_%s.png", tolower(pc)), fig,
         width = 8.5, height = 6.5, dpi = 200, bg = "white")
}

lineas <- c("# T-B2 Resumen de eficacia", "")
for (pc in names(res)) {
  r <- res[[pc]]
  lineas <- c(lineas,
    paste("##", titulos[[pc]]), "",
    tabla_md(r$por_brazo), "",
    sprintf("Log-rank (3 brazos): p = %s. Riesgos proporcionales, test global de Schoenfeld: p = %s.",
            fmt_p(r$p_lr), fmt_p(r$p_ph)), "",
    tabla_md(r$hrs), "",
    sprintf("Modelo ajustado: edad, sexo, obstrucción, perforación, adherencia, > 4 ganglios, diferenciación, extensión y tiempo cirugía-registro; %d pacientes con datos completos.",
            r$n_ajustado), "",
    tabla_md(r$rmst), "")
}
escribir_md(lineas, "output/B/tlf/t_b2_eficacia.md")
cat(lineas, sep = "\n")
