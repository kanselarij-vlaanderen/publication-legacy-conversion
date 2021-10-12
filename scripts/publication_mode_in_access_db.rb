recs = AccessDB.records()

values = recs.flat_map { |r|
  value = r.wijze_van_publicatie
  m.downcase!
  m.strip!
}

values = values.group_by { |m| m }
values = values.map { |k, v| [k, v.length] }
values = values.sort_by { |m| m[0] }

CSV.open('./modes.csv', 'wb') do |csv|
  report.each { |k, v| csv << [k, v] }
end