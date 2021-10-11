require_relative '../query_reference_document.rb'

query_reference_document = QueryReferenceDocument.new

records = AccessDB.records

$errors_csv = CSV.open('./reference-documents-not-found.csv', mode='wt', encoding: 'utf-8')

i = 0
records.each do |rec|
  next if !rec.datum && !rec.opdracht_formeel_ontvangen

  query_reference_document.query(rec)
end

$errors_csv.close
