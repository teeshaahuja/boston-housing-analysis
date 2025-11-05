#!/bin/bash
# Render both HTML and GitHub Markdown reports with correct image paths

cd "$(dirname "$0")"

# Render HTML
Rscript -e 'rmarkdown::render("report.Rmd", output_file="report.html", output_dir="results")'

# Render GitHub Markdown
Rscript -e 'rmarkdown::render("report.Rmd", output_format="github_document", output_file="report.md", output_dir="results")'

# Fix image paths in Markdown for GitHub (from results/ to ../figures/)
sed -i '' 's|src="figures/|src="../figures/|g' results/report.md

echo "Reports rendered successfully!"
echo "- HTML: results/report.html"
echo "- Markdown: results/report.md (images fixed for GitHub)"

