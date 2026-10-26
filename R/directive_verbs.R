# =============================================================================
# Directive verbs in reporting items
# -----------------------------------------------------------------------------
# Reproducible analysis of the directive verbs ("Describe ...", "Report ...",
# "Specify ...") that open synthesis reporting items.
#
#   0. Set-up        : data files, columns, parameters
#   1. Extraction    : POS-tag + lemmatise every item with udpipe (english-ewt)
#                      and extract the initial directive verb (rule-based, with
#                      every rule and lexicon decision exported for checking)
#   2. Analysis 1    : verb diversity within checklists
#   3. Analysis 2    : verbs per concept (and by manuscript section)
#   4. Outputs       : output/directive_verbs/
#
# Run from the project root (paths use here()). Existing data files are read
# only; nothing under data/ is modified.
# Tested with R 4.2.1, udpipe 0.8.11, ggplot2 3.5.1, dplyr 1.1.4.
# =============================================================================

# -----------------------------------------------------------------------------
# 0. Packages, parameters, data
# -----------------------------------------------------------------------------
suppressPackageStartupMessages({
  library(tidyverse)
  library(here)
  library(udpipe)
  library(stringi)
  library(patchwork)
})

# Decisions that the user may want to change (see decisions_and_edge_cases.md)
MULTI_VERB_RULE    <- "first"   # "first": "Describe and justify" -> describe
                                # "exclude": drop multi-verb items from the verb analyses
HARMONISE_SPELLING <- TRUE      # British/American spelling variants only
                                # (summarise -> summarize); NO synonym merging
SEED               <- 2026      # for the 100-item manual-check sample
RAREFY_M           <- 10        # rarefaction sample size (items)

out_dir <- here("output", "directive_verbs")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# ---- Data ------------------------------------------------------------------
# item_bank_reporting_guideline_compiled.csv : one row per reporting item
#   reporting_item       verbatim item text
#   checklist_item_id    item ID (unique)
#   checklist            checklist ID (a guideline can have several checklists)
#   study_id             guideline ID
#   standardised_section manuscript section (as compiled)
#   language             english / portuguese / spanish
# item_bank_reporting_guideline_concepts.csv : one row per item x concept
#   standardised_reporting_item_elements  concept label
#   standardised_section                  manuscript section of the concept
# item_bank_reporting_guideline.csv : one row per guideline (metadata only)
items_raw <- read_csv(here("data", "item_bank_reporting_guideline_compiled.csv"),
                      show_col_types = FALSE)
concept_raw <- suppressMessages(
  read_csv(here("data", "item_bank_reporting_guideline_concepts.csv"),
           show_col_types = FALSE, name_repair = "unique")
) %>%
  select(-starts_with("..."))          # two unnamed, empty trailing columns
study <- read_csv(here("data", "item_bank_reporting_guideline.csv"),
                  show_col_types = FALSE)

# ---- Text cleaning ----------------------------------------------------------
# A few items contain bytes that are not valid UTF-8 (Windows-1252 characters
# such as curly quotes, en dashes and non-breaking spaces). They are repaired
# before tagging; analysis.qmd uses stri_enc_toutf8(validate = TRUE) for the
# same purpose.
fix_encoding <- function(x) {
  bad <- !is.na(x) & !stri_enc_isutf8(x)
  x[bad] <- stri_encode(x[bad], from = "windows-1252", to = "UTF-8")
  x <- stri_enc_toutf8(x, validate = TRUE)
  x <- str_replace_all(x, " ", " ")   # non-breaking space
  x
}

clean_text <- function(x) {
  x <- str_squish(x)
  # extraction notes that trail a few items in the data ("d-nb?", "paste.txt?")
  x <- str_remove(x, "\\s*(d-nb\\?|paste\\.txt\\?)\\s*$")
  # leading list numbering, bullets, quotes
  x <- str_remove(x, "^[\"'“”\\-–—•\\*]+\\s*")
  x <- str_remove(x, "^\\(?\\d{1,3}[a-z]?[.):]\\)?\\s+")
  x <- str_remove(x, "^\\(?[a-z][.)]\\s+")
  x <- str_remove(x, "^[Ii]tem\\s*\\d+[a-z]?[.:)]?\\s+")
  str_squish(x)
}

items <- items_raw %>%
  mutate(
    encoding_repaired = !is.na(reporting_item) & !stri_enc_isutf8(reporting_item),
    reporting_item_fixed = fix_encoding(reporting_item),
    text_clean = clean_text(reporting_item_fixed),
    text_changed = text_clean != str_squish(reporting_item_fixed)
  )

items_en <- items %>% filter(language == "english")

# -----------------------------------------------------------------------------
# 1. Extraction of directive verbs
# -----------------------------------------------------------------------------
# 1a. udpipe annotation (tokeniser, tagger, parser), english-ewt model that
#     ships with the repository
ud_model <- udpipe_load_model(here("R.data", "english-ewt-ud-2.5-191206.udpipe"))

anno <- udpipe_annotate(
  ud_model,
  x = items_en$text_clean,
  doc_id = items_en$checklist_item_id
) %>%
  as.data.frame() %>%
  as_tibble() %>%
  mutate(
    tl = str_to_lower(token),        # token, lower case
    ll = str_to_lower(lemma),        # lemma, lower case
    token_id = as.integer(token_id),
    head_token_id = suppressWarnings(as.integer(head_token_id))
  )

# 1b. Lexicon and rule parameters
# Sentence-initial imperatives are poorly tagged by udpipe (e.g. "Describe"
# is tagged AUX/ADJ, "Report" NOUN, "Present" ADJ), so tagging alone cannot
# identify the directive verb. The rule therefore combines:
#   * a curated lexicon of directive verbs, split into
#       - strong verbs: accepted whenever they open the item in base form
#         (guard: not followed by "of", e.g. "List of citations", "Use of ...")
#       - ambiguous verbs: words that also open noun phrases in this corpus
#         ("Search terms used", "Study population", "Reference standard");
#         accepted only when followed by a determiner, pronoun, number,
#         wh-word or similar ("Search at least two databases", "Use a title")
#   * udpipe's own tag: any other token tagged VERB/VB in base form is accepted
#     under the same contextual condition as ambiguous verbs.
# The full lexicon is written to verb_lexicon.csv for checking.
strong_verbs <- c(
  "describe", "provide", "present", "specify", "report", "state", "list",
  "discuss", "indicate", "identify", "give", "include", "summarize",
  "summarise", "cite", "explain", "declare", "consider", "inform", "justify",
  "document", "detail", "share", "select", "define", "disclose", "acknowledge",
  "mention", "articulate", "tabulate", "synthesize", "synthesise", "perform",
  "integrate", "reflect", "register", "preregister", "pre-register",
  "communicate", "compare", "contrast", "assess", "draw", "quote", "make",
  "break", "allow", "conduct", "see", "name", "outline", "address", "clarify",
  "highlight", "ensure", "avoid", "follow", "calculate", "evaluate",
  "interpret", "offer", "elaborate", "explore", "examine", "enumerate",
  "supply", "append", "attach", "note", "comment", "show", "display",
  "illustrate", "record", "refer", "check", "account", "use", "add", "apply",
  "choose", "determine", "distinguish", "explicate", "justify", "map",
  "narrate", "pool", "quantify", "rate", "rank", "relate", "restate",
  "stratify", "tabulate", "write", "visualize", "visualise", "verify"
)
ambiguous_verbs <- c(
  "search", "study", "reference", "time", "effect", "research", "data",
  "group", "target", "summary", "question", "date", "total", "year", "level",
  "purpose", "process", "sample", "table", "test", "mass", "type", "number",
  "title", "review", "form", "model", "plan", "design", "measure", "estimate",
  "label", "link", "control", "focus", "support", "point", "access",
  "abstract", "result", "method", "change", "order", "contact", "code",
  "score", "value", "structure", "detail", "flow", "risk", "source", "weight",
  "signal", "frame", "scale", "range", "limit", "match", "balance", "cross"
)
strong_verbs <- unique(strong_verbs)
ambiguous_verbs <- setdiff(unique(ambiguous_verbs), strong_verbs)

