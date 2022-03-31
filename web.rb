require_relative './conversion.rb'

post '/api' do
  range = params['range']&.split(',')&.map { |s| s.to_i }
  take = params['take']&.to_i
  dossiernummer_list = params['dossiernummer']&.split(',')
  actions = Set.new params['actions']&.split(',')
  if actions.empty?
    status 400
    return 'actions query parameter is required: specify validate and/or convert: ?actions=validate,convert'
  end

  if range
    records = AccessDB.nodes[(range[0]..range[1])]
  elsif take
    records = AccessDB.nodes.select.with_index { |_, i| i % take === 0 }
  elsif dossiernummer_list
    records = AccessDB.by_dossiernummer dossiernummer_list
  else
    records = AccessDB.nodes
  end


  run(records, actions)

  status 200
end
