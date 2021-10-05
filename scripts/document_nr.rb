recs = AccessDB::records

csv = CSV.open './documentnummers-datums.csv', 'wb'

i = 0
recs.each do |r|
  i+=1
  if i % 1000 !== 0
    next
  end

  document_nr = r.document_nr
  next if document_nr.nil?

  titleParts = document_nr.match('VR/(?<year>\d{2})/(?<day>[0-9]{2})\.(?<month>[0-9]{2})/(?<number>\d{4})')

  if titleParts.nil?
    csv << [r.dossiernummer, 'document-number', 'not-parsed', document_nr]
    next
  end

  year = titleParts[:year]
  year4 = year.to_i < 30 ? "20" + year : "19" + year

  docTitle = "VR #{year4} #{titleParts[:day]}#{titleParts[:month]} DOC.#{titleParts[:number]}"
  medTitle = "VR #{year4} #{titleParts[:day]}#{titleParts[:month]} MED.#{titleParts[:number]}"

  query =  " SELECT ?stukUri ?caseUri ?treatmentUri WHERE {"
  query += "   GRAPH <#{KANSELARIJ_GRAPH}> {"
  query += "     ?treatmentUri a <#{BESLUIT.BehandelingVanAgendapunt}> ;"
  query += "              <#{BESLUITVORMING.heeftOnderwerp}> ?agendaItem ."
  query += "     ?agendaItem <#{BESLUITVORMING.geagendeerdStuk}> ?stukUri ."
  query += "     ?caseUri a <#{DOSSIER.Dossier}> ;"
  query += "              <#{DOSSIER['Dossier.bestaatUit']}> ?stukUri ."
  query += "     ?stukUri a <#{DOSSIER.Stuk}> ;"
  query += "              <#{DCT.title}> ?title ."
  query += "   FILTER (strstarts(str(?title), ?titleValue) )"
  query += "   VALUES ?titleValue  { '#{docTitle}' '#{medTitle}' }"
  query += "   }"
  query += " } ORDER BY ?title"

  results = LinkedDB.query(query)
  
  csv << [r.dossiernummer, results.length]
end