# words that open a conditional / scoping phrase before the directive
# ("If applicable, ...", "For each study, ...", "In the abstract, ...")
preamble_starters <- c(
  "if", "when", "whenever", "where", "wherever", "while", "for", "in", "as",
  "at", "on", "with", "after", "before", "during", "based", "according",
  "depending", "regardless", "except", "once", "to", "by", "from", "under",
  "within", "throughout", "although", "though", "unless", "following",
  "e.g.", "i.e.", "ideally", "only", "also", "additionally", "alternatively",
  "otherwise", "optionally", "particularly", "especially", "please"
)
# adverbs / particles skipped between the start and the verb
# ("Please describe", "Clearly describe", "Briefly summarise", "Break down and")
skip_words <- c(
  "please", "also", "clearly", "briefly", "explicitly", "fully", "always",
  "ideally", "then", "specifically", "carefully", "adequately",
  "appropriately", "concisely", "succinctly", "transparently", "down"
)
question_words <- c(
  "how", "what", "which", "why", "who", "whom", "whether", "were", "was",
  "did", "do", "does", "is", "are", "has", "have", "can", "could", "will",
  "would"
)
# tokens that may follow an ambiguous verb for it to be read as imperative
strict_next_words <- c(
  "whether", "if", "how", "which", "what", "where", "when", "why", "who",
  "that", "at", "about", "each", "all", "any", "both", "every", "such", ":"
)
modal_regex <- "\\b(should|must|may|might|ought|need(s)? to|has to|have to|is to|are to)\\b"

# 1c. Helper functions -------------------------------------------------------
# udpipe sometimes tags sentence-initial imperatives ("Describe", "Explain")
# and phrase openers ("Where", "When") as ADV, so only plain adverbs (xpos RB)
# that are neither lexicon verbs nor phrase openers are skipped
protected_words <- c(strong_verbs, ambiguous_verbs, preamble_starters, question_words)
skip_adverbs <- function(tk, i) {
  n <- nrow(tk)
  while (i <= n && !tk$tl[i] %in% protected_words &&
         (tk$tl[i] %in% skip_words || (tk$upos[i] == "ADV" && tk$xpos[i] == "RB")))
    i <- i + 1
  i
}

in_lexicon <- function(tk, i) {
  tk$tl[i] %in% c(strong_verbs, ambiguous_verbs) ||
    tk$ll[i] %in% c(strong_verbs, ambiguous_verbs)
}

# base form: the token is itself a lexicon entry (all entries are base forms),
# equals its lemma, or is tagged VB/VBP (udpipe lemmas are occasionally odd,
# e.g. "Explain" -> "aexplain")
is_base_form <- function(tk, i) {
  tk$tl[i] %in% c(strong_verbs, ambiguous_verbs) ||
    tk$tl[i] == tk$ll[i] || tk$xpos[i] %in% c("VB", "VBP")
}

# verbs accepted on udpipe's tag alone must look like ordinary words
# (no acronyms such as "TCM", which udpipe tagged VERB/VB once)
plausible_token <- function(tk, i) {
  str_detect(tk$token[i], "^[A-Z]?[a-z][a-z-]{2,}$")
}

is_verb_word <- function(tk, i) {
  i <= nrow(tk) && is_base_form(tk, i) &&
    (in_lexicon(tk, i) || (tk$upos[i] == "VERB" && tk$xpos[i] == "VB"))
}

# can token j start a coordination with another verb ("and define all ...")?
coord_ok <- function(tk, j) {
  n <- nrow(tk)
  if (j > n || !tk$tl[j] %in% c("and", "or", "/")) return(FALSE)
  k <- skip_adverbs(tk, j + 1)
  if (k > n || !is_verb_word(tk, k)) return(FALSE)
  m <- skip_adverbs(tk, k + 1)
  m <= n && (tk$upos[m] %in% c("DET", "PRON", "NUM") || tk$tl[m] %in% strict_next_words)
}

# test whether token i is the directive verb
#   strict = TRUE requires the contextual condition even for strong verbs
#   (used when scanning inside a leading phrase, e.g. "For each study report ...")
test_candidate <- function(tk, i, strict = FALSE) {
  n <- nrow(tk)
  if (i > n) return(NULL)
  w <- tk$tl[i]; lem <- tk$ll[i]
  if (!is_base_form(tk, i)) return(NULL)
  j <- skip_adverbs(tk, i + 1)
  nxt <- if (j <= n) tk$tl[j] else ""
  nxt_upos <- if (j <= n) tk$upos[j] else ""
  if (nxt == "of") return(NULL)
  strict_ok <- nxt_upos %in% c("DET", "PRON", "NUM") ||
    nxt %in% strict_next_words || coord_ok(tk, j)
  # inside a leading phrase a strong verb must be followed by an object-like
  # token ("report summary estimates", "provide citations"), not by a finite
  # verb ("Whether each report was coded ...")
  object_ok <- strict_ok || nxt_upos %in% c("NOUN", "PROPN", "ADJ", "ADV")
  strong <- w %in% strong_verbs || lem %in% strong_verbs
  ambig  <- w %in% ambiguous_verbs || lem %in% ambiguous_verbs
  if (strong && (!strict || object_ok))
    return(list(i = i, source = "lexicon (strong verb)"))
  if (ambig && strict_ok)
    return(list(i = i, source = "lexicon (ambiguous word) + context"))
  if (!strong && !ambig && tk$upos[i] == "VERB" && tk$xpos[i] == "VB" &&
      strict_ok && plausible_token(tk, i))
    return(list(i = i, source = "udpipe VERB/VB + context"))
  NULL
}

# first delimiter (",", ":", ";") after position p0 that is not inside
# parentheses, within `window` tokens
first_delimiter <- function(tk, p0, window = 30) {
  n <- nrow(tk)
  depth <- 0
  for (q in seq(p0 + 1, min(n, p0 + window))) {
    if (q > n) break
    if (tk$tl[q] %in% c("(", "[")) depth <- depth + 1
    if (tk$tl[q] %in% c(")", "]")) depth <- max(0, depth - 1)
    if (depth == 0 && tk$tl[q] %in% c(",", ":", ";")) return(q)
  }
  NA_integer_
}

