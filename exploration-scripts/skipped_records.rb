def no v
  (v.nil? || v.empty?)
end

CSV.open('./no-data.csv', 'wb') do |csv|
  AccessDB.records()
  .each do |r|
    
    skipped_info = no(r.opschrift) && !(r.datum) && no(r.document_nr)
    skipped_date = (!r.datum && !r.opdracht_formeel_ontvangen)
    
    csv << [r.dossiernummer, skipped_info, skipped_date] if skipped_info || skipped_date
  end
end