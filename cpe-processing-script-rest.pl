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

# Configuration
my $RESULTS_PER_PAGE = 10000;
my $START_INDEX = 0;
my $OUTPUT_DIR = "html";
my $TEMP_DIR = tempdir("cpe-rest.XXXXXX", CLEANUP => 1);

# Set up signal handlers
$SIG{INT} = $SIG{TERM} = sub {
    print "Cleaning up temporary files...\n";
    exit(1);
};

# Create output directory if it doesn't exist
make_path($OUTPUT_DIR);

# Function to fetch data from NVD API
sub fetch_cpe_data {
    my ($start_index, $results_per_page, $output_file) = @_;
    my $ua = LWP::UserAgent->new;
    
    my $url = "https://services.nvd.nist.gov/rest/json/cpes/2.0?resultsPerPage=$results_per_page&startIndex=$start_index";
    my $headers = {};
    $headers->{'apiKey'} = $ENV{API_KEY} if $ENV{API_KEY};
    
    while (1) {
        my $response = $ua->get($url, %$headers);
        if ($response->is_success) {
            open(my $fh, '>', $output_file) or die "Cannot open $output_file: $!";
            print $fh $response->content;
            close($fh);
            last;
        } else {
            print "Failed to fetch data, retrying...\n";
            sleep 10;
        }
    }
}

# Function to process JSON data and format output
sub process_json {
    my ($input_file, $output_file) = @_;
    my $last_line = "";
    
    open(my $in_fh, '<', $input_file) or die "Cannot open $input_file: $!";
    open(my $out_fh, '>>', $output_file) or die "Cannot open $output_file: $!";
    
    my $json_text = do { local $/; <$in_fh> };
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
                }
                
                my $line = "$vendor☭$product☭$simple_cpe☭$generic_title";
                
                if ("$vendor☭$product" ne $last_line) {
                    print $out_fh "$line\n";
                    $last_line = "$vendor☭$product";
                }
            }
        }
    }
    
    close($in_fh);
    close($out_fh);
}

# Main processing
print "Fetching CPE data from NVD API...\n";

# Fetch initial data to get total count
fetch_cpe_data(0, 1, "$TEMP_DIR/initial.json");
open(my $init_fh, '<', "$TEMP_DIR/initial.json") or die "Cannot open initial.json: $!";
my $init_json = decode_json(do { local $/; <$init_fh> });
close($init_fh);
my $total_results = $init_json->{totalResults};
print "Total results: $total_results\n";

# Process data in chunks
while ($START_INDEX < $total_results) {
    print "Processing results $START_INDEX to " . ($START_INDEX + $RESULTS_PER_PAGE) . "...\n";
    
    # Fetch chunk of data
    fetch_cpe_data($START_INDEX, $RESULTS_PER_PAGE, "$TEMP_DIR/chunk_$START_INDEX.json");
    
    # Process chunk
    process_json("$TEMP_DIR/chunk_$START_INDEX.json", "$TEMP_DIR/chunk_$START_INDEX.csv");
    
    $START_INDEX += $RESULTS_PER_PAGE;
}

sub combine_csv_chunks {
    my ($temp_dir, $output_filename) = @_;
    $output_filename ||= 'combined.csv';  # default output name if not provided

    my %seen;
    my @lines;

    # Read and collect all lines from chunk_*.csv
    foreach my $file (bsd_glob("$temp_dir/chunk_*.csv")) {
        open my $fh, '<', $file or die "Cannot open $file: $!";
        while (my $line = <$fh>) {
            chomp $line;
            unless ($seen{$line}++) {
                push @lines, $line;
            }
        }
        close $fh;
    }

    # Sort the unique lines
    @lines = sort @lines;

    # Write to output file
    my $output_path = File::Spec->catfile($temp_dir, $output_filename);
    open my $out, '>', $output_path or die "Cannot write to $output_path: $!";
    print $out "$_\n" for @lines;
    close $out;

    return $output_path;
}

# Combine all CSV files
print "Combining results...\n";
my $result_path = combine_csv_chunks($TEMP_DIR);

# Create final JSON file
print "Creating JSON output...\n";
open(my $csv_fh, '<', "$TEMP_DIR/combined.csv") or die "Cannot open combined.csv: $!";
my @lines = grep { length } <$csv_fh>;
close($csv_fh);

my @entries;
foreach my $line (@lines) {
    chomp $line;
    my ($vendor, $product, $filter, $title) = split('☭', $line);
    push @entries, {
        title => $title,
        vendor => $vendor,
        product => $product,
        filter => $filter
    };
}

open(my $json_fh, '>', "$OUTPUT_DIR/cpe-product-db.json") or die "Cannot open cpe-product-db.json: $!";
print $json_fh encode_json({ table => \@entries });
close($json_fh);

# Compress files
print "Compressing files...\n";
gzip "$OUTPUT_DIR/cpe-product-db.json" => "$OUTPUT_DIR/cpe-product-db.json.gz";
gzip "$TEMP_DIR/combined.csv" => "$OUTPUT_DIR/cpe-product-db.csv.gz";

print "Done! Output files in $OUTPUT_DIR/\n"; 
