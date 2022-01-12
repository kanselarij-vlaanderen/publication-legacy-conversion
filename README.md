# Publication legacy conversion
## How to run the conversion
### Input data requirements
- Make sure the folder structure & naming of the legacy input data is present in `./data/input`
- The expected input is an xml dump containing MS Access data from Dossieropvolging
- The input file should be named `legacy_data.xml`

- The Kanselarij data is expected to be in the graph  `<http://mu.semte.ch/graphs/organizations/kanselarij>`
- The Themis minister data should be in the graph  `<http://mu.semte.ch/graphs/ministers>`

### Add the service to a stack
Add the service to your `docker-compose.yml`:

```
  publication-legacy-conversion:
    image: semtech/mu-ruby-template:2.11.0
    ports:
      - 8888:80
    links:
      - database:database
    volumes:
      - ./data/input/legacy_data.xml:/data/input/legacy_data.xml
      - ./data/output/:/data/output/
```

The mounted volume `./data/input` is the location where the input data is expected to be.
The result of the conversion will end up in the mounted volume `./data/output`.

### Output of the conversion
The conversion will produce 2 files:
- `./data/output/legacy_data.ttl`
will contain triples generated by the conversion
- `./data/output/errors.txt`
contains the errors encountered during the conversion

## Reference
### API
```
POST /ingest
```
Endpoint to start a conversion
