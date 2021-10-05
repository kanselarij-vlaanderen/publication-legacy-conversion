recs = AccessDB::records

csv = CSV.open './documentnummers-datums.csv', 'wb'

i = 0
recs.each do |r|
  i+=1
  if i % 500 != 0
    next
  end
  
  document_nr = r.document_nr
  next if document_nr.nil?

  titleParts = document_nr.match('VR/(?<year>\d{2})/(?<day>[0-9]{2})\.(?<month>[0-9]{2})/(?<number>\d{4})')

  if titleParts.nil?
    csv << [r.dossiernummer, 'document-number', 'not-parsed', document_nr]
    next
  end

  puts document_nr

  year = titleParts[:year]
  year4 = year.to_i < 30 ? "20" + year : "19" + year

  docTitle = "VR #{year4} #{titleParts[:day]}#{titleParts[:month]} DOC.#{titleParts[:number]}"
  medTitle = "VR #{year4} #{titleParts[:day]}#{titleParts[:month]} MED.#{titleParts[:number]}"

  query = %{
    SELECT ?stukUri WHERE {
      GRAPH <http://mu.semte.ch/graphs/organizations/kanselarij> {
        ?stukUri a <https://data.vlaanderen.be/ns/dossier#Stuk> ;
        <http://purl.org/dc/terms/title> ?title .
        FILTER (strstarts(str(?title), ?titleValue) )
    
        VALUES ?titleValue  { 
          '#{docTitle}'
          '#{medTitle}'
        }
      }
    }
  }

  triples = LinkedDB.query(query)

  triples.each do |tri|
    query = %{
      PREFIX prov: <http://www.w3.org/ns/prov#>
      PREFIX besluit: <http://data.vlaanderen.be/ns/besluit#>
      PREFIX dct: <http://purl.org/dc/terms/>
      PREFIX dossier: <https://data.omgeving.vlaanderen.be/ns/dossier#>
      PREFIX besluitvorming: <http://data.vlaanderen.be/ns/besluitvorming#>
      SELECT
        ?title
        ?agendaDate ?agendaDateCreated
        ?treatmentDate ?treatmentDateCreated
        ?meetingDateGeplandeStart ?meetingDateStart
        ?fileDateCreated WHERE {
        GRAPH <http://mu.semte.ch/graphs/organizations/kanselarij> {
          ?treatmentUri a <http://data.vlaanderen.be/ns/besluit#BehandelingVanAgendapunt> ;              <http://data.vlaanderen.be/ns/besluitvorming#heeftOnderwerp> ?agendaItem .
          ?agendaItem <http://data.vlaanderen.be/ns/besluitvorming#geagendeerdStuk> ?stukUri .
          ?caseUri a <https://data.vlaanderen.be/ns/dossier#Dossier> ;
            <https://data.vlaanderen.be/ns/dossier#Dossier.bestaatUit> ?stukUri .
          ?stukUri a <https://data.vlaanderen.be/ns/dossier#Stuk> ;
            <http://purl.org/dc/terms/title> ?title .
          ?stukUri <http://mu.semte.ch/vocabularies/ext/file> ?file .
            ?file <http://purl.org/dc/terms/created> ?fileDateCreated .
                  
          ?agenda <http://purl.org/dc/terms/hasPart> ?agendaItem .
          OPTIONAL { ?agenda dct:issued ?agendaDate . }
          OPTIONAL { ?agenda dct:created ?agendaDateCreated }

          OPTIONAL { ?treatmentUri dossier:Activiteit.startdatum ?treatmentDate }
          OPTIONAL { ?treatmentUri dct:created ?treatmentDateCreated }

          ?agenda besluitvorming:isAgendaVoor ?meeting .
          OPTIONAL { ?meeting besluit:geplandeStart ?meetingDateGeplandeStart . }
          OPTIONAL { ?meeting prov:startedAtTime ?meetingDateStart . }
          
          VALUES ?stukUri  { 
            <#{tri[:stukUri]}>
          }
        }
      }
    }

    triples = LinkedDB.query(query)

    triples.each do |tri|
      puts "title #{tri[:fileDateCreated]}"
      # tri.each_binding do |name, value|
      #   puts name, value
      # end
    end
  end
  # puts 
  # csv << [r.dossiernummer, 'document-number', ]
end