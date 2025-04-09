# CPE Product Database Search

[![CPE DB Update](https://github.com/kakwa/cpe-search/actions/workflows/publish.yml/badge.svg)](https://github.com/kakwa/cpe-search/actions/workflows/publish.yml)


Common Platform Enumeration search tool: [https://kakwa.github.io/cpe-search/](https://kakwa.github.io/cpe-search/)

This project is a basic web interface to search and browse the CPE (Common Platform Enumeration) database and easily find CPE filters.

The raw CSV/JSON files (gziped) are available here:
* [cpe-product-db.csv.gz](https://kakwa.github.io/cpe-search/cpe-product-db.csv.gz)
* [cpe-product-db.json.gz](https://kakwa.github.io/cpe-search/cpe-product-db.json.gz)


The CPE Database is updated daily.

# Self-Hosting

## Dependencies

If you want to self-host the DB:

Install dependencies:
```
sudo apt install libwww-perl libtext-csv-encoded-perl
```

## CPE DB generation

Build the csv & json DBs:

```shell
./cpe-processing-script-rest.pl

# Result directory
ls html/ 
cpe-product-db.csv.gz  cpe-product-db.json.gz  favicon.ico  index.html
```

## Testing

Once the DB is generated, run:

```shell
# Using Python's built-in server
python3 -m http.server -d html/ 8080

# website available at http://127.0.0.1:8080
```

## Production

Optionally, get a NVD `API_KEY`, go to https://nvd.nist.gov/developers/request-an-api-key to get one.

Copy over the content of `html/` into `<your_static_webroot>`.

Initialize CPE DBs:

```bash
# API_KEY is optional
API_KEY='<nvd api key>' \
OUTPUT_DIR='<your_static_webroot>' \
./cpe-processing-script-rest.pl
```

Publish `<your_static_webroot>` using static hosting (`nginx`, `apache` or any other server).

Add the following cron to update it daily, tweak the minutes/hours:

```cron
12 3 * * * API_KEY='<nvd api key>' OUTPUT_DIR='<your_static_webroot>' /path/to/cpe-processing-script-rest.pl
```
