# CPE Product Database Search

[![CPE DB Update](https://github.com/kakwa/cpe-search/actions/workflows/publish.yml/badge.svg)](https://github.com/kakwa/cpe-search/actions/workflows/publish.yml)


Live DB: [https://kakwa.github.io/cpe-search/](https://kakwa.github.io/cpe-search/)

Web interface to search and browse the CPE (Common Platform Enumeration) product database and easily find CPE filters.

CPE DB is updated daily.

## Self-Hosting

Install dependencies:

```shell
sudo apt install libsaxonhe-java
```

```shell
# Build the DB csv & json DB
./cpe-processing-script.sh

# Result directory
ls html/ 
cpe-product-db.csv.gz  cpe-product-db.json.gz  favicon.ico  index.html
```

Testing it (in production, use `nginx` for example):
```shell
cd html/
# Using Python's built-in server
python3 -m http.server 8000
```

Then visit 127.0.0.1:8080 with your browser.
