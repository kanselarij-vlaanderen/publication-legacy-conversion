$errors_csv = CSV.open('./government-domains-not-found.csv', mode='wb')

query_government_domains = QueryGovernmentDomains.new $errors_csv, './data/input/government-domains-abbreviations.csv'

# i = 0
# AccessDB::[]
#   .filter { |rec| i += 1; i % 20 == 0 }
#   .each do |rec|
#     next if rec.beleidsdomein.nil? || !rec.beleidsdomein.include?('/')
#     government_domains = query_government_domains.query rec
#     puts 'dossiernummer', rec.dossiernummer, government_domains
#   end


AccessDB::by_dossiernummer(['55282'])
  .each do |rec|
    puts rec.beleidsdomein
    next if rec.beleidsdomein.nil? || !rec.beleidsdomein.include?('/')
    government_domains = query_government_domains.query rec
    puts 'dossiernummer', rec.dossiernummer, government_domains
  end
