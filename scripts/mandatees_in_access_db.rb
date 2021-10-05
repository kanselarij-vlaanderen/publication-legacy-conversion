require_relative '../access_db.rb'

def report_mandatees()

  recs = AccessDB::records([:dossiernummer, :bevoegde_ministers])

  bevoegde_ministers = recs.flat_map { |r|
    bevoegde_ministers = r[:bevoegde_ministers]
    bevoegde_ministers = bevoegde_ministers.split('/')
    bevoegde_ministers.each { |m| 
      m.downcase!
      m.strip!
    }
  }

  bevoegde_ministers = bevoegde_ministers.group_by { |m| m }
  bevoegde_ministers = bevoegde_ministers.map { |k, v| [k, v.length] }
  bevoegde_ministers = bevoegde_ministers.sort_by { |m| m[0] }
  
  CSV.open('./ministers.csv', 'wb') do |csv|
    bevoegde_ministers.each { |m| csv << m }
  end
end

