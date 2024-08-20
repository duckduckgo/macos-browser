#!/bin/bash

# Define the output file
output_file="comments_export.txt"

# Define the sensitive keyword pattern (case insensitive matching)
sensitive_keywords="microsoft|linkedin|facebook|meta|google|alphabet|bat.js|ads|data collection|track|monitoring|affiliate|anonymous|confidential|sensitive|encryption|token|password|credential|access key|secret|authentication|authorization|api key|oauth|certificate|gcp|user data|personal data|pii|gdpr|data breach|leak|exposure|dump|trace|spyware|malware|backdoor|exploit|vulnerability|hack|intrusion|breach|incident|threat|emergency|policy|legal|internal use only|not for public use|do not share|private|restricted|prototype|nda|sensitive information|data protection|decryption|cipher"
IFS='|' read -r -a keywords <<< "$sensitive_keywords"

# Find all Swift files in the repository
swift_files=$(find . -name "*.swift")

# Initialize the output file
echo "Export of comments from Swift files containing sensitive keywords" > $output_file
echo "================================================================" >> $output_file
echo "" >> $output_file

# Function to check if a line is a comment
is_comment() {
  [[ $1 =~ ^\s*// ]] || [[ $1 =~ ^\s*/\* ]] || [[ $1 =~ ^\s*\* ]] || [[ $1 =~ ^\s*\*/ ]]
}

# Function to check if a comment contains sensitive keywords
contains_sensitive_keyword() {
  local line=$1
  for keyword in "${keywords[@]}"; do
    if [[ $line =~ $keyword ]]; then
      return 0  # true
    fi
  done
  return 1  # false
}

# Loop through each Swift file and extract comments
for file in $swift_files; do
  header_skipped=false
  in_multiline_comment=false
  while IFS= read -r line; do
    # Check if we are in a multiline comment
    if $in_multiline_comment; then
      if contains_sensitive_keyword "$line"; then
        echo "$line" >> $output_file
      fi
      [[ $line =~ \*/ ]] && in_multiline_comment=false
      continue
    fi

    # Skip file headers
    if ! $header_skipped; then
      if is_comment "$line"; then
        [[ $line =~ /\* ]] && in_multiline_comment=true
        continue
      elif [[ -z $line || $line =~ ^\s*$ ]]; then
        continue
      else
        header_skipped=true
      fi
    fi

    # Extract single-line comments containing sensitive keywords
    if [[ $line =~ ^\s*// ]] && contains_sensitive_keyword "$line"; then
      echo "$line" >> $output_file
    fi

    # Check for multiline comment start
    if [[ $line =~ /\* ]] && contains_sensitive_keyword "$line"; then
      echo "$line" >> $output_file
      in_multiline_comment=true
    fi
  done < "$file"
done

echo "Comments export completed. Output file: $output_file"
