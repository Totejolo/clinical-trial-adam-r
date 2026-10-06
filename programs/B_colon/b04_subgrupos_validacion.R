# b04_subgrupos_validacion.R
# F-B3 forest plot de subgrupos (OS, Lev+5FU frente a Obs) y T-B4 validación frente a lo
# publicado (SAP_B secciones 4.6 y 4.7; cifras en docs/dossier_literatura_colon.md).

suppressPackageStartupMessages({
  library(dplyr, warn.conflicts = FALSE)
  library(survival)
  library(forestploter)
  library(grid)
})
source("R/funciones.R")

adsl <- readRDS("output/B/datasets/adsl.rds")
os <- readRDS("output/B/datasets/adtte.rds") %>%
  filter(PARAMCD == "OS", TRT01P %in% c("Obs", "Lev+5FU")) %>%
  mutate(EVENTO = 1 - CNSR, TRT = factor(TRT01P, levels = c("Obs", "Lev+5FU"))) %>%
  left_join(select(adsl, USUBJID, AGEGR1, SEX, NODE4, OBSTRUCT, DIFFER, EXTENT), by = "USUBJID") %>%
  mutate(
    DIFFER2 = if_else(DIFFER == "Pobre", "Pobre", "Bien o moderada"),
    EXTENT2 = if_else(EXTENT %in% c("Submucosa", "Muscular"), "Submucosa o muscular", "Serosa o contigua")
  )

subgrupos <- c(SEX = "Sexo", AGEGR1 = "Edad", NODE4 = "Ganglios positivos",
               OBSTRUCT = "Obstrucción", DIFFER2 = "Diferenciación", EXTENT2 = "Extensión local")

fila_hr <- function(d) {
  m <- coxph(Surv(AVAL, EVENTO) ~ TRT, data = d)
  ci <- summary(m)$conf.int
  c(n = nrow(d), ev = sum(d$EVENTO), hr = ci[1, 1], lo = ci[1, 3], hi = ci[1, 4])
}

global <- fila_hr(os)
filas <- list(data.frame(Subgrupo = "Todos", n = global["n"], ev = global["ev"],
                         hr = global["hr"], lo = global["lo"], hi = global["hi"], p_int = NA))
for (v in names(subgrupos)) {
  d <- filter(os, !is.na(.data[[v]])) %>% mutate(GRUPO = factor(.data[[v]]))
  m0 <- coxph(Surv(AVAL, EVENTO) ~ TRT + GRUPO, data = d)
  m1 <- coxph(Surv(AVAL, EVENTO) ~ TRT * GRUPO, data = d)
  p_int <- anova(m0, m1)[2, "Pr(>|Chi|)"]
  filas[[length(filas) + 1]] <- data.frame(Subgrupo = subgrupos[[v]], n = NA, ev = NA, hr = NA,
                                           lo = NA, hi = NA, p_int = p_int)
  for (nivel in sort(unique(d[[v]]))) {
    r <- fila_hr(filter(d, .data[[v]] == nivel))
    filas[[length(filas) + 1]] <- data.frame(Subgrupo = paste0("   ", nivel), n = r["n"], ev = r["ev"],
                                             hr = r["hr"], lo = r["lo"], hi = r["hi"], p_int = NA)
  }
}
fp <- bind_rows(filas)
rownames(fp) <- NULL

tabla_fp <- fp %>%
  transmute(
    Subgrupo,
    `Pacientes (eventos)` = ifelse(is.na(n), "", sprintf("%d (%d)", n, ev)),
    ` ` = paste(rep(" ", 22), collapse = ""),
    `HR (IC 95 %)` = ifelse(is.na(hr), "", fmt_ic(hr, lo, hi)),
    `p interacción` = ifelse(is.na(p_int), "", fmt_p(p_int))
  )
g <- forest(tabla_fp, est = fp$hr, lower = fp$lo, upper = fp$hi, ci_column = 3,
            ref_line = 1, x_trans = "log", xlim = c(0.25, 2), ticks_at = c(0.25, 0.5, 1, 2),
            title = "F-B3 Supervivencia global por subgrupos: Lev+5FU frente a observación")
png("output/B/figuras/f_b3_forest_subgrupos.png", width = 2200, height = 1500, res = 200)
grid.draw(g)
dev.off()

# T-B4 validación frente al informe final (Moertel 1995, Ann Intern Med 122:321)
cox_os <- readRDS("output/B/datasets/cox_sin_ajustar.rds")$OS
cs <- readRDS("output/B/datasets/riesgos_competitivos.rds")$cs
red <- function(m, term) sprintf("%.0f %%", 100 * (1 - exp(coef(m)[term])))
validacion <- data.frame(
  Comparación = c("Lev+5FU frente a Obs", "Lev+5FU frente a Obs", "Lev frente a Obs", "Lev frente a Obs"),
  Endpoint = c("Recurrencia", "Muerte", "Recurrencia", "Muerte"),
  `Publicado (reducción)` = c("40 %", "33 %", "2 %", "6 %"),
  `Este análisis (1 − HR de Cox)` = c(red(cs, "TRT01PLev+5FU"), red(cox_os, "TRT01PLev+5FU"),
                                      red(cs, "TRT01PLev"), red(cox_os, "TRT01PLev")),
  check.names = FALSE
)
escribir_md(c(
  "# T-B4 Validación frente a lo publicado", "",
  "Referencia: Moertel CG et al. Ann Intern Med 1995;122:321-6, informe final con los mismos",
  "929 pacientes en estadio III ([DOI](https://doi.org/10.7326/0003-4819-122-5-199503010-00001)).",
  "Recurrencia: HR de Cox por causa del tiempo hasta la recurrencia. Muerte: HR de Cox de la",
  "supervivencia global. Ambos sin ajustar.", "",
  tabla_md(validacion), "",
  "# F-B3 Subgrupos", "",
  "Análisis exploratorio, sin corrección por multiplicidad. Ver `figuras/f_b3_forest_subgrupos.png`.", "",
  tabla_md(tabla_fp[, c(1, 2, 4, 5)])
), "output/B/tlf/t_b4_validacion_subgrupos.md")
print(validacion)
print(tabla_fp[, c(1, 2, 4, 5)])
