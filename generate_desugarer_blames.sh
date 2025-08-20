#!/bin/bash

# Script to replace "desugarer_blame" with "desugarer_blame(line_number)" in all files in a directory

# Set default directory to current directory if no argument provided
TARGET_DIR=src/desugarers/

# Check if directory exists
if [ ! -d "$TARGET_DIR" ]; then
    echo "Error: Directory '$TARGET_DIR' does not exist."
    exit 1
fi

echo "Processing files in directory: $TARGET_DIR"
echo "Replacing 'desugarer_blame' with 'desugarer_blame(line_number)' in each file..."
echo

# Counter for processed files
processed_files=0

# Process all files in the directory (not subdirectories)
find "$TARGET_DIR" -maxdepth 1 -type f | while read -r file; do
    # Skip binary files by checking if file contains null bytes
    if grep -q $'\0' "$file" 2>/dev/null; then
        echo "Skipping binary file: $(basename "$file")"
        continue
    fi
    
    # Create a temporary file
    temp_file=$(mktemp)
    
    # Track if any replacements were made
    replacements_made=false
    
    # Process the file line by line
    line_number=1
    while IFS= read -r line || [ -n "$line" ]; do
        # Check if line contains "desugarer_blame"
        if [[ "$line" == *"desugarer_blame"* ]]; then
            # Replace all occurrences of "desugarer_blame" with "desugarer_blame(line_number)" on this line
            modified_line="${line//desugarer_blame/desugarer_blame($line_number)}"
            echo "$modified_line" >> "$temp_file"
            replacements_made=true
        else
            echo "$line" >> "$temp_file"
        fi
        ((line_number++))
    done < "$file"
    
    # If replacements were made, replace the original file
    if [ "$replacements_made" = true ]; then
        mv "$temp_file" "$file"
        echo "Processed: $(basename "$file")"
        ((processed_files++))
    else
        # No replacements needed, remove temp file
        rm "$temp_file"
    fi
done

# Note: The counter won't work correctly due to subshell, so we'll do a final count
final_count=$(find "$TARGET_DIR" -maxdepth 1 -type f -exec grep -l "desugarer_blame([0-9]\+)" {} \; 2>/dev/null | wc -l)

echo
echo "Script completed!"
echo "Files with replacements: $final_count"