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

CPE_XML=official-cpe-dictionary_v2.3.xml
# Process with XSLT
echo "Transforming to CSV..."
java -jar /usr/share/java/Saxon-HE-*.jar -s:$CPE_XML -xsl:$XSLT_FILE -o:$OUTPUT_CSV

# Check if transformation was successful
if [ ! -f "$OUTPUT_CSV" ]; then
  echo "Error: Failed to transform CPE dictionary to CSV"
  rm -rf "$TEMP_DIR"
  exit 1
fi

cat $OUTPUT_CSV | column -J -s '☭' --table-columns 'title,vendor,product,filter' > $OUTPUT_JSON

# Clean up
echo "Cleaning up temporary files..."
rm -rf "$TEMP_DIR"

echo "Done! CSV file created: $OUTPUT_CSV"
