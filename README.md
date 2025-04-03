# CPE Product Database Search

[![CPE DB Update](https://github.com/kakwa/cpe-search/actions/workflows/publish.yml/badge.svg)](https://github.com/kakwa/cpe-search/actions/workflows/publish.yml)


Common Platform Enumeration search tool: [https://kakwa.github.io/cpe-search/](https://kakwa.github.io/cpe-search/)

This project is a basic web interface to search and browse the CPE (Common Platform Enumeration) database and easily find CPE filters.

The raw CSV/JSON files (gziped) are available here:
* [cpe-product-db.csv.gz](https://kakwa.github.io/cpe-search/cpe-product-db.csv.gz)
* [cpe-product-db.json.gz](https://kakwa.github.io/cpe-search/cpe-product-db.json.gz)


The CPE Database is updated daily.

## Self-Hosting

If you want to self-host the DB:

Install dependencies:

```shell
sudo apt install libsaxonhe-java
```
Build the DB csv & json DB:
```shell
./cpe-processing-script.sh

# Result directory
ls html/ 
cpe-product-db.csv.gz  cpe-product-db.json.gz  favicon.ico  index.html
```

Testing it:
```shell
cd html/
# Using Python's built-in server
python3 -m http.server 8000
```

Then visit 127.0.0.1:8000 with your browser.

Use servers like `apache` or `nginx` to serve the content of `html/` in production.
I
