require_relative '../convert_reference_document.rb'

records = AccessDB.records

$errors_csv = CSV.open('./reference-documents-not-found.csv', mode='a+', encoding: 'utf-8')

i = 0
records.each do |rec|
  next if !rec.datum && !rec.opdracht_formeel_ontvangen

  ConvertReferenceDocument.convert(rec)
end

$errors_csv.close
