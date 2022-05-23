# Publication legacy conversion
## How to run the conversion
### Input data requirements
- Make sure the folder structure & naming of the legacy input data is present in `./data/input`
- The expected input is an xml dump containing MS Access data from Dossieropvolging
- The input file should be named `legacy_data.xml`

- The Kanselarij data is expected to be in the graph `<http://mu.semte.ch/graphs/organizations/kanselarij>`
- The Themis minister data should be in the graph `<http://mu.semte.ch/graphs/public>`

### Add the service to a stack
Add the service to your `docker-compose.yml`:

```
  publication-legacy-conversion:
    image: kanselarij/publication-legacy-conversion
    links:
      - triplestore:database
    volumes:
      - ./data/input:/data/input
      - ./data/output/:/data/output
```

The mounted volume `./data/input` is the location where the input data is expected to be.
The result of the conversion will end up in the mounted volume `./data/output`.

### Available conversions
There are two possible conversions:
- The main conversion:
  Converts publication-flows and all related data
- An additional conversion for the number of pages:
  outputs triples linking the number of pages to the publication-flows in the triplestore.
  This conversion requires the publication-flows to be already added to the triplestore.

### Output of the conversion
Both main and additional conversion will produce a set of ttl and graph files:
- `./data/output/$TIME-legacy-publications-$N.ttl`
- `./data/output/$TIME-legacy-publications--update--number-of-pages-$N.ttl`
The error file contains messages about missing or invalid data encountered during the conversion.
- `./data/output/$TIME-errors.csv`
Other errors are logged to:
- `/logs/application.log`

## Reference
### API
```
# example calls
POST /api?actions=validate,convert&dossiernummer=123252,321240
POST /api?actions=update--number-of-pages&range=123,654
```
Endpoint to trigger validation and/or conversion(s).

Whether validation and/or conversion are triggerd is determined by:
- `actions`:
  - validate: determine whether the conversion is configured correctly for the provided AccessDB file
    currently the only checks run over the beleidsdomeinen
  - convert: convert the legacy publication-flows
  - update--number-of-pages: add the number of pages

One of the following query params can be specified to run the validation/conversion only on a subset of publications from the Access DB
- `range`: specifying number of start and end node
- `take`: taking each nth element into account
- `dossiernummer`: specify dossiernummer(s)