# verbs directly coordinated with the directive verb ("Describe and justify")
# returns the token indices of the coordinated verbs
collect_coordinated <- function(tk, i) {
  n <- nrow(tk)
  idx <- integer(0)
  j <- skip_adverbs(tk, i + 1)
  while (j <= n && tk$tl[j] %in% c("and", "or", "/", ",")) {
    k <- skip_adverbs(tk, j + 1)
    if (k <= n && is_verb_word(tk, k) && tk$tl[k] != "of") {
      idx <- c(idx, k)
      j <- skip_adverbs(tk, k + 1)
    } else break
  }
  idx
}

empty_result <- tibble(
  verb_token = NA_character_, verb_lemma = NA_character_,
  verb_source = NA_character_, verb_position = NA_integer_,
  coordinated_verbs = NA_character_, leading_text_skipped = NA_character_,
  extraction_flags = NA_character_, first_token_after_skip = NA_character_
)

extract_one <- function(tk) {
  n <- nrow(tk)
  if (n == 0) return(empty_result)
  flags <- character(0)
  skipped <- character(0)
  pos <- 1
  # residual numbering / punctuation tokens at the very start
  while (pos <= n && (tk$upos[pos] == "PUNCT" ||
                      str_detect(tk$tl[pos], "^\\(?\\d{1,3}[a-z]?[.):]?\\)?$")))
    pos <- pos + 1
  if (pos > n) return(empty_result)
  cand <- NULL
  for (iter in 1:4) {
    p0 <- skip_adverbs(tk, pos)
    if (p0 > n) break
    if (p0 > pos) flags <- c(flags, "adverb/particle before verb skipped")
    cand <- test_candidate(tk, p0)
    if (!is.null(cand)) { pos <- p0; break }
    w <- tk$tl[p0]
    # (i) conditional / scoping phrase before the directive
    if ((w %in% preamble_starters || tk$upos[p0] %in% c("SCONJ", "ADP")) &&
        !w %in% question_words) {
      d <- first_delimiter(tk, p0)
      hi <- min(n, p0 + 30, if (is.na(d)) n else d - 1)
      # a verb inside the phrase itself ("For each study report ...",
      # "In the title include: ..."): must not directly follow the phrase
      # opener ("for report appearance") nor "to"/"of"/"and"/"or"
      hit <- NULL
      if (hi > p0 + 1) {
        for (q in seq(p0 + 2, hi)) {
          c2 <- test_candidate(tk, q, strict = TRUE)
          if (!is.null(c2) && !tk$tl[q - 1] %in% c("to", "of", "and", "or")) { hit <- c2; break }
        }
      }
      if (!is.null(hit)) {
        skipped <- c(skipped, paste(tk$token[pos:(hit$i - 1)], collapse = " "))
        flags <- c(flags, "verb inside leading phrase (no comma)")
        cand <- hit; pos <- hit$i
        break
      }
      if (is.na(d)) break
      skipped <- c(skipped, paste(tk$token[pos:d], collapse = " "))
      flags <- c(flags, "leading phrase skipped")
      pos <- d + 1
      next
    }
    # (ii) label before a colon ("Background: state ...", "Timing: describe ...")
    cpos <- which(tk$tl == ":" & seq_len(n) > p0 & seq_len(n) <= p0 + 4)
    if (length(cpos)) {
      skipped <- c(skipped, paste(tk$token[pos:cpos[1]], collapse = " "))
      flags <- c(flags, "label before colon skipped")
      pos <- cpos[1] + 1
      next
    }
    break
  }
  first_tok <- if (pos <= n) tk$tl[min(n, skip_adverbs(tk, pos))] else NA_character_
  if (is.null(cand)) {
    return(empty_result %>%
             mutate(leading_text_skipped = if (length(skipped)) paste(skipped, collapse = " | ") else NA_character_,
                    extraction_flags = if (length(flags)) paste(unique(flags), collapse = "; ") else NA_character_,
                    first_token_after_skip = first_tok))
  }
  i <- cand$i
  # the lexicon holds base forms, so a lexicon token is its own lemma
  # (udpipe lemmas are occasionally wrong, e.g. "Explain" -> "aexplain")
  lemma_of <- function(k) if (tk$tl[k] %in% c(strong_verbs, ambiguous_verbs)) tk$tl[k] else tk$ll[k]
  coord <- vapply(collect_coordinated(tk, i), lemma_of, character(1))
  if (length(coord)) flags <- c(flags, "multiple coordinated verbs")
  if (lemma_of(i) == "see") flags <- c(flags, "cross-reference item (See ...)")
  tibble(
    verb_token = tk$token[i], verb_lemma = lemma_of(i), verb_source = cand$source,
    verb_position = i,
    coordinated_verbs = if (length(coord)) paste(c(lemma_of(i), coord), collapse = "; ") else NA_character_,
    leading_text_skipped = if (length(skipped)) paste(skipped, collapse = " | ") else NA_character_,
    extraction_flags = if (length(flags)) paste(unique(flags), collapse = "; ") else NA_character_,
    first_token_after_skip = first_tok
  )
}

# 1d. Run the extraction ------------------------------------------------------
extracted <- anno %>%
  arrange(doc_id, paragraph_id, sentence_id, token_id) %>%
  group_by(doc_id) %>%
  group_modify(~ extract_one(.x)) %>%
  ungroup() %>%
  rename(checklist_item_id = doc_id)

# syntactic information used to label items without a directive verb
sentence_info <- anno %>%
  filter(sentence_id == 1) %>%
  group_by(doc_id) %>%
  summarise(
    first_sentence = first(sentence),
    root_id = token_id[dep_rel == "root"][1],
    root_upos = upos[dep_rel == "root"][1],
    root_has_subject = any(str_detect(dep_rel, "^nsubj") & head_token_id == root_id),
    .groups = "drop"
  ) %>%
  rename(checklist_item_id = doc_id)

spelling_map <- c(
  summarise = "summarize", synthesise = "synthesize", analyse = "analyze",
  characterise = "characterize", emphasise = "emphasize", visualise = "visualize",
  categorise = "categorize", prioritise = "prioritize", organise = "organize",
  "pre-register" = "preregister", recognise = "recognize", itemise = "itemize"
)
harmonise <- function(v) {
  if (!HARMONISE_SPELLING) return(v)
  ifelse(v %in% names(spelling_map), unname(spelling_map[v]), v)
}

item_verbs <- items %>%
  left_join(extracted, by = "checklist_item_id") %>%
  left_join(sentence_info, by = "checklist_item_id") %>%
  mutate(
    verb_raw = verb_lemma,
    verb = harmonise(verb_lemma),
    multi_verb = !is.na(coordinated_verbs),
    coordinated_verbs = if (HARMONISE_SPELLING) {
      map_chr(str_split(coordinated_verbs, ";\\s*"), ~ if (all(is.na(.x))) NA_character_ else paste(harmonise(.x), collapse = "; "))
    } else coordinated_verbs,
    no_verb_reason = case_when(
      !is.na(verb) ~ NA_character_,
      language != "english" ~ "non-English item (not tagged with english-ewt)",
      str_detect(str_to_lower(text_clean), "^(not applicable|n/?a\\b)") ~ "placeholder (not applicable)",
      first_token_after_skip %in% question_words ~ "question or indirect question (How ..., Whether ..., Were ...)",
      str_detect(str_to_lower(first_sentence), modal_regex) | root_has_subject %in% TRUE ~
        "declarative or modal statement (subject + finite verb, e.g. 'The title must ...', 'Authors should ...')",
      TRUE ~ "noun phrase or fragment (no initial verb)"
    )
  )

