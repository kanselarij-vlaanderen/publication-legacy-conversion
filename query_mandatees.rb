class QueryMandatees
  def initialize corrections_file_path
    replacements = CSV.read corrections_file_path,  'rt', encoding: 'UTF-8' # otherwise Ruby 2.5 assumes ASCII
    @replacements = replacements.to_h
  end

  def query rec
    bevoegde_ministers = rec.bevoegde_ministers
  
    return [] if bevoegde_ministers.nil?
  
    dossier_date = get_dossier_date rec
    dossier_date_escaped = dossier_date.sparql_escape
  
    if bevoegde_ministers === "allen"
      query = %{
        SELECT ?mandateeUri ?title ?person WHERE {
          GRAPH <http://mu.semte.ch/graphs/ministers> {
            ?mandateeUri <http://data.vlaanderen.be/ns/mandaat#isBestuurlijkeAliasVan> ?person .
            ?mandateeUri a <http://data.vlaanderen.be/ns/mandaat#Mandataris> ;
                        <http://data.vlaanderen.be/ns/mandaat#start> ?start .
            OPTIONAL { ?mandateeUri <http://data.vlaanderen.be/ns/mandaat#einde> ?end .}
            OPTIONAL { ?mandateeUri <http://purl.org/dc/terms/title> ?title . }
            FILTER ( ?start < #{dossier_date_escaped})
            FILTER ( !bound(?end) || ?end > #{dossier_date_escaped})
          }
        }
      }
  
      mandatees_results = LinkedDB.query(query)
  
      mandatees = process_mandatee_results rec, bevoegde_ministers, mandatees_results
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
  
          SELECT ?mandateeUri ?title
          WHERE {
              GRAPH <http://mu.semte.ch/graphs/ministers>
              {
                ?mandateeUri a mandaat:Mandataris .
            
                ?mandateeUri mandaat:isBestuurlijkeAliasVan ?person .
                ?mandateeUri mandaat:start ?start .
                OPTIONAL { ?mandateeUri mandaat:einde ?end . }
                ?person foaf:familyName ?name .
                # some mandatees are present twice in the database under two different URIs, one entry does not contain a title
                OPTIONAL { ?mandateeUri dct:title ?title . }
                FILTER (contains(lcase(str(?name)), #{minister_escaped}))
                FILTER (?start <= #{dossier_date_escaped})
                FILTER (!bound(?end) || ?end >= #{dossier_date_escaped})
            }
          }
        }
  
        mandatees_results = LinkedDB::query(query)
        
        mandatees = process_mandatee_results rec, minister, mandatees_results
        return mandatees
      end

      return mandatees
    end
  end

  private
  def process_mandatee_results rec, minister, mandatees_results
    dossier_date = get_dossier_date rec

    if mandatees_results.length == 0
      $errors_csv << [rec.dossiernummer, "mandatee", "not-found", minister, dossier_date]
      return []
    end

    mandatees_results_title = mandatees_results.dup.filter { |r| r[:title]&.value } # dup: filter modifies the solutionset
    if mandatees_results_title.length >= 1
      mandatee_result = mandatees_results_title.first
      if mandatees_results.length >= 1
        $errors_csv << [rec.dossiernummer, "mandatee", "found-multiple", minister, dossier_date, mandatee_result[:mandateeUri].value]
      end  
    else
      mandatee_result = mandatees_results.first
      if mandatees_results.length > 1
        $errors_csv << [rec.dossiernummer, "mandatee", "found-multiple", minister, dossier_date, mandatee_result[:mandateeUri].value]
      end
    end

    return [mandatee_result[:mandateeUri]]
  end
end