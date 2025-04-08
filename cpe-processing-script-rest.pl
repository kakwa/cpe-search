#!/usr/bin/perl
use strict;
use warnings;
use LWP::UserAgent;
use JSON;
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use File::Glob ':glob';
use File::Spec;
use POSIX qw(strftime);
use IO::Compress::Gzip qw(gzip);
use Encode qw(encode decode);
use open ':std', ':encoding(UTF-8)';
use Text::CSV;
use Text::CSV::Encoded;

# Configuration
my $RESULTS_PER_PAGE = 10000;
my $START_INDEX = 0;
my $OUTPUT_DIR = "html";
my $TEMP_DIR = tempdir("cpe-rest.XXXXXX", CLEANUP => 1);
my $DELIMITER = "\t";  # Using tab as delimiter instead of special character

# Create CSV object
my $csv = Text::CSV::Encoded->new ({
    binary    => 1,
    encoding_out  => 'UTF-8',
    sep_char  => ",",
}) or die "Cannot use CSV: " . Text::CSV->error_diag();

# Set up signal handlers
$SIG{INT} = $SIG{TERM} = sub {
    print "Cleaning up temporary files...\n";
    exit(1);
};

# Create output directory if it doesn't exist
make_path($OUTPUT_DIR);

# Function to fetch data from NVD API
sub fetch_cpe_data {
    my ($start_index, $results_per_page) = @_;
    my $ua = LWP::UserAgent->new;

    my $url = "https://services.nvd.nist.gov/rest/json/cpes/2.0?resultsPerPage=$results_per_page&startIndex=$start_index";
    my $headers = {};
    $headers->{'apiKey'} = $ENV{API_KEY} if $ENV{API_KEY};

    while (1) {
        my $response = $ua->get($url, %$headers);
        if ($response->is_success) {
            return $response->content;
            last;
        } else {
            print "Failed to fetch data, retrying...\n";
            sleep 10;
        }
    }
}

# Function to process JSON data and format output
sub process_json {
    my ($json_text, $output_file) = @_;
    my $last_line = "";

    open(my $out_fh, '>', $output_file) or die "Cannot open $output_file: $!";

    my $json = decode_json($json_text);

    foreach my $product (@{$json->{products}}) {
        my $cpe = $product->{cpe}->{cpeName};
        my $title = "";
        foreach my $t (@{$product->{cpe}->{titles}}) {
            $title = $t->{title} if $t->{lang} eq "en";
        }

        print "Processing CPE: $cpe\n";

        if ($cpe =~ /^cpe:([0-9.]+):([a-z]):([^:]+):([^:]+):([^:]+):/) {
            my ($cpe_version, $part, $vendor, $product, $version) = ($1, $2, $3, $4, $5);

            if ($cpe_version && $part && $vendor && $product) {
                my $simple_cpe = "cpe:$cpe_version:$part:$vendor:$product:*";
                my $generic_title = $title;

                if ($version && $version ne '-') {
                    $version =~ s/\\//g;
                    $generic_title =~ s/\s*\Q$version\E\s*/ /g;
                    $generic_title =~ s/\s+$//;
                }

                my $key = lc("$vendor\t$product");
                if ($key ne $last_line) {
                    $csv->print($out_fh, [$vendor, $product, $simple_cpe, $generic_title]);
                    print $out_fh "\n";
                    $last_line = $key;
                }
            }
        }
    }

    close($out_fh);
}

# Main processing
print "Fetching CPE data from NVD API...\n";

# Fetch initial data to get total count
my $init_json = decode_json(fetch_cpe_data(0, 1));
my $total_results = $init_json->{totalResults};
print "Total results: $total_results\n";

# Process data in chunks
while ($START_INDEX < $total_results) {
    print "Processing results $START_INDEX to " . ($START_INDEX + $RESULTS_PER_PAGE) . "...\n";

    # Fetch chunk of data
    my $data = fetch_cpe_data($START_INDEX, $RESULTS_PER_PAGE);

    # Process chunk
    process_json($data, "$TEMP_DIR/chunk_$START_INDEX.csv");

    $START_INDEX += $RESULTS_PER_PAGE;
}

sub combine_csv_chunks {
    my ($temp_dir, $output_filename) = @_;
    $output_filename ||= 'combined.csv';

    my %seen;  # Hash to track unique vendor-product combinations
    my @lines;

    # Read and collect all lines from chunk_*.csv
    foreach my $file (bsd_glob("$temp_dir/chunk_*.csv")) {
        open my $fh, '<:encoding(UTF-8)', $file or die "Cannot open $file: $!";
        while (my $row = $csv->getline($fh)) {
            my ($vendor, $product) = @$row;
            my $key = lc("$vendor\t$product");  # Case-insensitive comparison

            unless ($seen{$key}++) {
                push @lines, $row;
            }
        }
        close $fh;
    }

    # Sort the unique lines
    @lines = sort {
        lc("$a->[0]\t$a->[1]") cmp lc("$b->[0]\t$b->[1]")
    } @lines;

    # Write to output file
    my $output_path = File::Spec->catfile($temp_dir, $output_filename);
    open my $out, '>:encoding(UTF-8)', $output_path or die "Cannot write to $output_path: $!";
    $csv->print($out, $_) for @lines;
    close $out;

    return $output_path;
}

# Combine all CSV files
print "Combining results...\n";
my $result_path = combine_csv_chunks($TEMP_DIR);

# Create final JSON file
print "Creating JSON output...\n";
open(my $csv_fh, '<:encoding(UTF-8)', "$TEMP_DIR/combined.csv") or die "Cannot open combined.csv: $!";
my @entries;
while (my $row = $csv->getline($csv_fh)) {
    my ($vendor, $product, $filter, $title) = @$row;
    push @entries, {
        title => $title,
        vendor => $vendor,
        product => $product,
        filter => $filter
    };
}
close($csv_fh);

open(my $json_fh, '>:encoding(UTF-8)', "$OUTPUT_DIR/cpe-product-db.json") or die "Cannot open cpe-product-db.json: $!";
print $json_fh encode_json({ table => \@entries });
close($json_fh);

# Compress files
print "Compressing files...\n";
gzip "$OUTPUT_DIR/cpe-product-db.json" => "$OUTPUT_DIR/cpe-product-db.json.gz";
gzip "$TEMP_DIR/combined.csv" => "$OUTPUT_DIR/cpe-product-db.csv.gz";

print "Done! Output files in $OUTPUT_DIR/\n";
