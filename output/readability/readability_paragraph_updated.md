# Readability results, re-run 2026-11-03 on the current data (English-language items only)

Run: `R/analysis.qmd` "Total items", "Readability" and concept-count chunks, re-executed on
`data/item_bank_reporting_guideline_compiled.csv` after adding an English-only filter to the `items`
step (2,312 rows; 2,068 unique English items per guideline after `distinct(study_id, year, reporting_item)`;
56 guidelines; 1999-2025). Full console output is in `readability_results_full.txt`.
Figure: `figures/items_mattr_lexdens_abc_side.png`.

## Updated paragraph

We found that reporting items were relatively verbose (mean words / item = 19.6, SD = 14.5; median = 16,
range 1 to 259; n = 2,068 English-language items). Lexical diversity, as measured by the MATTR, had its
highest observed annual mean in 2011 (0.991, n = 1 checklist) and its lowest in 2023 (0.940, n = 1
checklist); the model-estimated MATTR was highest in 1999 (0.970) and lowest in 2025 (0.954), with an
intercept-based expected overall mean of 0.959 (95% Bayesian Credible Interval, hereon CrI: 0.954 to
0.964). On the 0 to 1 scale, this indicates that words were rarely repeated within items; on average, about
9.6 of every 10 consecutive words were distinct. Although MATTR declined slightly over time (average change
= -0.0006 per year, 95% CrI: -0.0013 to 0.0002), the Bayesian GAMM explained only a small proportion of its
variation (Bayesian R2 = 0.067, 95% CrI: 0.050 to 0.086). For lexical density, the intercept-based expected
mean across all reporting items was 0.540 (95% CrI: 0.514 to 0.567), indicating that just over half of the
words in each item were content-bearing words (e.g., nouns, verbs) rather than function words (e.g.,
articles, prepositions). Its highest observed annual mean was in 2014 (0.651, n = 3 checklists) and its
lowest in 2025 (0.451, n = 1 checklist); the model-estimated lexical density was highest in 1999 (0.605) and
lowest in 2025 (0.499). Lexical density also declined over time (average change = -0.0041 per year, 95% CrI:
-0.0094 to 0.0015), with a steeper estimated decline after 2020 (-0.0063 per year, 95% CrI: -0.0205 to
0.0049) than before (-0.0036 per year, 95% CrI: -0.0090 to 0.0026), and the corresponding model explained a
moderate proportion of variation (Bayesian R2 = 0.418, 95% CrI: 0.396 to 0.439). To assess whether these
linguistic metrics predicted the number of concepts extracted per item (n = 2,027 items from 55
guidelines), we found that higher MATTR was associated with a modest increase in expected concept count,
with each standard deviation increase in MATTR associated with a 6% increase in the number of concepts per
item (IRR = 1.06, 95% CrI: 1.02 to 1.09). Lexical density showed a stronger association, with each standard
deviation increase associated with a 17% increase in concept count (IRR = 1.17, 95% CrI: 1.13 to 1.23). In
both models, longer items (as indexed by log-transformed token count) were associated with substantially
more concepts (MATTR model: IRR = 1.50, 95% CrI: 1.44 to 1.56; lexical density model: IRR = 1.57, 95% CrI:
1.51 to 1.63), consistent with longer items conveying more distinct reporting concepts. See Figure 2 for
the readability measures over time.

## Old vs new numbers

| Quantity | Previous text | Re-run, all languages | Re-run, English only |
|---|---|---|---|
| Items in readability analysis | 2,191 | 2,191 | 2,068 |
| Words per item, mean (SD) | 19.9 (14.7) | 19.9 (14.5) | 19.6 (14.5) |
| MATTR observed max (year, n checklists) | 0.991 (2011, X) | 0.991 (2011, 1) | 0.991 (2011, 1) |
| MATTR observed min (year, n checklists) | 0.939 (2023, X) | 0.940 (2023, 1) | 0.940 (2023, 1) |
| MATTR model-estimated max / min | 0.969 (1999) / 0.952 (2025) | 0.970 / 0.953 | 0.970 (1999) / 0.954 (2025) |
| MATTR intercept mean (95% CrI) | 0.958/0.959 (0.954-0.963) | 0.959 (0.954-0.963) | 0.959 (0.954-0.964) |
| MATTR Bayesian R2 (95% CrI) | 0.079 (0.061-0.099) or 0.065 (0.049-0.083) | 0.072 (0.055-0.091) | 0.067 (0.050-0.086) |
| Lexical density mean (95% CrI) | 0.542 (0.515-0.567) | 0.529 (0.502-0.556) | 0.540 (0.514-0.567) |
| Lexical density observed max | 0.591 (1999, n = 1) | 0.651 (2014, n = 3) | 0.651 (2014, n = 3) |
| Lexical density observed min | 0.496 (2025, n = 1) | 0.451 (2025, n = 1) | 0.451 (2025, n = 1) |
| Lexical density model-estimated max / min | not reported | 0.611 / 0.482 | 0.605 (1999) / 0.499 (2025) |
| Lexical density Bayesian R2 (95% CrI) | 0.398 (0.376-0.418) | 0.430 (0.408-0.449) | 0.418 (0.396-0.439) |
| IRR per SD MATTR | 1.04 (1.00-1.07) | 1.06 (1.02-1.09) | 1.06 (1.02-1.09) |
| IRR per SD lexical density | 1.15 (1.11-1.20) | 1.17 (1.13-1.23) | 1.17 (1.13-1.23) |
| IRR log tokens, MATTR model | 1.36 (1.32-1.42) | 1.50 (1.44-1.56) | 1.50 (1.44-1.56) |
| IRR log tokens, lexical density model | 1.43 (1.38-1.49) | 1.57 (1.51-1.63) | 1.57 (1.51-1.63) |

## Notes on the run

- The English-only filter removed 123 items (81 Portuguese, 42 Spanish) from the readability set and
  3 guidelines (59 to 56). The concept-count models are unchanged because no non-English item has coded
  concepts, so they were never in those models.
- The MATTR and lexical density Beta GAMMs had 1 and 4 divergent transitions respectively out of 8,000
  post-warmup draws (Rhat = 1.00 everywhere). Negligible, but raising adapt_delta would remove them.
- POS tagging used the same english-ewt-ud-2.5 UDPipe model through the ufal.udpipe Python binding,
  because the R udpipe package could not be installed in this environment (CRAN is blocked). It wraps the
  same C++ library, so tokens and tags are the same.
- "n checklists" per year counts distinct `checklist` values among the items analysed in that year.
