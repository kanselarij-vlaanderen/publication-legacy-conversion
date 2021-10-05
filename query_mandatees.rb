class QueryMandatees
  def initialize corrections_file_path
    replacements = CSV.read(corrections_file_path)
    @replacements = replacements.to_h
  end

  def query rec
    bevoegde_ministers = rec.bevoegde_ministers
  
    return [] if bevoegde_ministers.nil?
  
    dossier_date = rec.datum || rec.opdracht_formeel_ontvangen
    dossier_date = DateTime.strptime(dossier_date, '%Y-%m-%dT%H:%M:%S')
    dossier_date_escaped = dossier_date.sparql_escape
  
    if bevoegde_ministers === "allen"
      query = %{
        SELECT ?mandateeUri WHERE {
          GRAPH <http://mu.semte.ch/graphs/ministers> {
            ?mandateeUri a <http://data.vlaanderen.be/ns/mandaat#Mandataris> ;
                        <http://data.vlaanderen.be/ns/mandaat#start> ?start .
            OPTIONAL { ?mandateeUri <http://data.vlaanderen.be/ns/mandaat#einde> ?end .}
            FILTER ( ?start < #{dossier_date_escaped})
            FILTER ( !bound(?end) || ?end > #{dossier_date_escaped})
          }
        }
      }
  
      mandatees_results = LinkedDB.query(query)
  
      if mandatees_results.length == 0
        $errors_csv << [rec.dossiernummer, "mandatee", "not-found", "allen", dossier_date, rec.opschrift]
      end

      mandatees = mandatees_results.map { |mandatee| mandatee[:mandateeUri] }
      return mandatees
    else
      bevoegde_ministers = bevoegde_ministers.split('/')
        .map(&:strip).map(&:downcase)
        .map { |minister| @replacements.fetch minister, minister }
  
      mandatees = bevoegde_ministers.flat_map do |minister|
        minister_escaped = sparql_escape_string(minister)
  
        query = %{
          PREFIX mandaat: <http://data.vlaanderen.be/ns/mandaat#>
          PREFIX foaf: <http://xmlns.com/foaf/0.1/> 
          PREFIX dct: <http://purl.org/dc/terms/>
  
          SELECT ?mandateeUri
          WHERE {
              GRAPH <http://mu.semte.ch/graphs/ministers>
              {
                ?mandateeUri a mandaat:Mandataris .
            
                ?mandateeUri mandaat:isBestuurlijkeAliasVan ?person .
                ?mandateeUri mandaat:start ?start .
                OPTIONAL { ?mandateeUri mandaat:einde ?end . }
                ?person foaf:familyName ?name .
                # some mandatees are present twice in the database under two different URIs, one entry does not contain a title
                ?mandateeUri dct:title ?title .
                FILTER (contains(lcase(str(?name)), #{minister_escaped}))
                FILTER (?start <= #{dossier_date_escaped})
                FILTER (!bound(?end) || ?end >= #{dossier_date_escaped})
            }
          }
        }
  
        mandatees_results = LinkedDB::query(query)
        
        if mandatees_results.length == 0
          $errors_csv << [rec.dossiernummer, "mandatee", "not-found", minister, dossier_date, rec.opschrift]
          next []
        elsif mandatees_results.length > 1
          $errors_csv << [rec.dossiernummer, "mandatee", "found-multiple", minister, dossier_date, rec.opschrift]
        end
        
        mandatee_result = mandatees_results[0]
        next [mandatee_result[:mandateeUri]]
      end

      return mandatees
    end
  end
end
