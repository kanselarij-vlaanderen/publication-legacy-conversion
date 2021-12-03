require 'ostruct'

module RegulationTypes
  def self.run display=false

    keys_csv = Files.regulation_types_keys
    types = keys_csv.map { |r| r[0] }

    types.each do |t|
      rec = OpenStruct.new dossiernummer: "test", soort: t
      uri = ConvertRegulationTypes.convert rec
      if uri.nil?
        raise Error("regulation-type #{t} has no corresponding URI")
      end

      result = LinkedDB::query %{
        PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
        PREFIX ext: <http://mu.semte.ch/vocabularies/ext/>
        PREFIX pub: <http://mu.semte.ch/vocabularies/ext/publicatie/>
        SELECT ?regulationType ?label
        WHERE {
            GRAPH <http://mu.semte.ch/graphs/public> {
              <#{uri}> a ext:RegelgevingType .
              <#{uri}> skos:prefLabel ?label .
            }
        }
      }
      
      first_result = result.first
      if first_result.nil?
        puts "NOT FOUND: #{t}"
      end

      puts "#{t}: #{result.first[:label]}" if display
    end

  end
end