if (MULTI_VERB_RULE == "exclude") {
  item_verbs <- item_verbs %>%
    mutate(no_verb_reason = if_else(multi_verb %in% TRUE, "multi-verb item excluded (MULTI_VERB_RULE)", no_verb_reason),
           verb = if_else(multi_verb %in% TRUE, NA_character_, verb))
}

item_level <- item_verbs %>%
  select(
    checklist_item_id, study_id, checklist, reporting_item_number, language,
    section, standardised_section, reporting_item, text_clean, verb, verb_raw,
    verb_token, verb_source, verb_position, multi_verb, coordinated_verbs,
    leading_text_skipped, extraction_flags, no_verb_reason,
    encoding_repaired, text_changed
  )

write_csv(item_level, file.path(out_dir, "item_level_verbs.csv"), na = "")

# 1e. Manual-check sample ------------------------------------------------------
set.seed(SEED)
manual_sample <- item_level %>%
  filter(language == "english") %>%
  slice_sample(n = 100) %>%
  arrange(checklist_item_id) %>%
  select(checklist_item_id, checklist, reporting_item, verb, coordinated_verbs,
         leading_text_skipped, extraction_flags, no_verb_reason) %>%
  mutate(manual_verb = "", manual_agree = "", comment = "")
write_csv(manual_sample, file.path(out_dir, "manual_check_sample_100.csv"), na = "")

# 1f. Lexicon export -----------------------------------------------------------
first_token_stats <- item_verbs %>%
  filter(language == "english") %>%
  mutate(w = str_to_lower(word(text_clean, 1)) %>% str_remove("[[:punct:]]+$")) %>%
  count(w, name = "n_items_opening_with_word")
verb_lexicon <- bind_rows(
  tibble(word = strong_verbs, class = "strong directive verb (accepted when initial and in base form; not followed by 'of')"),
  tibble(word = ambiguous_verbs, class = "ambiguous noun/verb (accepted only before a determiner, pronoun, number or wh-word)")
) %>%
  left_join(first_token_stats, by = c("word" = "w")) %>%
  left_join(item_verbs %>% filter(!is.na(verb)) %>% count(verb_raw, name = "n_items_extracted_as_verb"),
            by = c("word" = "verb_raw")) %>%
  mutate(across(starts_with("n_"), ~ replace_na(.x, 0L))) %>%
  arrange(class, desc(n_items_opening_with_word), word)
write_csv(verb_lexicon, file.path(out_dir, "verb_lexicon.csv"))

# 1g. Overall verb frequency ----------------------------------------------------
verbs_en <- item_verbs %>% filter(language == "english")
n_en <- nrow(verbs_en)
n_en_verb <- sum(!is.na(verbs_en$verb))
verb_frequency <- verbs_en %>%
  filter(!is.na(verb)) %>%
  group_by(verb) %>%
  summarise(n_items = n(), n_checklists = n_distinct(checklist),
            n_guidelines = n_distinct(study_id), .groups = "drop") %>%
  mutate(pct_of_items_with_verb = round(100 * n_items / n_en_verb, 1),
         pct_of_all_english_items = round(100 * n_items / n_en, 1)) %>%
  arrange(desc(n_items), verb)
write_csv(verb_frequency, file.path(out_dir, "verb_frequency.csv"))

# -----------------------------------------------------------------------------
# 2. Analysis 1 - verb diversity within checklists
# -----------------------------------------------------------------------------
shannon <- function(counts) { p <- counts / sum(counts); -sum(p * log(p)) }
pielou  <- function(counts) { S <- length(counts); if (S < 2) NA_real_ else shannon(counts) / log(S) }
# Hurlbert rarefaction: expected number of distinct verbs in a random
# subsample of m items
rarefy_s <- function(counts, m = RAREFY_M) {
  N <- sum(counts)
  if (N < m) return(NA_real_)
  sum(1 - exp(lchoose(N - counts, m) - lchoose(N, m)))
}
verb_string <- function(v) {
  tb <- sort(table(v), decreasing = TRUE)
  paste0(names(tb), " (", as.integer(tb), ")", collapse = "; ")
}

checklist_level <- verbs_en %>%
  group_by(study_id, checklist) %>%
  summarise(
    n_items = n(),
    n_items_with_verb = sum(!is.na(verb)),
    prop_items_with_verb = n_items_with_verb / n_items,
    n_distinct_verbs = n_distinct(verb[!is.na(verb)]),
    shannon_H = if (n_items_with_verb > 0) shannon(as.integer(table(verb))) else NA_real_,
    pielou_J = if (n_items_with_verb > 0) pielou(as.integer(table(verb))) else NA_real_,
    modal_verb = if (n_items_with_verb > 0) names(sort(table(verb), decreasing = TRUE))[1] else NA_character_,
    n_modal_verb = if (n_items_with_verb > 0) max(table(verb)) else NA_integer_,
    prop_modal_verb = n_modal_verb / n_items_with_verb,
    rarefied_distinct_verbs_10 = if (n_items_with_verb > 0) rarefy_s(as.integer(table(verb))) else NA_real_,
    verbs = if (n_items_with_verb > 0) verb_string(verb[!is.na(verb)]) else NA_character_,
    .groups = "drop"
  ) %>%
  arrange(desc(n_distinct_verbs), desc(n_items_with_verb))
write_csv(checklist_level, file.path(out_dir, "checklist_level_metrics.csv"), na = "")

med_iqr <- function(x) {
  x <- x[!is.na(x)]
  q <- quantile(x, c(0.25, 0.5, 0.75), names = FALSE)
  list(n = length(x), median = q[2], q1 = q[1], q3 = q[3])
}
summ_row <- function(analysis, subset, metric, x, note = NA_character_) {
  m <- med_iqr(x)
  tibble(analysis = analysis, subset = subset, metric = metric, n = m$n,
         value = m$median, q1 = m$q1, q3 = m$q3, note = note)
}
pct_row <- function(analysis, subset, metric, lgl, note = NA_character_) {
  lgl <- lgl[!is.na(lgl)]
  tibble(analysis = analysis, subset = subset, metric = metric, n = length(lgl),
         value = 100 * mean(lgl), q1 = NA_real_, q3 = NA_real_,
         note = paste0(sum(lgl), " of ", length(lgl), if (!is.na(note)) paste0("; ", note) else ""))
}
val_row <- function(analysis, subset, metric, value, n = NA_integer_, note = NA_character_) {
  tibble(analysis = analysis, subset = subset, metric = metric, n = n,
         value = value, q1 = NA_real_, q3 = NA_real_, note = note)
}

