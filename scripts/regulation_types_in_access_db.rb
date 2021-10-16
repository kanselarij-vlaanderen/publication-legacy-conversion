recs = AccessDB.records()

values = recs.flat_map { |r|
  value = r.soort
  next [] if value.nil?
  value.downcase!
  value.strip!
  [value]
}

values = values.group_by { |m| m }
values = values.map { |k, v| [k, v.length] }
values = values.sort_by { |m| m[0] }

CSV.open('./regulation-types.csv', 'wb') do |csv|
  values.each { |k, v| csv << [k, v] }
end