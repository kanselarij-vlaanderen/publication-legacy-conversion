require 'linkeddata'

module LinkedDB

  def self.initialize
    options = {}
    #if ENV['MU_SPARQL_TIMEOUT']
      options[:read_timeout] = 10_000 # ENV['MU_SPARQL_TIMEOUT'].to_i
    #end
    puts options
    @sparql_client = SinatraTemplate::SPARQL::Client.new(ENV['MU_SPARQL_ENDPOINT'], options)
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

  def self.sparql_escape_datetime dateTime
    # no xsd:dateTime typing: SELECTs failed due to not all dates having this
    '"' + dateTime.xmlschema + '"'
  end
end