cl_any <- checklist_level %>% filter(n_items_with_verb >= 1)
cl_5   <- checklist_level %>% filter(n_items_with_verb >= 5)
cl_10  <- checklist_level %>% filter(n_items_with_verb >= 10)
cor_sp <- suppressWarnings(cor.test(cl_any$n_items_with_verb, cl_any$n_distinct_verbs, method = "spearman"))
cor_sp_all <- suppressWarnings(cor.test(cl_any$n_items, cl_any$n_distinct_verbs, method = "spearman"))
cor_pe <- cor.test(cl_any$n_items_with_verb, cl_any$n_distinct_verbs, method = "pearson")

a1_subset <- "checklists with >= 1 item with a directive verb"
summary_a1 <- bind_rows(
  val_row("extraction", "all items", "n items (all languages)", nrow(items)),
  val_row("extraction", "English items", "n items", n_en),
  val_row("extraction", "English items", "n items with a directive verb", n_en_verb),
  val_row("extraction", "English items", "% items with a directive verb", 100 * n_en_verb / n_en),
  val_row("extraction", "English items", "n items with coordinated verbs (e.g. 'Describe and justify')", sum(verbs_en$multi_verb, na.rm = TRUE)),
  val_row("extraction", "English items", "n distinct directive verbs overall", nrow(verb_frequency)),
  val_row("analysis 1", "all English-language checklists", "n checklists", nrow(checklist_level)),
  val_row("analysis 1", a1_subset, "n checklists", nrow(cl_any)),
  val_row("analysis 1", "checklists with >= 5 items with a directive verb", "n checklists", nrow(cl_5)),
  summ_row("analysis 1", a1_subset, "n items per checklist (median, IQR)", cl_any$n_items),
  summ_row("analysis 1", a1_subset, "n items with a directive verb per checklist (median, IQR)", cl_any$n_items_with_verb),
  summ_row("analysis 1", a1_subset, "proportion of items with a directive verb (median, IQR)", cl_any$prop_items_with_verb),
  summ_row("analysis 1", a1_subset, "n distinct verbs per checklist (median, IQR)", cl_any$n_distinct_verbs),
  summ_row("analysis 1", a1_subset, "Shannon diversity H (median, IQR)", cl_any$shannon_H),
  summ_row("analysis 1", a1_subset, "Pielou evenness J = H/ln(S) (median, IQR)", cl_any$pielou_J, "undefined (NA) when S = 1"),
  summ_row("analysis 1", a1_subset, "proportion of items using the modal verb (median, IQR)", cl_any$prop_modal_verb),
  pct_row("analysis 1", a1_subset, "% checklists with >= 2 distinct verbs", cl_any$n_distinct_verbs >= 2),
  pct_row("analysis 1", a1_subset, "% checklists with >= 3 distinct verbs", cl_any$n_distinct_verbs >= 3),
  summ_row("analysis 1", "checklists with >= 5 items with a directive verb", "n distinct verbs per checklist (median, IQR)", cl_5$n_distinct_verbs),
  summ_row("analysis 1", "checklists with >= 5 items with a directive verb", "proportion of items using the modal verb (median, IQR)", cl_5$prop_modal_verb),
  pct_row("analysis 1", "checklists with >= 5 items with a directive verb", "% checklists with >= 2 distinct verbs", cl_5$n_distinct_verbs >= 2),
  pct_row("analysis 1", "checklists with >= 5 items with a directive verb", "% checklists with >= 3 distinct verbs", cl_5$n_distinct_verbs >= 3),
  val_row("analysis 1", a1_subset, "Spearman rho: n items with verb vs n distinct verbs", unname(cor_sp$estimate), nrow(cl_any), paste0("p = ", signif(cor_sp$p.value, 3))),
  val_row("analysis 1", a1_subset, "Spearman rho: n items (all) vs n distinct verbs", unname(cor_sp_all$estimate), nrow(cl_any), paste0("p = ", signif(cor_sp_all$p.value, 3))),
  val_row("analysis 1", a1_subset, "Pearson r: n items with verb vs n distinct verbs", unname(cor_pe$estimate), nrow(cl_any), paste0("p = ", signif(cor_pe$p.value, 3))),
  val_row("analysis 1", "checklists with >= 10 items with a directive verb", "n checklists", nrow(cl_10)),
  summ_row("analysis 1", "checklists with >= 10 items with a directive verb", "rarefied expected distinct verbs per 10 items (median, IQR)", cl_10$rarefied_distinct_verbs_10),
  summ_row("analysis 1", "checklists with >= 10 items with a directive verb", "observed distinct verbs (median, IQR)", cl_10$n_distinct_verbs)
)

# -----------------------------------------------------------------------------
# 3. Analysis 2 - verbs per concept
# -----------------------------------------------------------------------------
# one row per item x concept (duplicates and empty concepts removed)
concept_pairs <- concept_raw %>%
  filter(!is.na(standardised_reporting_item_elements)) %>%
  distinct(checklist_item_id, concept = standardised_reporting_item_elements,
           concept_section = standardised_section)
n_dup_pairs <- concept_raw %>%
  filter(!is.na(standardised_reporting_item_elements)) %>%
  count(checklist_item_id, standardised_reporting_item_elements) %>%
  filter(n > 1) %>% nrow()

concept_items <- concept_pairs %>%
  inner_join(verbs_en %>% select(checklist_item_id, study_id, checklist, verb, multi_verb),
             by = "checklist_item_id")

summarise_concepts <- function(d, ...) {
  d %>%
    group_by(...) %>%
    summarise(
      n_items_mapped = n(),
      n_items_with_verb = sum(!is.na(verb)),
      n_checklists = n_distinct(checklist[!is.na(verb)]),
      n_guidelines = n_distinct(study_id[!is.na(verb)]),
      n_distinct_verbs = n_distinct(verb[!is.na(verb)]),
      verbs = if (n_items_with_verb > 0) verb_string(verb[!is.na(verb)]) else NA_character_,
      .groups = "drop"
    )
}

concept_level <- concept_items %>%
  group_by(concept) %>%
  mutate(sections = paste(sort(unique(concept_section)), collapse = "; ")) %>%
  ungroup() %>%
  summarise_concepts(concept, sections) %>%
  mutate(included_in_summary = n_items_with_verb >= 2) %>%
  arrange(desc(n_items_with_verb), desc(n_distinct_verbs))
write_csv(concept_level, file.path(out_dir, "concept_level_metrics.csv"), na = "")

concept_section_level <- concept_items %>%
  summarise_concepts(concept_section, concept) %>%
  mutate(included_in_summary = n_items_with_verb >= 2) %>%
  arrange(concept_section, desc(n_items_with_verb))
write_csv(concept_section_level, file.path(out_dir, "concept_by_section_level_metrics.csv"), na = "")

cp <- concept_level %>% filter(included_in_summary)
top10 <- cp %>% arrange(desc(n_items_with_verb), desc(n_distinct_verbs)) %>% slice_head(n = 10) %>%
  select(concept, sections, n_items_with_verb, n_checklists, n_distinct_verbs, verbs)
write_csv(top10, file.path(out_dir, "top10_concepts_verbs.csv"))

