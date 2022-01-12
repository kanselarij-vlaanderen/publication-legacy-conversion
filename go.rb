require 'request_store'
require_relative 'sinatra_template/utils.rb'

include SinatraTemplate::Utils

MU = RDF::Vocabulary.new('http://mu.semte.ch/vocabularies/')
MU_CORE = RDF::Vocabulary.new(MU.to_uri.to_s + 'core/')

require_relative 'conversion.rb'

def take_and_skip nodes, count
  i = 0
  return nodes.select do
    take = i % count === 0
    i = i + 1
    take
  end
end


# require_relative './exploration-scripts/fields.rb'

# some ways to select AccessDB records
# nodes = AccessDB::nodes[(0...100)]
nodes = take_and_skip(AccessDB::nodes, 5000)
# nodes = AccessDB.by_dossiernummer(["53001"])
run(nodes)
