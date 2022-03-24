# TODO: government domains data model is under consideration
module ConvertGovernmentDomains
  def self.initialize
    @mapping = setup_mapping
    @ignore_set = setup_ignore_set
  end

  def self.setup_mapping
    mapping_keys_csv = Configuration::Files.government_domains_keys.to_h
    mapping_uris_csv = Configuration::Files.government_domains_uris.to_h
    return mapping_keys_csv.map do |key, mapping_key|
      uri_str = mapping_uris_csv[mapping_key]
      uri = RDF::URI uri_str
      [key, uri]
    end .to_h
  end

  def self.setup_ignore_set
    ignore_csv = Configuration::Files.government_domains_ignore
    ignore_list = ignore_csv.to_a.flatten
    Set.new ignore_list
  end

  def self.validate publication_records
    validate_mapping @mapping
    validate_entries publication_records
  end

  # @param [Enumerator::Lazy] publication_records 
  def self.validate_mapping mapping
    records = query_mapping mapping
    
    export_mapping records

    not_found = records.select { |r| r[2].nil? }
    if not_found.any?
      not_found_keys = not_found.map { |r| r[0] }
      raise StandardError.new "Incorrect government domain mapping: #{ not_found_keys.join "," }"
    end
  end

  # @param [Enumerator::Lazy] publication_records 
  def self.validate_entries publication_records
    beleidsdomeinen = publication_records.flat_map { |r| prepare r }.uniq
    not_found = beleidsdomeinen.select do |domein|
      not_found = !(@mapping.include? domein)
      required = !(@ignore_set === domein)
      next not_found && required
    end
    
    if not_found.any?
      raise StandardError.new "Unknown govenment domains: #{ not_found.to_a.join "," }"
    end
  end

  def self.export_mapping records
    Configuration::Output.government_domains do |csv|
      
      records.each do |r|
        if r[2]
          label = r[2][:label]
        end
        csv << [r[0], r[1], label]
      end
    end
  end

  def self.query_mapping mapping
    uris = mapping.values.uniq
    uri_to_record = uris.map do |uri|
      record = query uri
      [uri, record]
    end .to_h

    return mapping.map do |k, uri|
      [k, uri, uri_to_record[uri]]
    end
  end

  def self.query uri
    query = %{
      PREFIX skos: <http://www.w3.org/2004/02/skos/core#>

      SELECT ?label
      WHERE {
        GRAPH <http://mu.semte.ch/graphs/public> {
          BIND (#{ uri.sparql_escape } AS ?uri)

          ?uri a skos:Concept .
          ?uri skos:topConceptOf <http://themis.vlaanderen.be/id/concept-schema/f4981a92-8639-4da4-b1e3-0e1371feaa81> . # Beleidsdomeinen
          ?uri skos:prefLabel ?label .
        }
      }
    }
    triples = LinkedDB.query query
    if triples.length > 1
      raise StandardError.new "Unexpected number of results for uri <#{uri}>"
    end

    if triples.first
      return { label: triples.first[:label].value }
    else
      return nil
    end

  end

  def self.prepare rec
    beleidsdomein = rec.beleidsdomein
    
    return [] if beleidsdomein.nil?

    beleidsdomeinen = beleidsdomein.split '/'
    beleidsdomeinen.each { |d| d.strip!; d.downcase! }
  end

  # @return [Array] always returns an array (empty if no results)
  def self.convert rec
    beleidsdomeinen = prepare rec

    return beleidsdomeinen.flat_map do |d|
      uri = @mapping[d]
      if uri.nil?
        $errors_csv << [rec.dossiernummer, "government-domain", "not-found", d]
        next []
      end

      next uri
    end
  end

  initialize
end
