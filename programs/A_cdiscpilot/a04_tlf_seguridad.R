# a04_tlf_seguridad.R
# T-14.1.1 características basales, T-14.3.1 resumen de TEAE, T-14.3.2 TEAE por SOC y PT.

suppressPackageStartupMessages({
  library(dplyr, warn.conflicts = FALSE)
  library(rtables)
  library(tern)
})
source("R/funciones.R")

adsl <- readRDS("output/A/datasets/adsl.rds") %>%
  filter(SAFFL == "Y") %>%
  mutate(
    TRT01A = factor(TRT01A, levels = BRAZOS_A),
    SEX = factor(SEX, levels = c("F", "M"), labels = c("Mujer", "Hombre")),
    AGEGR1 = factor(AGEGR1, levels = c("18-64", ">64")),
    RACE = factor(RACE)
  )
adae <- readRDS("output/A/datasets/adae.rds") %>%
  filter(TRTEMFL == "Y") %>%
  semi_join(adsl, by = "USUBJID") %>%
  mutate(TRT01A = factor(TRT01A, levels = BRAZOS_A))

dir.create("output/A/tlf", recursive = TRUE, showWarnings = FALSE)

# T-14.1.1 Características basales
lyt_dem <- basic_table(
  title = "T-14.1.1 Características basales, población de seguridad",
  main_footer = "Datos sintéticos del piloto CDISC (pharmaversesdtm)."
) %>%
  split_cols_by("TRT01A") %>%
  add_overall_col("Total") %>%
  analyze_vars(
    vars = c("AGE", "AGEGR1", "SEX", "RACE"),
    var_labels = c("Edad (años)", "Grupo de edad", "Sexo", "Raza"),
    .stats = c("n", "mean_sd", "median", "range", "count_fraction")
  )
t_dem <- build_table(lyt_dem, adsl)
export_as_txt(t_dem, file = "output/A/tlf/t_14_1_1_demografia.txt", paginate = FALSE)

# T-14.3.1 Resumen de TEAE (sujetos con al menos un evento de cada tipo)
n_brazo <- adsl %>% count(TRT01A, name = "N")
filas <- list(
  "Cualquier TEAE" = adae,
  "TEAE grave" = filter(adae, AESER == "Y"),
  "TEAE relacionado (posible o probable)" = filter(adae, AEREL %in% c("POSSIBLE", "PROBABLE")),
  "TEAE mortal" = filter(adae, AEOUT == "FATAL")
)
t1431 <- bind_rows(
  lapply(names(filas), function(f) {
    filas[[f]] %>% distinct(USUBJID, TRT01A) %>% count(TRT01A) %>% mutate(fila = f)
  }),
  adsl %>% filter(DCSREAS %in% "ADVERSE EVENT") %>% count(TRT01A) %>%
    mutate(fila = "Interrupción del estudio por evento adverso")
) %>%
  tidyr::complete(fila, TRT01A, fill = list(n = 0)) %>%
  mutate(fila = factor(fila, levels = c(names(filas), "Interrupción del estudio por evento adverso"))) %>%
  arrange(fila, TRT01A)

write.csv(t1431 %>% mutate(fila = as.character(fila), TRT01A = as.character(TRT01A)),
          "output/A/tlf/t_14_3_1_resumen_teae.csv", row.names = FALSE)

t1431_ancha <- t1431 %>%
  left_join(n_brazo, by = "TRT01A") %>%
  mutate(valor = fmt_n_pct(n, N)) %>%
  select(fila, TRT01A, valor) %>%
  tidyr::pivot_wider(names_from = TRT01A, values_from = valor) %>%
  rename(`Sujetos con` = fila)
cab <- sprintf("%s (N=%d)", n_brazo$TRT01A, n_brazo$N)
names(t1431_ancha)[-1] <- cab

# T-14.3.2 TEAE por SOC y PT (PT con ≥ 5 % en algún brazo)
lyt_ae <- basic_table(
  title = "T-14.3.2 TEAE por órgano-sistema y término preferente (≥ 5 % en algún brazo)",
  main_footer = "Un sujeto se cuenta una vez por término. TEAE: inicio entre la primera dosis y 30 días tras la última."
) %>%
  split_cols_by("TRT01A") %>%
  add_overall_col("Total") %>%
  analyze_num_patients(
    vars = "USUBJID",
    .stats = "unique",
    .labels = c(unique = "Sujetos con al menos un TEAE")
  ) %>%
  split_rows_by("AEBODSYS", child_labels = "visible", nested = FALSE,
                split_fun = drop_split_levels, label_pos = "topleft",
                split_label = "Órgano-sistema") %>%
  summarize_num_patients(var = "USUBJID", .stats = "unique",
                         .labels = c(unique = "Sujetos con al menos un evento")) %>%
  count_occurrences(vars = "AEDECOD")
t_ae <- build_table(lyt_ae, adae, alt_counts_df = adsl)
t_ae <- prune_table(
  t_ae,
  keep_rows(has_fraction_in_any_col(atleast = 0.05, col_names = levels(adsl$TRT01A)))
)
t_ae <- sort_at_path(t_ae, path = c("AEBODSYS"), scorefun = cont_n_allcols)
export_as_txt(t_ae, file = "output/A/tlf/t_14_3_2_teae_soc_pt.txt", paginate = FALSE)

escribir_md(c(
  "# Tablas de seguridad (parte A)", "",
  "## T-14.3.1 Resumen de TEAE, población de seguridad", "",
  tabla_md(t1431_ancha), "",
  "T-14.1.1 y T-14.3.2 están en formato de texto en esta misma carpeta."
), "output/A/tlf/tablas_seguridad.md")

print(t_dem)
cat("\n")
print(as.data.frame(t1431_ancha))
