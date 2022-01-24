require 'linkeddata'

class RDF::URI
  def sparql_escape
    "<#{self.to_s}>"
  end
end

module LinkedDB
  def self.initialize
    @sparql_client = Mu.sparql_client
  end
  initialize

  BASE_BACKOFF_SECONDS = 1
  def self.query(query)
    log.debug(query)

    max_tries = 5
    (1..max_tries).each do |try|
      begin
        return @sparql_client.query query
      rescue => x
        if try === max_tries
          raise x
        end
        time_to_sleep = BASE_BACKOFF_SECONDS * (try ** 2)
        log.info "HTTP error: retrying in #{time_to_sleep} seconds. Sleeping: zzz..."

        Kernel.sleep time_to_sleep
      end
    end

  end

  def self.sparql_escape_string string
    # added new line support (missing in mu-ruby-template)
    '"""' + string.gsub(/[\\"']/) { |s| '\\' + s } + '"""'
  end
end