a2_subset <- "concepts requested by >= 2 items with a directive verb"
summary_a2 <- bind_rows(
  val_row("analysis 2", "all concepts", "n concepts (non-missing labels)", n_distinct(concept_pairs$concept)),
  val_row("analysis 2", "all concepts", "n item x concept pairs (English items)", nrow(concept_items)),
  val_row("analysis 2", "all concepts", "n item x concept pairs with a directive verb", sum(!is.na(concept_items$verb))),
  val_row("analysis 2", a2_subset, "n concepts", nrow(cp)),
  summ_row("analysis 2", a2_subset, "n items per concept (median, IQR)", cp$n_items_with_verb),
  summ_row("analysis 2", a2_subset, "n checklists per concept (median, IQR)", cp$n_checklists),
  summ_row("analysis 2", a2_subset, "n distinct verbs per concept (median, IQR)", cp$n_distinct_verbs),
  pct_row("analysis 2", a2_subset, "% concepts requested with >= 2 distinct verbs", cp$n_distinct_verbs >= 2),
  pct_row("analysis 2", a2_subset, "% concepts requested with >= 3 distinct verbs", cp$n_distinct_verbs >= 3),
  summ_row("analysis 2", "concepts requested by >= 5 items with a directive verb", "n distinct verbs per concept (median, IQR)", cp$n_distinct_verbs[cp$n_items_with_verb >= 5]),
  pct_row("analysis 2", "concepts requested by >= 5 items with a directive verb", "% concepts requested with >= 2 distinct verbs", cp$n_distinct_verbs[cp$n_items_with_verb >= 5] >= 2),
  pct_row("analysis 2", "concepts requested by >= 5 items with a directive verb", "% concepts requested with >= 3 distinct verbs", cp$n_distinct_verbs[cp$n_items_with_verb >= 5] >= 3)
)

section_summary <- concept_section_level %>%
  filter(included_in_summary) %>%
  group_by(section = concept_section) %>%
  summarise(
    n_concepts = n(),
    n_items_with_verb = sum(n_items_with_verb),
    median_distinct_verbs = median(n_distinct_verbs),
    q1_distinct_verbs = quantile(n_distinct_verbs, 0.25),
    q3_distinct_verbs = quantile(n_distinct_verbs, 0.75),
    pct_concepts_2plus_verbs = 100 * mean(n_distinct_verbs >= 2),
    pct_concepts_3plus_verbs = 100 * mean(n_distinct_verbs >= 3),
    .groups = "drop"
  ) %>%
  arrange(factor(section, levels = c("Title", "Abstract", "Introduction", "Methodology", "Results", "Discussion", "Other information")))
write_csv(section_summary, file.path(out_dir, "concept_by_section_summary.csv"))

summary_a2_section <- section_summary %>%
  transmute(analysis = "analysis 2 by section",
            subset = paste0(section, ": concepts requested by >= 2 items with a directive verb"),
            metric = "n distinct verbs per concept (median, IQR); % with >= 2 verbs in note",
            n = n_concepts, value = median_distinct_verbs, q1 = q1_distinct_verbs, q3 = q3_distinct_verbs,
            note = paste0(round(pct_concepts_2plus_verbs, 1), "% with >= 2 verbs; ",
                          round(pct_concepts_3plus_verbs, 1), "% with >= 3 verbs"))

summary_statistics <- bind_rows(summary_a1, summary_a2, summary_a2_section) %>%
  mutate(across(c(value, q1, q3), ~ round(.x, 3)))
write_csv(summary_statistics, file.path(out_dir, "summary_statistics.csv"), na = "")

# -----------------------------------------------------------------------------
# 4. Figure: distinct verbs per checklist (a) and per concept (b)
# -----------------------------------------------------------------------------
col_point <- "#54478c"   # as in analysis.qmd
fig_theme <- theme_minimal(base_size = 13) +
  theme(
    panel.grid = element_blank(),
    panel.grid.major.y = element_line(color = "grey90", linewidth = 0.35),
    axis.title = element_text(color = "black"),
    axis.text = element_text(color = "black"),
    axis.line = element_line(linewidth = 0.7, color = "black"),
    axis.ticks = element_line(color = "black"),
    plot.title = element_text(size = 12.5, face = "bold", color = "black", hjust = 0),
    plot.title.position = "plot"
  )

p_a <- cl_any %>%
  count(n_distinct_verbs) %>%
  ggplot(aes(x = n_distinct_verbs, y = n)) +
  geom_col(fill = col_point, width = 0.8) +
  geom_text(aes(label = n), vjust = -0.4, size = 3.4, colour = "black") +
  scale_x_continuous(breaks = seq(0, max(cl_any$n_distinct_verbs), 2)) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.12))) +
  labs(title = paste0("a) Distinct directive verbs per checklist (n = ", nrow(cl_any), ")"),
       x = "Number of distinct directive verbs", y = "Number of checklists") +
  fig_theme

p_b <- cp %>%
  count(n_distinct_verbs) %>%
  ggplot(aes(x = n_distinct_verbs, y = n)) +
  geom_col(fill = col_point, width = 0.8) +
  geom_text(aes(label = n), vjust = -0.4, size = 3.4, colour = "black") +
  scale_x_continuous(breaks = seq(0, max(cp$n_distinct_verbs), 1)) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.12))) +
  labs(title = paste0("b) Distinct directive verbs per concept (n = ", nrow(cp), ")"),
       x = "Number of distinct directive verbs", y = "Number of concepts") +
  fig_theme

fig <- p_a + p_b
ggsave(file.path(out_dir, "figure_distinct_verbs.png"), fig,
       width = 24, height = 11, units = "cm", dpi = 300, bg = "white")
ggsave(file.path(out_dir, "figure_distinct_verbs.pdf"), fig,
       width = 24, height = 11, units = "cm", bg = "white")

