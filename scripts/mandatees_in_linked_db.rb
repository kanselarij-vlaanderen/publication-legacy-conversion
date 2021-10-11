def sparql_escape_string string
  '"""' + string.gsub(/[\\"']/) { |s| '\\' + s } + '"""'
end

query_mandatees = QueryMandatees.new './data/input/mandatees-corrections.csv'

records = AccessDB::records()

$errors_csv = CSV.open('./mandatees-not-found.csv', mode='wb')

i = 0
records.each do |rec|
  next if !rec.datum && !rec.opdracht_formeel_ontvangen
  
  next if

  query_mandatees.query(rec)

end

$errors_csv.close
