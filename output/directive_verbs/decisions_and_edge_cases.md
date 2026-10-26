# Directive verbs: decisions and edge cases to check

Generated from the "Directive verbs in reporting items" section of `R/analysis.qmd` (the outputs in this folder are written by that section). Parameters: MULTI_VERB_RULE = "first", HARMONISE_SPELLING = TRUE, DV_SEED = 2026.

## 0. Files and columns used

| Need | File | Column(s) |
|---|---|---|
| Verbatim item text | data/item_bank_reporting_guideline_compiled.csv | reporting_item |
| Item ID | same | checklist_item_id |
| Checklist ID | same | checklist (68 checklists; 60 guidelines have >1 checklist in 4 cases, e.g. page_2021 / page_2021_abstract / page_2021_extended) |
| Guideline ID | same | study_id |
| Manuscript section | item-level: standardised_section in the compiled file (9 levels incl. 'Methods', 'Other', NA); concept-level: standardised_section in the concepts file (7 clean levels). Analysis 2 by section uses the concepts file. |
| Item-to-concept mapping | data/item_bank_reporting_guideline_concepts.csv | checklist_item_id x standardised_reporting_item_elements (one row per item x concept) |
| Language | compiled file | language (english / portuguese / spanish) |

## 1. Decisions taken (please confirm)

1. **Non-English items excluded.** 135 items in 5 Portuguese/Spanish checklists (galvao_2015, galvao_2022, galvao_2022_abstracts, yepes.nunez_2021, yepes.nunez_2021_abstracts) are not tagged with the English model; verb = NA, reason 'non-English item'. All analyses use the 2177 English items in 63 checklists.
2. **Directive verb = lemma of the first imperative verb that opens the item** after skipping (a) list numbering/bullets/quotes, (b) a leading conditional or scoping phrase ending in a comma, colon or semicolon ('If applicable,', 'For each study,', 'In the title,', 'Where appropriate,'; up to three nested phrases), (c) a short label before a colon ('Background: state ...', 'Timing: describe ...'), and (d) adverbs/particles ('Please', 'Clearly', 'Briefly').
3. **udpipe tagging alone is not sufficient.** udpipe (english-ewt) tags most sentence-initial imperatives wrongly ('Describe' as AUX/ADJ, 'Report' as NOUN, 'Present' as ADJ, 'List' as NOUN). The extraction therefore uses udpipe for tokenisation, lemmatisation, POS tags of the surrounding tokens and the dependency parse, combined with a curated lexicon (verb_lexicon.csv):
   - *strong* directive verbs are accepted whenever they open the item in base form and are not followed by 'of' ('List of citations', 'Use of hand searching' are noun phrases);
   - *ambiguous* words that also open noun phrases in this corpus ('search', 'study', 'reference', 'time', 'effect', 'number', 'type', ...) are accepted only when followed by a determiner, pronoun, number, wh-word or 'at'/'about' ('Search at least two databases' yes; 'Search terms used' no);
   - any other token tagged VERB/VB by udpipe is accepted under the same contextual condition.
   Items accepted by source: lexicon (strong verb) = 1654; lexicon (ambiguous word) + context = 3; udpipe VERB/VB + context = 2.
4. **Items without an initial directive verb** get verb = NA with a reason: non-English; placeholder ('Not applicable for scoping reviews'); question / indirect question (first word How/What/Whether/Were/...); declarative or modal statement (first sentence has a subject attached to the root verb in the parse, or contains should/must/may/need to: 'The title must indicate ...', 'Authors should report ...', 'Abstract contains ...'); otherwise noun phrase or fragment ('Description of ...', 'Study eligibility criteria', 'Reporting of Discussion').
   Counts (English items): noun phrase or fragment (no initial verb) = 347; declarative or modal statement (subject + finite verb, e.g. 'The title must ...', 'Authors should ...') = 133; question or indirect question (How ..., Whether ..., Were ...) = 33; placeholder (not applicable) = 5.
