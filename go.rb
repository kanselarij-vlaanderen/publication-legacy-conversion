require 'request_store'
require_relative 'sinatra_template/utils.rb'

include SinatraTemplate::Utils

MU = RDF::Vocabulary.new('http://mu.semte.ch/vocabularies/')
MU_CORE = RDF::Vocabulary.new(MU.to_uri.to_s + 'core/')

require_relative 'conversion.rb'

def take_and_skip nodes, size
  i = 0
  return nodes.select do
    take = i % size === 0
    i = i + 1
    take
  end
end

# require_relative './scripts/mandatees_in_access_db.rb'
# require_relative './scripts/mandatees_in_linked_db.rb'
# require_relative './scripts/fields.rb'
# require_relative './scripts/beleidsdomeinen_in_access_db.rb'
# require_relative './scripts/beleidsdomeinen_in_linked_db.rb'

# nodes = AccessDB::nodes[(0...100)]
# nodes = take_and_skip(AccessDB::nodes, 5000)
# run(ENV["INPUT_DIR"], ENV["OUTPUT_DIR"], nodes)
