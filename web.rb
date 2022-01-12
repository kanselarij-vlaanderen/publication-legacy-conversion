require_relative './conversion.rb'

post '/ingest' do
  range = params['range']&.split(',')&.map { |s| s.to_i }
  if range
    records = AccessDB.nodes[(range[0]..range[1])]
  end

  run("/data/input/", "/data/output/", records)

  status 200
end
