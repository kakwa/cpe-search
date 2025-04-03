#!/bin/bash

# Configuration
RESULTS_PER_PAGE=10000
START_INDEX=0
OUTPUT_DIR="html"
TEMP_DIR=$(mktemp -d)

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Function to fetch data from NVD API
fetch_cpe_data() {
    local start_index=$1
    local results_per_page=$2
    local output_file=$3

    HEADERS=""
    if [ -n "$API_KEY" ]; then
        HEADERS="-H apiKey:${API_KEY}"
    fi

    while ! curl -f -s $HEADERS "https://services.nvd.nist.gov/rest/json/cpes/2.0?resultsPerPage=$results_per_page&startIndex=$start_index" > "$output_file"; do
        echo "Failed to fetch data, retrying..."
        sleep 10
    done
}

# Function to process JSON data and format output
process_json() {
    local input_file=$1
    local output_file=$2
    local last_line=""

    # Extract and format data
    jq -r '.products[] | [.cpe.cpeName, .cpe.titles[0].title] | @tsv' "$input_file" | while IFS=$'\t' read -r cpe title; do
        # Extract vendor and product from CPE
        if [[ $cpe =~ (cpe:2\.3:[a-z]):([^:]+):([^:]+):([^:]+): ]]; then
            prefix="${BASH_REMATCH[1]}"
            vendor="${BASH_REMATCH[2]}"
            product="${BASH_REMATCH[3]}"
            version="${BASH_REMATCH[4]}"

            # Create simplified CPE with wildcard
            simple_cpe="${prefix}:${vendor}:${product}:*"


            generic_title=$(echo ${title} | sed "s/ *[0-9]\\+\.[0-9]\\+[.0-9]* *//")
            # Create output line
            line="${generic_title}☭${vendor}☭${product}☭${simple_cpe}"

            # Skip if duplicate
            if [ "${vendor}☭${product}" != "$last_line" ]; then
                echo "$line" >> "$output_file"
                last_line="${vendor}☭${product}"
            fi
        fi
    done
}

# Main processing
echo "Fetching CPE data from NVD API..."

# Fetch initial data to get total count
fetch_cpe_data 0 1 "$TEMP_DIR/initial.json"
total_results=$(jq -r '.totalResults' "$TEMP_DIR/initial.json")
echo "Total results: $total_results"

# Process data in chunks
while [ $START_INDEX -lt $total_results ]; do
    echo "Processing results $START_INDEX to $((START_INDEX + RESULTS_PER_PAGE))..."

    # Fetch chunk of data
    fetch_cpe_data $START_INDEX $RESULTS_PER_PAGE "$TEMP_DIR/chunk_$START_INDEX.json"

    # Process chunk
    process_json "$TEMP_DIR/chunk_$START_INDEX.json" "$TEMP_DIR/chunk_$START_INDEX.csv"

    START_INDEX=$((START_INDEX + RESULTS_PER_PAGE))
done

# Combine all CSV files
echo "Combining results..."
cat "$TEMP_DIR"/chunk_*.csv > "$TEMP_DIR/combined.csv"


# Create final JSON file
echo "Creating JSON output..."
jq -s -R 'split("\n") | map(select(length > 0)) | map(split("☭")) | map({"title": .[0], "vendor": .[1], "product": .[2], "filter": .[3]}) | {"table": .}' "$TEMP_DIR/combined.csv" > "$OUTPUT_DIR/cpe-product-db.json"

# Compress files
echo "Compressing files..."
gzip -f -9 "$OUTPUT_DIR/cpe-product-db.json"
gzip -f -9 "$TEMP_DIR/combined.csv" && mv "$TEMP_DIR/combined.csv.gz" "$OUTPUT_DIR/cpe-product-db.csv.gz"

# Cleanup
echo "Cleaning up..."
rm -rf "$TEMP_DIR"

echo "Done! Output files in $OUTPUT_DIR/"