5. **Multi-verb items** ('Describe and justify ...', 'List and define ...', 'compare and contrast'): the FIRST verb is used (MULTI_VERB_RULE = "first"); all coordinated verbs are kept in `coordinated_verbs`. 60 English items are affected. Alternative built into the script: MULTI_VERB_RULE = "exclude". **Your call.**
6. **No synonyms merged.** 'report', 'provide', 'describe', 'state', 'specify', 'present', 'give' etc. are kept distinct. Only British/American spelling variants are harmonised (summarise -> summarize, synthesise -> synthesize, pre-register -> preregister); `verb_raw` keeps the original lemma. Set HARMONISE_SPELLING = FALSE to switch this off. **Your call.**
7. **'See the PRISMA 2020 for Abstracts checklist'** (cross-reference items) open with the verb 'see' and are counted as such but flagged; you may prefer to treat them as NA.
8. **Checklist-level metrics** are computed on items with a directive verb; `n_items` (all English items) and `n_items_with_verb` are both reported. Across-checklist summaries use checklists with >= 1 verb-bearing item (primary) and >= 5 verb-bearing items (sensitivity). Pielou's J is undefined (NA) when a checklist uses a single verb. Rarefaction (Hurlbert's expected number of distinct verbs in 10 items) uses checklists with >= 10 verb-bearing items.
9. **Concept mapping**: 351 distinct concept labels; 17 rows with an empty concept label were dropped; 70 duplicated item x concept pairs were collapsed to one. Each item's verb is assigned to every concept it maps to. Concept-level summaries use concepts requested by >= 2 items that have a directive verb (items without a verb cannot contribute a verb). 19 English items have no concept mapping (mainly APA_2018 abstract items) and are excluded from Analysis 2.
10. **Section for Analysis 2** = `standardised_section` of the concepts file (44 concepts occur in more than one section, e.g. 'Report any limitations ...' in Abstract and Discussion; by-section results treat each concept x section as a unit, pooled results treat the concept as a unit).
11. **Text artefacts in the data** (not modified in data/, handled in the script only): trailing extraction notes 'd-nb?' (harvranek_2020) and 'paste.txt?' (wong_2013a) removed before tagging; invalid UTF-8 bytes (curly quotes, dashes, non-breaking spaces) repaired; one item concatenates two items ('Use a structured formatDescribe explicitly ...', verb = use).
12. **udpipe version**: the analysis was run with udpipe 0.8.11 (conda-forge build for R 4.2.1) rather than 0.8.16, which could not be installed in the sandbox (CRAN is not reachable). The udpipe model file is identical (english-ewt-ud-2.5-191206), so annotations should not differ. tidytext 0.4.1 is installed but not needed by this script.

## 2. Edge cases

All flagged items are listed in `edge_cases.csv` (1051 rows). Counts by type:

| Edge case | n items |
|---|---|
| no directive verb | 518 |
| leading phrase skipped | 193 |
| non-English item | 135 |
| multiple coordinated verbs | 60 |
| text cleaned before tagging (numbering/bullet/quote or trailing extraction note removed) | 29 |
| invalid UTF-8 bytes repaired (Windows-1252 -> UTF-8) before tagging | 28 |
| spelling harmonised | 20 |
| English item with no concept mapping (excluded from Analysis 2) | 19 |
| label before colon skipped | 18 |
| verb found inside leading phrase without comma | 10 |
| adverb/particle between start and verb skipped | 9 |
| cross-reference item ('See ...') counted with verb 'see' | 5 |
| verb accepted by context rule (lexicon (ambiguous word) + context) | 3 |
| item ends with '?' but opens with a directive verb (kept) | 2 |
| verb accepted by context rule (udpipe VERB/VB + context) | 2 |

A random sample of 100 English items with the extracted verb is in `manual_check_sample_100.csv` (columns manual_verb / manual_agree / comment left empty for you).

## 3. Headline numbers

