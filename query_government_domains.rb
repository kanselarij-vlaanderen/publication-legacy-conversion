class QueryGovernmentDomains
  def initialize (
    errors,
    abbreviations_filepath
  )
    @errors = errors

    abbreviations = CSV.read abbreviations_filepath, 'rt', encoding: "UTF-8"
    
    abbreviation_values = abbreviations.map { |row|
      "(#{row[0].sparql_escape} #{row[1].sparql_escape})"
    } .join " "

    query = %{
      PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
      SELECT DISTINCT ?abbreviation ?uri
      WHERE {
        GRAPH <http://mu.semte.ch/graphs/public> {
          VALUES (?abbreviation ?label_in) {
            #{ abbreviation_values }
          }

          OPTIONAL {
            ?uri a <http://kanselarij.vo.data.gift/core/Beleidsdomein> .
            ?uri skos:prefLabel ?label .
          }

          FILTER (
            (REPLACE(LCASE(REPLACE(REPLACE(?label, "[^\\\\w\\\\s]", ""), "\\\\s+", " ")), " en ", " "))
            = (REPLACE(LCASE(REPLACE(REPLACE(?label_in, "[^\\\\w\\\\s]", ""), "\\\\s+", " ")), " en ", " ")))
        }
      }
    }

    triples = LinkedDB.query query
    @abbreviations = triples.map { |tri| [tri[:abbreviation].value, tri[:uri]] } .to_h

    SinatraTemplate::Utils.log.error("not found: #{abbreviations.select { |abbr| !@abbreviations[abbr[0]]}}")
  end

  def query rec
    beleidsdomein = rec.beleidsdomein
    
    return [] if beleidsdomein.nil?

    beleidsdomeinen = beleidsdomein.split '/'
    beleidsdomeinen.each { |d| d.strip!; d.downcase! }

    beleidsdomeinen.filter_map do |d|
      uri = @abbreviations[d]
      if uri.nil?
        @errors << [rec.dossiernummer, "government-domain", "not-found", d]
        next nil
      end

      next uri
    end
  end
end
