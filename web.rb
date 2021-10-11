require_relative './conversion.rb'

get '/ingest' do
  run()
  
  status 200
end