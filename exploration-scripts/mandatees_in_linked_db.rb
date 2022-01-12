def sparql_escape_string string
  '"""' + string.gsub(/[\\"']/) { |s| '\\' + s } + '"""'
end

records = AccessDB::records()

$errors_csv = CSV.open('./mandatees-not-found.csv', mode='wb')

i = 0
records.each do |rec|
  next if !rec.datum && !rec.opdracht_formeel_ontvangen
  
  ConvertMandatees.convert(rec)

end

$errors_csv.close