- English items: 2177; with a directive verb: 1659 (76.2%); distinct verbs: 56.
- Most frequent verbs: describe (466), provide (207), present (171), specify (130), report (122), state (98), indicate (59), list (58).
- Checklists with >= 1 verb-bearing item: 56 of 63. Distinct verbs per checklist: median 10 (IQR 6-12); Shannon H: 1.95 (IQR 1.42-2.15); Pielou J: 0.85 (IQR 0.80-0.90); proportion of items using the modal verb: 0.34 (IQR 0.26-0.45).
- Checklists with >= 2 distinct verbs: 94.6% (53 of 56); >= 3: 89.3% (50 of 56).
- Spearman rho (n items with verb vs n distinct verbs): 0.85, p = 5.05e-17.
- Rarefied distinct verbs per 10 items (checklists with >= 10 verb-bearing items, n = 46): median 5.96 (IQR 5.11-6.37).
- Concepts requested by >= 2 verb-bearing items: 188. Distinct verbs per concept: median 3 (IQR 2-5); >= 2 verbs: 81.4% (153 of 188); >= 3 verbs: 54.3% (102 of 188).

Top 10 concepts (by number of verb-bearing items):

| Concept | Section(s) | Items | Checklists | Distinct verbs | Verbs |
|---|---|---|---|---|---|
| Report the method used to assess the risk of bias | Abstract; Methodology | 74 | 38 | 10 | describe (30); specify (18); provide (13); state (4); report (3); indicate (2); conduct (1); identify (1); include (1); list (1) |
| Report an interpretation of the results | Abstract; Discussion | 70 | 35 | 13 | provide (26); summarize (23); compare (4); describe (3); present (3); state (3); include (2); discuss (1); draw (1); explain (1); explore (1); list (1); report (1) |
| Report the sources of support received for conducting the evidence synthesis | Abstract; Other information | 58 | 36 | 9 | describe (27); provide (16); indicate (5); specify (3); report (2); state (2); acknowledge (1); include (1); list (1) |
| Report the results of the study selection process | Results | 54 | 32 | 8 | provide (18); give (13); describe (11); cite (6); report (3); assess (1); identify (1); use (1) |
| Report the results of the risk of bias assessment | Results | 54 | 28 | 5 | present (41); provide (4); report (4); summarize (4); consider (1) |
| Report the eligibility criteria for the evidence synthesis | Abstract; Methodology | 50 | 29 | 9 | specify (19); provide (13); describe (5); report (4); include (3); state (3); define (1); indicate (1); list (1) |
| Report the implications of the evidence synthesis results | Abstract; Discussion | 50 | 30 | 9 | provide (21); summarize (10); discuss (8); describe (5); consider (2); indicate (1); make (1); present (1); state (1) |
| Report the methodology used to conduct the evidence synthesis | Abstract; Introduction; Title | 49 | 43 | 9 | identify (38); select (4); consider (1); describe (1); include (1); indicate (1); make (1); specify (1); use (1) |
| Report the scientific literature databases used to conduct the literature search | Abstract; Methodology | 48 | 41 | 12 | describe (19); specify (11); detail (4); present (3); state (3); list (2); document (1); give (1); include (1); name (1); provide (1); search (1) |
| Report a measure of statistical heterogeneity associated with the pooled effect size estimate | Abstract; Results | 47 | 20 | 7 | present (25); give (13); provide (3); describe (2); report (2); include (1); summarize (1) |

By section (concepts requested by >= 2 verb-bearing items):

| Section | Concepts | Items | Median distinct verbs (IQR) | % >= 2 verbs | % >= 3 verbs |
|---|---|---|---|---|---|
| Title | 7 | 75 | 4 (3-4) | 100.0 | 85.7 |
| Abstract | 35 | 286 | 2 (2-3) | 85.7 | 40.0 |
| Introduction | 13 | 173 | 3 (2-6) | 100.0 | 69.2 |
| Methodology | 104 | 1156 | 2 (1-4) | 73.1 | 43.3 |
| Results | 33 | 495 | 3 (2-5) | 84.8 | 69.7 |
| Discussion | 10 | 282 | 5.5 (4.25-7.75) | 90.0 | 80.0 |
| Other information | 17 | 234 | 3 (2-5) | 94.1 | 70.6 |
