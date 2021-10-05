records = AccessDB.records

beleidsdomeinen = records.flat_map do |rec|
  beleidsdomeinen = rec.beleidsdomein
  if beleidsdomeinen.nil?
    next []
  end

  beleidsdomeinen = beleidsdomeinen.split '/'
  beleidsdomeinen.each do |d|
    d.strip!
    d.downcase!
  end

  beleidsdomeinen
end

beleidsdomeinen = beleidsdomeinen.group_by { |d| d }
beleidsdomeinen = beleidsdomeinen.map { |k, v| [k, v.length] }
beleidsdomeinen = beleidsdomeinen.sort_by { |d| d[0] }

CSV.open('./beleidsdomeinen.csv', 'wb') do |csv|
  beleidsdomeinen.each { |d| csv << d }
end