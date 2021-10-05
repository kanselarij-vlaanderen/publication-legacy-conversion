require 'set'

input_file = "data/input/legacy_data.xml"
doc = Nokogiri::XML(File.open(input_file)) { |c| c.noblanks }

access_fields = Set.new
doc.xpath('//Dossieropvolging').each do |record_node|
  record_node
    .xpath('*')
    .each do |field_node|
      field_name = field_node.name
      var = AccessDB::FIELDS.value? field_name
      if !var
        access_fields << field_name
      end
    end
end

CSV.open('./fields.csv', 'wb') do |csv|
  access_fields.each { |field| csv << [field] }
end