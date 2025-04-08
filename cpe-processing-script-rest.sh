#!/bin/sh

# Configuration
RESULTS_PER_PAGE=10000
START_INDEX=0
OUTPUT_DIR="html"
TEMP_DIR=$(mktemp -d)

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Function to fetch data from NVD API
fetch_cpe_data() {
    start_index=$1
    results_per_page=$2
    output_file=$3

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
    input_file=$1
    output_file=$2
    last_line=""

    # Extract and format data
    jq -r '.products[] | [.cpe.cpeName, .cpe.titles[0].title] | @tsv' "$input_file" | while IFS=$(printf '\t') read -r cpe title; do
        # Extract vendor and product from CPE
        prefix=$(echo "$cpe" | sed -n 's/cpe:2\.3:\([a-z]\):\([^:]*\):\([^:]*\):\([^:]*\):.*/\1/p')
        vendor=$(echo "$cpe" | sed -n 's/cpe:2\.3:\([a-z]\):\([^:]*\):\([^:]*\):\([^:]*\):.*/\2/p')
        product=$(echo "$cpe" | sed -n 's/cpe:2\.3:\([a-z]\):\([^:]*\):\([^:]*\):\([^:]*\):.*/\3/p')
        version=$(echo "$cpe" | sed -n 's/cpe:2\.3:\([a-z]\):\([^:]*\):\([^:]*\):\([^:]*\):.*/\4/p')

        if [ -n "$prefix" ] && [ -n "$vendor" ] && [ -n "$product" ]; then
            # Create simplified CPE with wildcard
            simple_cpe="${prefix}:${vendor}:${product}:*"

            generic_title=$(echo "$title" | sed "s/ *[0-9]\\+\.[0-9]\\+[.0-9]* *//")
            # Create output line
            line="${vendor}☭${product}☭${simple_cpe}☭${generic_title}"

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
cat "$TEMP_DIR"/chunk_*.csv | sort > "$TEMP_DIR/combined.csv"

# Create final JSON file
echo "Creating JSON output..."
jq -s -R 'split("\n") | map(select(length > 0)) | map(split("☭")) | map({"title": .[3], "vendor": .[0], "product": .[1], "filter": .[2]}) | {"table": .}' "$TEMP_DIR/combined.csv" > "$OUTPUT_DIR/cpe-product-db.json"

# Compress files
echo "Compressing files..."
gzip -f -9 "$OUTPUT_DIR/cpe-product-db.json"
gzip -f -9 "$TEMP_DIR/combined.csv" && mv "$TEMP_DIR/combined.csv.gz" "$OUTPUT_DIR/cpe-product-db.csv.gz"

# Cleanup
echo "Cleaning up..."
rm -rf "$TEMP_DIR"

echo "Done! Output files in $OUTPUT_DIR/"
