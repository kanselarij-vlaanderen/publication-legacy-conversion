MINISTERS_GRAPH = "http://mu.semte.ch/graphs/public"

module ConvertMandatees
  def self.initialize
    replacements = Configuration::Files.mandatees_corrections
    @replacements = replacements.to_h
  end
  initialize

  # @return [Array] always returns an array (empty if no results)
  def self.convert rec
    bevoegde_ministers = rec.bevoegde_ministers

    return [] if bevoegde_ministers.nil?

    dossier_date = get_dossier_date rec
    dossier_date_escaped = dossier_date.sparql_escape

    if bevoegde_ministers === "allen"
      query = %{
        SELECT ?mandateeUri ?title ?person WHERE {
          GRAPH <#{MINISTERS_GRAPH}> {
            ?mandateeUri a <http://data.vlaanderen.be/ns/mandaat#Mandataris> .
            FILTER STRSTARTS(STR(?mandateeUri), "http://themis.vlaanderen.be")

            # some mandatees are present twice in the database under two different URIs, one entry does not contain a title
            OPTIONAL { ?mandateeUri <http://purl.org/dc/terms/title> ?title . }

            ?mandateeUri <http://data.vlaanderen.be/ns/mandaat#start> ?start .
            OPTIONAL { ?mandateeUri <http://data.vlaanderen.be/ns/mandaat#einde> ?end . }
            FILTER (?start < #{dossier_date_escaped})
            FILTER (!BOUND(?end) || ?end > #{dossier_date_escaped})

            ?mandateeUri <http://data.vlaanderen.be/ns/mandaat#isBestuurlijkeAliasVan> ?person .
          }
        }
      }

      mandatees_results = LinkedDB.query(query)

      grouped_mandatees = mandatees_results.group_by { |it| it[:person] }
      mandatees = grouped_mandatees.flat_map { |k, mandatee_results|
        process_mandatee_results(rec, bevoegde_ministers, mandatee_results, query)
      }

      return mandatees
    else
      bevoegde_ministers = bevoegde_ministers.split('/')
        .map(&:strip).map(&:downcase)
        .map { |minister_accdb| @replacements.fetch minister_accdb, minister_accdb }

      mandatees = bevoegde_ministers.flat_map do |minister_accdb|
        minister_escaped = minister_accdb.sparql_escape

        query = %{
          SELECT ?mandateeUri ?title
          WHERE {
            GRAPH <#{MINISTERS_GRAPH}>
            {
              ?mandateeUri a <http://data.vlaanderen.be/ns/mandaat#Mandataris> .
              FILTER STRSTARTS(STR(?mandateeUri), "http://themis.vlaanderen.be")

              # some mandatees are present twice in the database under two different URIs, one entry does not contain a title
              OPTIONAL { ?mandateeUri <http://purl.org/dc/terms/title> ?title . }

              ?mandateeUri <http://data.vlaanderen.be/ns/mandaat#start> ?start .
              OPTIONAL { ?mandateeUri <http://data.vlaanderen.be/ns/mandaat#einde> ?end . }
              FILTER (?start <= #{dossier_date_escaped})
              FILTER (!BOUND(?end) || ?end >= #{dossier_date_escaped})

              ?mandateeUri <http://data.vlaanderen.be/ns/mandaat#isBestuurlijkeAliasVan> ?person .
              ?person <http://xmlns.com/foaf/0.1/familyName> ?name .
              FILTER (CONTAINS(LCASE(STR(?name)), #{minister_escaped}))
            }
          }
        }

        mandatees_results = LinkedDB::query(query)

        mandatees = process_mandatee_results(rec, minister_accdb, mandatees_results.to_a, query)
        mandatees
      end

      return mandatees
    end
  end

  private
  def self.process_mandatee_results rec, minister_accdb, mandatees_results, query
    dossier_date = get_dossier_date rec

    if mandatees_results.length == 0
      $errors_csv << [rec.dossiernummer, 'mandataris', 'not-found', 'used:', nil, 'query params: mandataris, dossier datum', minister_accdb, dossier_date, query]
      return []
    end

    mandatees_results_title = mandatees_results.select { |r| r[:title]&.value }
    if mandatees_results_title.length >= 1
      mandatee_result = mandatees_results_title.first
      if mandatees_results_title.length > 1
        $errors_csv << [rec.dossiernummer, 'mandataris', 'found-multiple', 'used:', mandatee_result[:mandateeUri].value, 'query params: mandataris, dossier datum', minister_accdb, dossier_date, query]
      end
    else
      mandatee_result = mandatees_results.first
      if mandatees_results.length > 1
        $errors_csv << [rec.dossiernummer, 'mandataris', 'found-multiple', 'used:', mandatee_result[:mandateeUri].value, 'query params: mandataris, dossier datum', minister_accdb, dossier_date, query]
      end
    end

    return [mandatee_result[:mandateeUri]]
  end
end