# -----------------------------------------------------------------------------
# 5. Edge cases and decisions for checking
# -----------------------------------------------------------------------------
edge_cases <- bind_rows(
  item_level %>% filter(language != "english") %>%
    transmute(checklist_item_id, checklist, edge_case = "non-English item: excluded from verb extraction", reporting_item, verb),
  item_level %>% filter(encoding_repaired, language == "english") %>%
    transmute(checklist_item_id, checklist, edge_case = "invalid UTF-8 bytes repaired (Windows-1252 -> UTF-8) before tagging", reporting_item, verb),
  item_level %>% filter(text_changed, language == "english") %>%
    transmute(checklist_item_id, checklist, edge_case = "text cleaned before tagging (numbering/bullet/quote or trailing extraction note removed)", reporting_item, verb),
  item_level %>% filter(str_detect(extraction_flags, "leading phrase skipped") %in% TRUE) %>%
    transmute(checklist_item_id, checklist, edge_case = paste0("leading phrase skipped: '", leading_text_skipped, "'"), reporting_item, verb),
  item_level %>% filter(str_detect(extraction_flags, "no comma") %in% TRUE) %>%
    transmute(checklist_item_id, checklist, edge_case = paste0("verb found inside leading phrase without comma: '", leading_text_skipped, "'"), reporting_item, verb),
  item_level %>% filter(str_detect(extraction_flags, "label before colon") %in% TRUE) %>%
    transmute(checklist_item_id, checklist, edge_case = paste0("label before colon skipped: '", leading_text_skipped, "'"), reporting_item, verb),
  item_level %>% filter(str_detect(extraction_flags, "adverb") %in% TRUE) %>%
    transmute(checklist_item_id, checklist, edge_case = "adverb/particle between start and verb skipped", reporting_item, verb),
  item_level %>% filter(multi_verb %in% TRUE) %>%
    transmute(checklist_item_id, checklist, edge_case = paste0("multiple coordinated verbs: ", coordinated_verbs, " (rule: ", MULTI_VERB_RULE, ")"), reporting_item, verb),
  item_level %>% filter(str_detect(extraction_flags, "cross-reference") %in% TRUE) %>%
    transmute(checklist_item_id, checklist, edge_case = "cross-reference item ('See ...') counted with verb 'see'", reporting_item, verb),
  item_level %>% filter(verb_source %in% c("lexicon (ambiguous word) + context", "udpipe VERB/VB + context")) %>%
    transmute(checklist_item_id, checklist, edge_case = paste0("verb accepted by context rule (", verb_source, ")"), reporting_item, verb),
  item_level %>% filter(language == "english", is.na(verb)) %>%
    transmute(checklist_item_id, checklist, edge_case = paste0("no directive verb: ", no_verb_reason), reporting_item, verb),
  item_level %>% filter(language == "english", !is.na(verb_raw), verb_raw != verb) %>%
    transmute(checklist_item_id, checklist, edge_case = paste0("spelling harmonised: ", verb_raw, " -> ", verb), reporting_item, verb),
  item_level %>% filter(language == "english", str_detect(text_clean, "\\?$"), !is.na(verb)) %>%
    transmute(checklist_item_id, checklist, edge_case = "item ends with '?' but opens with a directive verb (kept)", reporting_item, verb),
  items_en %>% filter(!checklist_item_id %in% concept_pairs$checklist_item_id) %>%
    transmute(checklist_item_id, checklist, edge_case = "English item with no concept mapping (excluded from Analysis 2)", reporting_item, verb = NA_character_)
) %>% arrange(edge_case, checklist_item_id)
write_csv(edge_cases, file.path(out_dir, "edge_cases.csv"), na = "")

fmt <- function(x, d = 2) formatC(x, digits = d, format = "f")
g <- function(metric, subset = NULL) {
  r <- summary_statistics %>% filter(.data$metric == .env$metric)
  if (!is.null(subset)) r <- r %>% filter(.data$subset == .env$subset)
  r[1, ]
}
mi <- function(metric, subset = NULL, d = 1) { r <- g(metric, subset); paste0(fmt(r$value, d), " (IQR ", fmt(r$q1, d), "-", fmt(r$q3, d), ")") }
pc <- function(metric, subset = NULL) { r <- g(metric, subset); paste0(fmt(r$value, 1), "% (", r$note, ")") }

no_verb_counts <- verbs_en %>% filter(is.na(verb)) %>% count(no_verb_reason, sort = TRUE)
source_counts <- verbs_en %>% filter(!is.na(verb)) %>% count(verb_source, sort = TRUE)

