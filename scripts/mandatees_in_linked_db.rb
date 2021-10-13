def sparql_escape_string string
  '"""' + string.gsub(/[\\"']/) { |s| '\\' + s } + '"""'
end

mandatees_corrections_path = File.join(__dir__, '../configuration/mandatees-corrections.csv')
query_mandatees = QueryMandatees.new mandatees_corrections_path

records = AccessDB::records()

$errors_csv = CSV.open('./mandatees-not-found.csv', mode='wb')

i = 0
records.each do |rec|
  next if !rec.datum && !rec.opdracht_formeel_ontvangen
  
  next if

  query_mandatees.query(rec)

end

$errors_csv.close
