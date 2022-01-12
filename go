#!/bin/bash --login
rvm use ruby-2.5.8
MU_SPARQL_ENDPOINT=http://localhost:8890/sparql MU_APPLICATION_GRAPH=http://mu.semte.ch/graphs/organizations/kanselarij \
    SAFE=off LOG_LEVEL=debug INPUT_DIR=./data/input/ OUTPUT_DIR=./data/output/ \
    bundle exec ruby ./go.rb