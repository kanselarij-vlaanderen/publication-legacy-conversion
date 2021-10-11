require 'linkeddata'

module LinkedDB
  def self.initialize
    @sparql_client = SinatraTemplate::Utils.sparql_client
  end
  initialize

  BASE_BACKOFF_SECONDS = 1
  def self.query(query)
    max_tries = 5
    (1..max_tries).each do |try|
      begin
        return @sparql_client.query query
      rescue Net::HTTP::Persistent::Error => x
        if try === max_tries
          raise x
        end
        time_to_sleep = BASE_BACKOFF_SECONDS * (try ** 2)
        log.info "HTTP error: retrying in #{time_to_sleep} seconds. Sleeping: zzz..."

        Kernel.sleep time_to_sleep_sec
      end
    end

  end

  def self.sparql_escape_string string
    # added new line support (missing in mu-ruby-template)
    '"""' + string.gsub(/[\\"']/) { |s| '\\' + s } + '"""'
  end
end