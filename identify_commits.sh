#!/bin/bash

# Define the output file for commit messages
commit_file="commit_messages.txt"
output_file="matching_commits.txt"
highlighted_output_file="highlighted_matching_commits.txt"

# Define the keyword pattern (case insensitive matching)
keyword_pattern="microsoft|linkedin|facebook|meta|google|alphabet|bat.js|ads|data collection|track|monitoring|affiliate|anonymous|confidential|sensitive|encryption|token|password|credential|access key|secret|authentication|authorization|api key|oauth|certificate|gcp|user data|personal data|pii|gdpr|data breach|leak|exposure|dump|trace|spyware|malware|backdoor|exploit|vulnerability|hack|intrusion|breach|incident|threat|emergency|policy|legal|internal use only|not for public use|do not share|private|restricted|prototype|nda|sensitive information|data protection|decryption|cipher"
IFS='|' read -r -a keywords <<< "$keyword_pattern"

# Extract all commit messages with delimiters
git log --all --pretty=format:"--DELIMITER--%n%H%n%s%n%b%n" --no-merges > $commit_file

# Use awk to filter commit messages containing sensitive keywords and highlight lines
awk -v pattern="$keyword_pattern" '
BEGIN {
  pattern = tolower(pattern);
}

/--DELIMITER--/ {
  if (tolower(commit) ~ pattern) {
    print commit > "'$output_file'"
    split(commit, lines, "\n")
    for (i in lines) {
      if (tolower(lines[i]) ~ pattern) {
        print "--DELIMITER--" > "'$highlighted_output_file'"
        print lines[2] > "'$highlighted_output_file'"
        print lines[i] > "'$highlighted_output_file'"
      }
    }
  }
  commit = $0 "\n"
  next
}

{
  commit = commit $0 "\n"
}

END {
  if (tolower(commit) ~ pattern) {
    print commit > "'$output_file'"
    split(commit, lines, "\n")
    for (i in lines) {
      if (tolower(lines[i]) ~ pattern) {
        print "--DELIMITER--" > "'$highlighted_output_file'"
        print lines[2] > "'$highlighted_output_file'"
        print lines[i] > "'$highlighted_output_file'"
      }
    }
  }
}
' $commit_file

# Report
total_commits=$(grep -c -- "--DELIMITER--" $commit_file)
matching_commits=$(grep -c -- "--DELIMITER--" $output_file)
total_lines=$(wc -l < $output_file)

echo "Total commits processed: $total_commits"
echo "Matching commits found: $matching_commits"
echo "Total lines in the output file: $total_lines"

# Count occurrences of each keyword and store in a temporary file
tmp_file=$(mktemp)
for keyword in "${keywords[@]}"; do
  count=$(grep -iow "$keyword" $output_file | wc -l)
  echo "$count $keyword" >> $tmp_file
done

# Sort and display keywords by count
echo "Keyword occurrences (sorted by count):"
sort -nr $tmp_file
rm $tmp_file
