# synthesis_item_bank

## Repository Structure

```text
synthesis_item_bank/
│
├── R/
│   ├── analysis.qmd              # Main Quarto analysis document (figures, statistics)
│   ├── analysis.rmarkdown        # R Markdown version of the analysis
│   ├── datapage.qmd              # Interactive HTML datapage (DT + crosstalk)
│   ├── datapage.html             # Pre-rendered interactive datapage
│   └── datapage_files/           # Supporting assets for rendered datapage
│
├── R.data/                       # Cached R data objects
│
├── data/
│   ├── item_bank_reporting_guideline.csv            # Guideline-level metadata
│   ├── item_bank_reporting_guideline_compiled.csv   # Item-level data (wide format)
│   ├── item_bank_reporting_guideline_concepts.csv   # Concept-level data (long format)
│   ├── tables_by_section.xlsx                       # Item tables organised by section
│   └── concept_tables_by_section.xlsx               # Concept tables organised by section
│
├── figures/                      # Output figures (JPG, 300 dpi)
├── literature_search/            # Search strategy files
├── literature_screen/            # Screening decision records
│
├── english-ewt-ud-2.5-191206.udpipe   # UDPipe English language model (POS tagging)
├── synthesis_item_bank.Rproj          # RStudio project file
├── .gitignore
├── LICENSE
└── README.md
```

## Data Description

All datasets cover synthesis-relevant reporting guidelines and are the primary (non-pilot) versions.

| File | Unit of observation | Key variables |
|---|---|---|
| `item_bank_reporting_guideline.csv` | Guideline | `study_id`, `year`, `DOI`, `methodology_category`, `discipline`, `guideline_extension` |
| `item_bank_reporting_guideline_compiled.csv` | Reporting item | `study_id`, `checklist`, `checklist_item_id`, `reporting_item_number`, `reporting_item`, `section`, `topic`, `standardised_section`, `language` |
| `item_bank_reporting_guideline_concepts.csv` | Concept per item | `study_id`, `checklist`, `checklist_item_id`, `reporting_item_number`, `standardised_reporting_item_elements`, `standardised_section`, `standardised_subsection` |
| `tables_by_section.xlsx` | Item | Items tabulated by standardised section |
| `concept_tables_by_section.xlsx` | Concept | Concepts tabulated by standardised section |



## Citation

If you use these data or code, please cite this repository until a formal publication is available:

> Morrison, K. (2026). *Synthesis Item Bank* [Data and code]. GitHub. https://github.com/KyleMorrison99/synthesis_item_bank

## License

This project is licensed under the terms of the [MIT License](LICENSE).

## Contact

**Kyle Morrison**  
PhD Candidate, Environmental Health & Evidence Synthesis  
University of Alberta, Edmonton, AB, Canada  
GitHub: [@KyleMorrison99](https://github.com/KyleMorrison99)
