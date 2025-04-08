#!/bin/sh

# Script to download CPE dictionary, decompress, and transform to CSV & JSON

# Create a temporary directory
TEMP_DIR=$(mktemp -d)
echo "Created temporary directory: $TEMP_DIR"

# Define file paths
CPE_GZ="$TEMP_DIR/official-cpe-dictionary.xml.gz"
CPE_XML="$TEMP_DIR/official-cpe-dictionary.xml"
XSLT_FILE="$(dirname $0)/cpe-to-csv.xslt"
OUTPUT_CSV="html/cpe-product-db.csv"
OUTPUT_JSON="html/cpe-product-db.json"
OUTPUT_JSON_GZ="html/cpe-product-db.json.gz"

# Download CPE dictionary
echo "Downloading CPE dictionary..."
curl -s -o "$CPE_GZ" https://nvd.nist.gov/feeds/xml/cpe/dictionary/official-cpe-dictionary_v2.3.xml.gz

# Check if download was successful
if [ ! -f "$CPE_GZ" ]; then
  echo "Error: Failed to download CPE dictionary"
  rm -rf "$TEMP_DIR"
  exit 1
fi

# Decompress the file
echo "Decompressing CPE dictionary..."
gunzip -c "$CPE_GZ" > "$CPE_XML"

# Check if decompression was successful
if [ ! -f "$CPE_XML" ]; then
  echo "Error: Failed to decompress CPE dictionary"
  rm -rf "$TEMP_DIR"
  exit 1
fi

# Process with XSLT
echo "Transforming to CSV..."
java -jar /usr/share/java/Saxon-HE-*.jar -s:$CPE_XML -xsl:$XSLT_FILE -o:$OUTPUT_CSV

# Check if transformation was successful
if [ ! -f "$OUTPUT_CSV" ]; then
  echo "Error: Failed to transform CPE dictionary to CSV"
  rm -rf "$TEMP_DIR"
  exit 1
fi


# Convert CSV to JSON and compress
echo "Converting to JSON and compressing..."
cat $OUTPUT_CSV | column -J -s '☭' --table-columns 'title,vendor,product,filter' | gzip -f -c > $OUTPUT_JSON_GZ


gzip -f $OUTPUT_CSV

# Clean up
echo "Cleaning up temporary files..."
rm -rf "$TEMP_DIR"

echo "Done! Gzipped JSON file created: $OUTPUT_JSON_GZ"
