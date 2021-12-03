keys = AccessDB::FIELDS.keys
CSV.open('./records.csv', 'wt', encoding: 'UTF-8') do |csv|
  csv << keys
  AccessDB.nodes
    .each do |r|
          
    values = keys.map { |k| AccessDB::field(r, k) }

    csv << values
  end
end