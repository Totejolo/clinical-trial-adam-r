# T-B4 Validación frente a lo publicado

Referencia: Moertel CG et al. Ann Intern Med 1995;122:321-6, informe final con los mismos
929 pacientes en estadio III ([DOI](https://doi.org/10.7326/0003-4819-122-5-199503010-00001)).
Recurrencia: HR de Cox por causa del tiempo hasta la recurrencia. Muerte: HR de Cox de la
supervivencia global. Ambos sin ajustar.

| Comparación | Endpoint | Publicado (reducción) | Este análisis (1 − HR de Cox) |
|---|---|---|---|
| Lev+5FU frente a Obs | Recurrencia | 40 % | 40 % |
| Lev+5FU frente a Obs | Muerte | 33 % | 31 % |
| Lev frente a Obs | Recurrencia | 2 % | 2 % |
| Lev frente a Obs | Muerte | 6 % | 3 % |

# F-B3 Subgrupos

Análisis exploratorio, sin corrección por multiplicidad. Ver `figuras/f_b3_forest_subgrupos.png`.

| Subgrupo | Pacientes (eventos) | HR (IC 95 %) | p interacción |
|---|---|---|---|
| Todos | 619 (291) | 0.69 (0.55 a 0.87) |  |
| Sexo |  |  | 0.042 |
|    Hombre | 307 (139) | 0.52 (0.37 a 0.74) |  |
|    Mujer | 312 (152) | 0.86 (0.63 a 1.19) |  |
| Edad |  |  | 0.775 |
|    <65 | 376 (173) | 0.70 (0.52 a 0.95) |  |
|    >=65 | 243 (118) | 0.66 (0.46 a 0.95) |  |
| Ganglios positivos |  |  | 0.759 |
|    >4 ganglios | 166 (114) | 0.73 (0.50 a 1.06) |  |
|    1-4 ganglios | 453 (177) | 0.66 (0.49 a 0.89) |  |
| Obstrucción |  |  | 0.962 |
|    No | 502 (231) | 0.69 (0.53 a 0.90) |  |
|    Sí | 117 (60) | 0.71 (0.42 a 1.19) |  |
| Diferenciación |  |  | 0.887 |
|    Bien o moderada | 500 (226) | 0.69 (0.53 a 0.90) |  |
|    Pobre | 106 (61) | 0.74 (0.44 a 1.23) |  |
| Extensión local |  |  | 0.813 |
|    Serosa o contigua | 531 (263) | 0.68 (0.53 a 0.87) |  |
|    Submucosa o muscular | 88 (28) | 0.73 (0.35 a 1.55) |  |
