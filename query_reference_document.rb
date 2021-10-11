class QueryReferenceDocument
  def initialize
    pattern = 'VR/(?<year>\d{2})/(?<day>[0-9]{2})\.(?<month>[0-9]{2})(?<type>med|doc|dec)?[/.-]? ?(?<number>\d{4})(?<version>[a-z]{1,3})?'
    @regexp = Regexp.new pattern, true
  end

  def prepare rec
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

    type.map { |t| "VR #{year4} #{title_parts[:day]}#{title_parts[:month]} #{t}.#{title_parts[:number]}" }
    medTitle = "VR #{year4} #{title_parts[:day]}#{title_parts[:month]} MED.#{title_parts[:number]}"
    decTitle = "VR #{year4} #{title_parts[:day]}#{title_parts[:month]} DEC.#{title_parts[:number]}"

    return [docTitle, medTitle, decTitle]

  end

  def query rec

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
    
    type = ["DOC", "MED", "DEC"]
    candidate_titles = type.map { |t| [ t, "VR #{year4} #{title_parts[:day]}#{title_parts[:month]} #{t}.#{title_parts[:number]}" ] }
    
    # if candidate_titles.nil?
    #   return
    # end

    candidate_titles_escaped = candidate_titles.map { |t|
      "(#{[t[0].sparql_escape, LinkedDB.sparql_escape_string(t[1])].join(' ')})"
    }.join(' ')

    query = %{
      SELECT ?stukUri ?type
      WHERE {
        GRAPH <http://mu.semte.ch/graphs/organizations/kanselarij> {
          ?stukUri a <https://data.vlaanderen.be/ns/dossier#Stuk> ;
            <http://purl.org/dc/terms/title> ?title .
          FILTER (strstarts(str(?title), ?titleValue) )
          VALUES (?type ?titleValue)  { #{candidate_titles_escaped} }
        }
      }
    }

    results = LinkedDB.query(query)

    document_uris = results.map { |r| [r[:type], r[:stukUri]] }
    document_uris_escaped = document_uris.map { |uri| "<#{uri[1].to_s}>" }.join(' ')
    if document_uris.length === 0
      $errors_csv << [rec.dossiernummer, 'reference-document', 'not-found']
      return
    end

    query = %{
      SELECT ?stukUri ?caseUri ?treatmentUri
      WHERE {
        GRAPH <http://mu.semte.ch/graphs/organizations/kanselarij> {
          ?stukUri a <https://data.vlaanderen.be/ns/dossier#Stuk> .
          ?caseUri a <https://data.vlaanderen.be/ns/dossier#Dossier> ;
            <https://data.vlaanderen.be/ns/dossier#Dossier.bestaatUit> ?stukUri .
          VALUES ?stukUri { #{document_uris_escaped} }
        }
      }
    }

    document_results = LinkedDB.query(query)
    case_uris = document_results.map { |r| r[:caseUri] }
    case_uris.uniq!
    if case_uris.length === 0
      $errors_csv << [rec.dossiernummer, 'case', 'not-found', case_uris.map { |u| u.to_s }, document_uris.map { |u| u.to_s }]
    end
    if case_uris.length > 1
      $errors_csv << [rec.dossiernummer, 'case', 'found-multiple', case_uris.map { |u| u.to_s }, document_uris.map { |u| u.to_s }]
    end

    document_uris = results.map { |r| [r[:type], r[:stukUri]] }
    document_uris_escaped = document_uris.map { |uri| "<#{uri[1].to_s}>" }.join(' ')

    query = %{
      SELECT ?stukUri ?treatmentUri
      WHERE {
        GRAPH <http://mu.semte.ch/graphs/organizations/kanselarij> {
          ?stukUri a <https://data.vlaanderen.be/ns/dossier#Stuk> .
          ?agendaItem <http://data.vlaanderen.be/ns/besluitvorming#geagendeerdStuk> ?stukUri .
          ?treatmentUri a <http://data.vlaanderen.be/ns/besluit#BehandelingVanAgendapunt> ;
            <http://data.vlaanderen.be/ns/besluitvorming#heeftOnderwerp> ?agendaItem .

          VALUES ?stukUri  { #{ document_uris_escaped } }
        }
      }
    }

    document_results = LinkedDB.query(query)
    treatment_uris = document_results.map { |r| r[:treatmentUri] }
    treatment_uris.uniq!
    if treatment_uris.length === 0
      $errors_csv << [rec.dossiernummer, 'reference-documents', 'not-found', treatment_uris.map { |u| u.to_s }, document_uris.map { |u| u.to_s }]
    end
    if treatment_uris.length > 1
      $errors_csv << [rec.dossiernummer, 'reference-documents', 'found-multiple', treatment_uris.map { |u| u.to_s }, document_uris.map { |u| u.to_s }]
    end
    treatmentUri = document_results.map { |r| r[:treatmentUri] }.uniq!

    query = %{
      SELECT ?type ?stukUri ?title ?caseUri ?treatmentUri WHERE {
        GRAPH <#{KANSELARIJ_GRAPH}> {
           ?treatmentUri a <#{BESLUIT.BehandelingVanAgendapunt}> ;
                    <#{BESLUITVORMING.heeftOnderwerp}> ?agendaItem .
           ?agendaItem <#{BESLUITVORMING.geagendeerdStuk}> ?stukUri .
           ?caseUri a <#{DOSSIER.Dossier}> ;
                    <#{DOSSIER['Dossier.bestaatUit']}> ?stukUri .
           ?stukUri a <#{DOSSIER.Stuk}> ;
                    <#{DCT.title}> ?title .
         FILTER (strstarts(str(?title), ?titleValue) )
         VALUES (?type ?titleValue)  { #{ candidate_titles_escaped } }
        }
      } ORDER BY ?title
    }

    results = LinkedDB.query(query)
    
    case_uris2 = document_results.map { |r| r[:caseUri] }.uniq
    treatment_uris2 = document_results.map { |r| r[:treatmentUri] }.uniq

    $errors_csv << [
      rec.dossiernummer, "lengths", document_uris.length, 
      case_uris.length === case_uris2.length && treatment_uris.length === treatment_uris2.length,
      case_uris.length, case_uris2.length, treatment_uris.length, treatment_uris2.length]

    $errors_csv.flush
  end
end

