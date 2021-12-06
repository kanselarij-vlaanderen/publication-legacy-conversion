module ConvertReferenceDocument
  def self.initialize
    pattern = 'VR/(?<year>\d{2})/(?<day>[0-9]{2})\.(?<month>[0-9]{2})(?<type>med|doc|dec)?[/.-]? ?(?<number>\d{4})(?<version>[a-z]{1,3})?'
    @regexp = Regexp.new pattern, true
  end
  initialize

  def self.prepare rec
    document_number = rec.document_nr

    if document_number.nil?
      return
    end

    title_parts = @regexp.match(document_number)

    if title_parts.nil?
      $errors_csv << [rec.dossiernummer, 'reference-document', 'could-not-parse', document_number]
      return
    end

    year = title_parts[:year]
    year4 = year.to_i < 30 ? "20" + year : "19" + year
  
    type = title_parts[:type]
    if type
      type = [type.upcase]
    else
      type = ["DOC", "MED", "DEC"]
    end

    return type.map { |t| [t, "VR #{year4} #{title_parts[:day]}#{title_parts[:month]} #{t}.#{title_parts[:number]}"] }
  end

  def self.convert rec
    candidate_titles = prepare rec

    if candidate_titles.nil?
      return
    end

    candidate_titles_escaped = candidate_titles.map { |t|
      pair = [t[0].sparql_escape, t[1].sparql_escape].join(' ')
      next "(#{ pair })"
    }.join(' ')

    documents_query = %{
      SELECT ?stukUri ?type
      WHERE {
        GRAPH <http://mu.semte.ch/graphs/organizations/kanselarij> {
          ?stukUri a <https://data.vlaanderen.be/ns/dossier#Stuk> ;
            <http://purl.org/dc/terms/title> ?title .

          FILTER (strstarts(str(?title), ?titleValue) )
          VALUES (?type ?titleValue)  { #{ candidate_titles_escaped } }
        }
      }
    }

    document_results = LinkedDB.query(documents_query)

    if document_results.length === 0
      candidate_titles = candidate_titles.map! { |it| it[1] }
      $errors_csv << [rec.dossiernummer, 'reference-document', 'not-found', candidate_titles]
      return
    end

    document_uris = document_results.map { |r| r[:stukUri] }
    document_uris_escaped = document_uris.map { |it| it.sparql_escape }.join(' ')

    case_query = %{
      SELECT ?stukUri ?caseUri ?treatmentUri
      WHERE {
        GRAPH <http://mu.semte.ch/graphs/organizations/kanselarij> {
          ?stukUri a <https://data.vlaanderen.be/ns/dossier#Stuk> .
          ?caseUri a <https://data.vlaanderen.be/ns/dossier#Dossier> ;
            <https://data.vlaanderen.be/ns/dossier#Dossier.bestaatUit> ?stukUri .
          ?agendaItem <http://data.vlaanderen.be/ns/besluitvorming#geagendeerdStuk> ?stukUri .
          ?treatmentUri a <http://data.vlaanderen.be/ns/besluit#BehandelingVanAgendapunt> ;
              <http://data.vlaanderen.be/ns/besluitvorming#heeftOnderwerp> ?agendaItem .
          VALUES ?stukUri { #{ document_uris_escaped } }
        }
      }
    }

    case_results = LinkedDB.query(case_query)
    case_uris = case_results.map { |r| r[:caseUri] }
    case_uris.uniq!
    if case_uris.length === 0
      $errors_csv << [rec.dossiernummer, 'case', 'not-found', document_uris.map { |u| u.value }]
      return
    elsif case_uris.length >= 1
      case_result = case_results[0]
      if case_results.length > 1
        $errors_csv << [rec.dossiernummer, 'case', 'found-multiple', case_result[:caseUri].value, document_uris.map { |u| u.value }]
      end
    end
    
    reference_document_uri = case_result[:stukUri]
    case_uri = case_result[:caseUri]
    treatment_uri = case_result[:treatmentUri]

    return reference_document_uri, case_uri, treatment_uri
  end
end

