MU_SPARQL_ENDPOINT=http://localhost:8890/sparql LOG_LEVEL=DEBUG bundle exec ruby ./go.rb

#docker build --tag ikke/publication-legacy-conversion:0.1 .
# docker run ikke/publication-legacy-conversion:0.1 ruby ./script.rb
#docker stop convertor
#docker rm convertor
# docker run --name convertor ikke/publication-legacy-conversion:0.1 ruby /usr/src/app/script.rb