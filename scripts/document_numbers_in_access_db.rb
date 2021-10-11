csv = CSV.open('./document_numbers.csv', 'wb')
recs = AccessDB::records()

recs.each do |rec|
  if rec.document_nr.nil?
    next
  end


  pattern = 'VR/(?<year>\d{2})/(?<day>[0-9]{2})\.(?<month>[0-9]{2})(med|doc|dec)?[/\.-]? ?(?<number>\d{4})'
  regex = Regexp.new pattern, true
  title_parts = rec.document_nr.match(regex)
  
  csv << [rec.dossiernummer, rec.document_nr, !!title_parts]

end
