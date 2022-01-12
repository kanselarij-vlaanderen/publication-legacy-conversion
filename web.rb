require_relative './conversion.rb'

post '/ingest' do
  range = params['range']&.split(',')&.map { |s| s.to_i }
  take = params['take']&.to_i
  if range
    records = AccessDB.nodes[(range[0]..range[1])]
  elsif take
    records = AccessDB.nodes.select.with_index { |_, i| i % take === 0 }
  end

  run(records)

  status 200
end