decisions_md <- c(
  "# Directive verbs: decisions and edge cases to check",
  "",
  paste0("Generated by `R/directive_verbs.R` on ", format(Sys.Date()), ". Parameters: MULTI_VERB_RULE = \"", MULTI_VERB_RULE,
         "\", HARMONISE_SPELLING = ", HARMONISE_SPELLING, ", SEED = ", SEED, "."),
  "",
  "## 0. Files and columns used",
  "",
  "| Need | File | Column(s) |",
  "|---|---|---|",
  "| Verbatim item text | data/item_bank_reporting_guideline_compiled.csv | reporting_item |",
  "| Item ID | same | checklist_item_id |",
  "| Checklist ID | same | checklist (68 checklists; 60 guidelines have >1 checklist in 4 cases, e.g. page_2021 / page_2021_abstract / page_2021_extended) |",
  "| Guideline ID | same | study_id |",
  "| Manuscript section | item-level: standardised_section in the compiled file (9 levels incl. 'Methods', 'Other', NA); concept-level: standardised_section in the concepts file (7 clean levels). Analysis 2 by section uses the concepts file. |",
  "| Item-to-concept mapping | data/item_bank_reporting_guideline_concepts.csv | checklist_item_id x standardised_reporting_item_elements (one row per item x concept) |",
  "| Language | compiled file | language (english / portuguese / spanish) |",
  "",
  "## 1. Decisions taken (please confirm)",
  "",
  paste0("1. **Non-English items excluded.** ", sum(items$language != "english"), " items in 5 Portuguese/Spanish checklists (galvao_2015, galvao_2022, galvao_2022_abstracts, yepes.nunez_2021, yepes.nunez_2021_abstracts) are not tagged with the English model; verb = NA, reason 'non-English item'. All analyses use the ", n_en, " English items in ", nrow(checklist_level), " checklists."),
  "2. **Directive verb = lemma of the first imperative verb that opens the item** after skipping (a) list numbering/bullets/quotes, (b) a leading conditional or scoping phrase ending in a comma, colon or semicolon ('If applicable,', 'For each study,', 'In the title,', 'Where appropriate,'; up to three nested phrases), (c) a short label before a colon ('Background: state ...', 'Timing: describe ...'), and (d) adverbs/particles ('Please', 'Clearly', 'Briefly').",
  "3. **udpipe tagging alone is not sufficient.** udpipe (english-ewt) tags most sentence-initial imperatives wrongly ('Describe' as AUX/ADJ, 'Report' as NOUN, 'Present' as ADJ, 'List' as NOUN). The extraction therefore uses udpipe for tokenisation, lemmatisation, POS tags of the surrounding tokens and the dependency parse, combined with a curated lexicon (output/directive_verbs/verb_lexicon.csv):",
  "   - *strong* directive verbs are accepted whenever they open the item in base form and are not followed by 'of' ('List of citations', 'Use of hand searching' are noun phrases);",
  "   - *ambiguous* words that also open noun phrases in this corpus ('search', 'study', 'reference', 'time', 'effect', 'number', 'type', ...) are accepted only when followed by a determiner, pronoun, number, wh-word or 'at'/'about' ('Search at least two databases' yes; 'Search terms used' no);",
  "   - any other token tagged VERB/VB by udpipe is accepted under the same contextual condition.",
  paste0("   Items accepted by source: ", paste0(source_counts$verb_source, " = ", source_counts$n, collapse = "; "), "."),
  "4. **Items without an initial directive verb** get verb = NA with a reason: non-English; placeholder ('Not applicable for scoping reviews'); question / indirect question (first word How/What/Whether/Were/...); declarative or modal statement (first sentence has a subject attached to the root verb in the parse, or contains should/must/may/need to: 'The title must indicate ...', 'Authors should report ...', 'Abstract contains ...'); otherwise noun phrase or fragment ('Description of ...', 'Study eligibility criteria', 'Reporting of Discussion').",
  paste0("   Counts (English items): ", paste0(no_verb_counts$no_verb_reason, " = ", no_verb_counts$n, collapse = "; "), "."),
  paste0("5. **Multi-verb items** ('Describe and justify ...', 'List and define ...', 'compare and contrast'): the FIRST verb is used (MULTI_VERB_RULE = \"first\"); all coordinated verbs are kept in `coordinated_verbs`. ", sum(verbs_en$multi_verb, na.rm = TRUE), " English items are affected. Alternative built into the script: MULTI_VERB_RULE = \"exclude\". **Your call.**"),
  "6. **No synonyms merged.** 'report', 'provide', 'describe', 'state', 'specify', 'present', 'give' etc. are kept distinct. Only British/American spelling variants are harmonised (summarise -> summarize, synthesise -> synthesize, pre-register -> preregister); `verb_raw` keeps the original lemma. Set HARMONISE_SPELLING = FALSE to switch this off. **Your call.**",
  "7. **'See the PRISMA 2020 for Abstracts checklist'** (cross-reference items) open with the verb 'see' and are counted as such but flagged; you may prefer to treat them as NA.",
  "8. **Checklist-level metrics** are computed on items with a directive verb; `n_items` (all English items) and `n_items_with_verb` are both reported. Across-checklist summaries use checklists with >= 1 verb-bearing item (primary) and >= 5 verb-bearing items (sensitivity). Pielou's J is undefined (NA) when a checklist uses a single verb. Rarefaction (Hurlbert's expected number of distinct verbs in 10 items) uses checklists with >= 10 verb-bearing items.",
  paste0("9. **Concept mapping**: ", n_distinct(concept_pairs$concept), " distinct concept labels; ", sum(is.na(concept_raw$standardised_reporting_item_elements)), " rows with an empty concept label were dropped; ", n_dup_pairs, " duplicated item x concept pairs were collapsed to one. Each item's verb is assigned to every concept it maps to. Concept-level summaries use concepts requested by >= 2 items that have a directive verb (items without a verb cannot contribute a verb). ", nrow(filter(items_en, !checklist_item_id %in% concept_pairs$checklist_item_id)), " English items have no concept mapping (mainly APA_2018 abstract items) and are excluded from Analysis 2."),
  "10. **Section for Analysis 2** = `standardised_section` of the concepts file (44 concepts occur in more than one section, e.g. 'Report any limitations ...' in Abstract and Discussion; by-section results treat each concept x section as a unit, pooled results treat the concept as a unit).",
  "11. **Text artefacts in the data** (not modified in data/, handled in the script only): trailing extraction notes 'd-nb?' (harvranek_2020) and 'paste.txt?' (wong_2013a) removed before tagging; invalid UTF-8 bytes (curly quotes, dashes, non-breaking spaces) repaired; one item concatenates two items ('Use a structured formatDescribe explicitly ...', verb = use).",
  "12. **udpipe version**: the analysis was run with udpipe 0.8.11 (conda-forge build for R 4.2.1) rather than 0.8.16, which could not be installed in the sandbox (CRAN is not reachable). The udpipe model file is identical (english-ewt-ud-2.5-191206), so annotations should not differ. tidytext 0.4.1 is installed but not needed by this script.",
  "",
  "## 2. Edge cases",
  "",
  paste0("All flagged items are listed in `edge_cases.csv` (", nrow(edge_cases), " rows). Counts by type:"),
  "",
  "| Edge case | n items |",
  "|---|---|",
  edge_cases %>% mutate(type = str_remove(edge_case, ":.*$")) %>% count(type, sort = TRUE) %>%
    mutate(row = paste0("| ", type, " | ", n, " |")) %>% pull(row),
  "",
  "A random sample of 100 English items with the extracted verb is in `manual_check_sample_100.csv` (columns manual_verb / manual_agree / comment left empty for you).",
  "",
  "## 3. Headline numbers",
  "",
  paste0("- English items: ", n_en, "; with a directive verb: ", n_en_verb, " (", fmt(100 * n_en_verb / n_en, 1), "%); distinct verbs: ", nrow(verb_frequency), "."),
  paste0("- Most frequent verbs: ", paste0(head(verb_frequency$verb, 8), " (", head(verb_frequency$n_items, 8), ")", collapse = ", "), "."),
  paste0("- Checklists with >= 1 verb-bearing item: ", nrow(cl_any), " of ", nrow(checklist_level), ". Distinct verbs per checklist: median ", mi("n distinct verbs per checklist (median, IQR)", a1_subset, 0),
         "; Shannon H: ", mi("Shannon diversity H (median, IQR)", a1_subset, 2),
         "; Pielou J: ", mi("Pielou evenness J = H/ln(S) (median, IQR)", a1_subset, 2),
         "; proportion of items using the modal verb: ", mi("proportion of items using the modal verb (median, IQR)", a1_subset, 2), "."),
  paste0("- Checklists with >= 2 distinct verbs: ", pc("% checklists with >= 2 distinct verbs", a1_subset), "; >= 3: ", pc("% checklists with >= 3 distinct verbs", a1_subset), "."),
  paste0("- Spearman rho (n items with verb vs n distinct verbs): ", fmt(g("Spearman rho: n items with verb vs n distinct verbs")$value, 2), ", ", g("Spearman rho: n items with verb vs n distinct verbs")$note, "."),
  paste0("- Rarefied distinct verbs per 10 items (checklists with >= 10 verb-bearing items, n = ", nrow(cl_10), "): median ", mi("rarefied expected distinct verbs per 10 items (median, IQR)", NULL, 2), "."),
  paste0("- Concepts requested by >= 2 verb-bearing items: ", nrow(cp), ". Distinct verbs per concept: median ", mi("n distinct verbs per concept (median, IQR)", a2_subset, 0),
         "; >= 2 verbs: ", pc("% concepts requested with >= 2 distinct verbs", a2_subset), "; >= 3 verbs: ", pc("% concepts requested with >= 3 distinct verbs", a2_subset), "."),
  "",
  "Top 10 concepts (by number of verb-bearing items):",
  "",
  "| Concept | Section(s) | Items | Checklists | Distinct verbs | Verbs |",
  "|---|---|---|---|---|---|",
  top10 %>% mutate(row = paste0("| ", concept, " | ", sections, " | ", n_items_with_verb, " | ", n_checklists, " | ", n_distinct_verbs, " | ", verbs, " |")) %>% pull(row),
  "",
  "By section (concepts requested by >= 2 verb-bearing items):",
  "",
  "| Section | Concepts | Items | Median distinct verbs (IQR) | % >= 2 verbs | % >= 3 verbs |",
  "|---|---|---|---|---|---|",
  section_summary %>% mutate(row = paste0("| ", section, " | ", n_concepts, " | ", n_items_with_verb, " | ", median_distinct_verbs, " (", q1_distinct_verbs, "-", q3_distinct_verbs, ") | ", fmt(pct_concepts_2plus_verbs, 1), " | ", fmt(pct_concepts_3plus_verbs, 1), " |")) %>% pull(row)
)
writeLines(decisions_md, file.path(out_dir, "decisions_and_edge_cases.md"))

writeLines(capture.output(sessionInfo()), file.path(out_dir, "sessionInfo.txt"))

cat("\nDone. Outputs written to", out_dir, "\n")
print(summary_statistics %>% select(-q1, -q3) %>% as.data.frame())
