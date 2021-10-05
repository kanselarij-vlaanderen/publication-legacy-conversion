require 'request_store'
require_relative 'sinatra_template/utils.rb'

include SinatraTemplate::Utils

require_relative 'conversion.rb'

# require_relative './scripts/mandatees_in_access_db.rb'
# require_relative './scripts/mandatees_in_linked_db.rb'
# require_relative './scripts/fields.rb'
# require_relative './scripts/document_nr.rb'
#require_relative './scripts/document_nr_datums.rb'
#require_relative './scripts/beleidsdomein.rb'

# require_relative './query_government_domains.rb'
# require_relative './scripts/beleidsdomeinen_in_linked_db.rb'

nodes = AccessDB::nodes[(0...100)]
run('./data/input/', './data/output/', nodes)

# $query_government_domains = QueryGovernmentDomains.new($errors_csv, "./data/input/government-domains-abbreviations.csv")
# $query_mandatees = QueryMandatees.new("./data/input/mandatees-corrections.csv")
# $errors_csv = CSV.open(
#   "./data/output/errors.csv", mode='wt')

# nodes.each do |node|
#   process_publicatie(node)
# end

# RDF::Writer.open('./data/output/publicaties.ttl') { |writer| writer << $public_graph }