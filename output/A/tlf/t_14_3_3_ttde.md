# T-14.3.3 Tiempo hasta el primer evento adverso dermatológico en tratamiento

Población de seguridad. Estimando principal (*while on treatment*), SAP sección 2.

## Eventos y censuras

| Brazo | N | Eventos | Censura: completó | Censura: interrupción por EA | Censura: otra interrupción |
|---|---|---|---|---|---|
| Placebo | 86 | 29 | 37 | 3 | 17 |
| Xanomeline Low Dose | 96 | 63 | 5 | 16 | 12 |
| Xanomeline High Dose | 72 | 60 | 2 | 6 | 4 |

## Incidencia acumulada (1 − KM, %, IC 95 %)

| Brazo | Día | En riesgo | Incidencia (IC 95 %) |
|---|---|---|---|
| Placebo | 84 | 46 | 32.2 (20.8 a 42.0) |
| Placebo | 168 | 39 | 36.6 (24.7 a 46.7) |
| Xanomeline Low Dose | 84 | 13 | 78.6 (66.0 a 86.5) |
| Xanomeline Low Dose | 168 | 5 | 89.0 (77.5 a 94.6) |
| Xanomeline High Dose | 84 | 6 | 88.1 (75.6 a 94.2) |
| Xanomeline High Dose | 168 | 2 | 94.1 (82.6 a 98.0) |

Con pocos sujetos en riesgo la estimación es inestable: véase la columna En riesgo.

## Contrastes

| Contraste | HR (IC 95 %) | p |
|---|---|---|
| Log-rank, 3 brazos |  | <1e-04 |
| Dosis baja frente a placebo (Cox, ajustado por edad) | 4.30 (2.74 a 6.74) | <1e-04 |
| Dosis alta frente a placebo (Cox, ajustado por edad) | 5.47 (3.46 a 8.66) | <1e-04 |
| Dosis alta frente a dosis baja (mismo modelo) | 1.27 (0.89 a 1.82) | 0.18 |
| Tendencia con la dosis, por cada 27 mg | 1.76 (1.52 a 2.03) | <1e-04 |
| Edad, por año | 0.99 (0.97 a 1.01) | 0.38 |

## Riesgos proporcionales (residuos de Schoenfeld)

| Término | p |
|---|---|
| TRT01A | 0.49 |
| AGE | 0.57 |
| GLOBAL | 0.64 |

Un p alto indica falta de evidencia contra la proporcionalidad, no que esté demostrada.
Gráficos en `figuras/f_schoenfeld_ttde.png`.
