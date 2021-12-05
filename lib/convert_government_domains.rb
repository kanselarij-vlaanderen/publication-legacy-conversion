GOVERNMENT_DOMAIN_CONCEPT_SCHEME_URI = RDF::URI 'http://themis.vlaanderen.be/id/concept-schema/f4981a92-8639-4da4-b1e3-0e1371feaa81'

class ConvertGovernmentDomains
  def self.initialize ()  
    abbreviations_to_label = Configuration::Files.government_domains.map { |row| 
      [row[0].downcase, row[1]]
    } .to_h
    
    abbreviations_to_label_sparql = abbreviations_to_label.map { |abbr, label|
      "(#{abbr.sparql_escape} #{label.sparql_escape})"
    } .join " "

    query = %{
      PREFIX skos: <http://www.w3.org/2004/02/skos/core#>

      SELECT ?abbreviation ?uri
      WHERE {
        GRAPH <http://mu.semte.ch/graphs/public> {
          VALUES (?abbreviation ?label_in) {
            #{ abbreviations_to_label_sparql }
          }

          OPTIONAL {
            ?uri a skos:Concept .
            ?uri skos:topConceptOf #{ GOVERNMENT_DOMAIN_CONCEPT_SCHEME_URI.sparql_escape } .
            ?uri skos:prefLabel ?label .
          }

          FILTER (
              (REPLACE(LCASE(REPLACE(REPLACE(?label,    #{ '[^\w\s]'.sparql_escape }, ""), #{ '\s+'.sparql_escape }, " ")), " en ", " "))
            = (REPLACE(LCASE(REPLACE(REPLACE(?label_in, #{ '[^\w\s]'.sparql_escape }, ""), #{ '\s+'.sparql_escape }, " ")), " en ", " "))
          )
        }
      }
    }

    triples = LinkedDB.query query
    @abbreviations_to_uri = triples.map { |tri| [tri[:abbreviation].value, tri[:uri]] } .to_h
    missing_government_domains = abbreviations_to_label.select { |key, value| !@abbreviations_to_uri[key]}
    if not missing_government_domains.empty?
      if Configuration::Environment.safe
        raise StandardError.new "Government domains could not be found: #{missing_government_domains}"
      end
    end
  end
  initialize

  # @return [Array] always returns an array (empty if no results)
  def self.convert rec
    beleidsdomein = rec.beleidsdomein
    
    return [] if beleidsdomein.nil?

    beleidsdomeinen = beleidsdomein.split '/'
    beleidsdomeinen.each { |d| d.strip!; d.downcase! }

    return beleidsdomeinen.flat_map do |d|
      uri = @abbreviations_to_uri[d]
      if uri.nil?
        $errors_csv << [rec.dossiernummer, "government-domain", "not-found", d]
        next []
      end

      next uri
    end
  end
end
