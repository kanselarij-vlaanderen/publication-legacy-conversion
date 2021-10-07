require 'linkeddata'

module LinkedDB

  def self.initialize
    @sparql_client = SinatraTemplate::Utils.sparql_client
  end
  initialize

  def self.query(query)
    #log.info "Executing query: #{query}"
    @sparql_client.query query
  end

  def self.sparql_escape_string string
    # added new line support (missing in mu-ruby-template)
    '"' + string.gsub(/[\\"']/) { |s| '\\' + s }.gsub(/\n/, '\n') + '"'
  end
end