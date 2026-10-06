# Dossier de literatura: ensayo de levamisol y 5-FU en cáncer de colon estadio III

Fuente: PubMed (consultado el 2026-10-05). Verificación cruzada pendiente con Claude Science.

## Publicaciones de referencia

| Ref. | Publicación | Población | Seguimiento | Lev+5FU frente a observación | Levamisol solo |
|---|---|---|---|---|---|
| [1] | Moertel CG et al. *N Engl J Med* 1990;322:352-8. [DOI](https://doi.org/10.1056/NEJM199002083220602) | 1.296 pacientes (estadios B2 y C); análisis del estadio C | Mediana 3 años (2 a 5,5) | Estadio C: riesgo de recurrencia −41 % (p < 0,0001); mortalidad global −33 % (p ≈ 0,006) | Sin efecto detectable |
| [2] | Moertel CG et al. *Ann Intern Med* 1995;122:321-6 (informe final). [DOI](https://doi.org/10.7326/0003-4819-122-5-199503010-00001) | **929 pacientes elegibles en estadio III (Dukes C)**, todos con ≥ 5 años de seguimiento | Mediana 6,5 años | Tasa de recurrencia −40 % (p < 0,0001); tasa de muerte −33 % (p = 0,0007) | Recurrencia −2 %; muerte −6 % |
| [3] | Moertel CG et al. *J Clin Oncol* 1995;13:2936-43 (INT-0035, estadio II). [DOI](https://doi.org/10.1200/JCO.1995.13.12.2936) | 318 pacientes en estadio II | Mediana 7 años | No aplica a este dataset (estadio II) | No aplica |

## Relación con `survival::colon`

- 929 pacientes y tres brazos (Obs, Lev, Lev+5FU): coincide con la población del informe
  final de 1995 [2]. Es la referencia principal para validar.
- Pauta [2]: levamisol 50 mg orales tres veces al día durante 3 días cada 2 semanas durante
  1 año; 5-FU 450 mg/m² IV diario 5 días y, desde el día 28, semanal durante 48 semanas.
- Grupos cooperativos [2]: North Central Cancer Treatment Group, Southwest Oncology Group y
  Eastern Cooperative Oncology Group.

## Objetivo de validación (parte B)

Las "reducciones de tasa" publicadas se comparan con 1 − HR de Cox. No son exactamente la
misma medida (el artículo no detalla en el resumen el método), así que se espera
concordancia aproximada, no idéntica:

| Comparación | Endpoint | Publicado [2] | HR esperado aproximado |
|---|---|---|---|
| Lev+5FU frente a Obs | Recurrencia | −40 % | ≈ 0,60 |
| Lev+5FU frente a Obs | Muerte | −33 % | ≈ 0,67 |
| Lev frente a Obs | Recurrencia | −2 % | ≈ 0,98 |
| Lev frente a Obs | Muerte | −6 % | ≈ 0,94 |

## Verificación cruzada con Claude Science (2026-10-06)

Dossier completo, figura y tabla de Cox en `docs/claude_science/`. Resumen:

- **Cifras publicadas confirmadas** contra PubMed y CrossRef: NEJM 1990 (1.296 pacientes,
  estadio C −41 % recurrencia, −33 % mortalidad) y Ann Intern Med 1995 (929 pacientes,
  mediana 6,5 años, −40 % / −33 %; levamisol −2 % / −6 %). Sin retractaciones.
- **No verificable:** el texto completo de 1995 está tras muro de pago; no se pudieron
  comprobar HR, IC, supervivencia a 5 años por brazo ni el método exacto. Que las
  "reducciones" sean 100 × (1 − HR) de Cox es una inferencia apoyada por los reanálisis.
- **Tercera comprobación independiente:** su propio Cox sobre `survival::colon` da recurrencia
  HR 0,60 (0,47 a 0,76) y muerte HR 0,69 (0,55 a 0,87) para Lev+5FU, idéntico a nuestro
  análisis. Con su modelo ajustado (ganglios como número continuo), la mortalidad con
  levamisol solo baja un 6,6 %, cerca del 6 % publicado; no se puede saber qué modelo usó
  el artículo.
- **Errores en la documentación de `survival` 3.8.12** (comprobados también por Claude Code
  con `tools::Rd_db`): cita el NEJM como volumen 332 en lugar de 322, y describe el informe
  final de Annals como "stage II … 1991" cuando es estadio III y 1995. El título llama a los
  929 registros "stage B/C", pero son solo estadio III (el estrato B2, 318 pacientes, se
  publicó aparte: J Clin Oncol 1995;13:2936, PMID 8523058). La discordancia entre `nodes` y
  `node4` afecta a 12 de los 911 pacientes con ganglios registrados.
- **Reanálisis del mismo dataset**, útiles para ampliar el proyecto: Therneau et al. 2024,
  Clin Trials (PMID 39095982), modelos multiestado; Mao 2023, Biometrics (PMID 34562019),
  *restricted mean time in favor of treatment*; Lin 1994, Stat Med (PMID 7846422).
