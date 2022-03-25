module ConvertGovernmentDomains
  def self.initialize
    setup_mapping
    @ignore_set = setup_ignore_set
  end

  def self.setup_mapping
    mapping_info_csv = Configuration::Files.government_domains
    @mapping_info = mapping_info_csv.map { |row|
      {
        abbr: row[0].strip.downcase,
        label: row[1].strip,
        uri: RDF::URI(row[2].strip)
      }
    }
    @mapping = @mapping_info.map { |row|
      [row[:abbr], row[:uri]]
    } .to_h
  end

  def self.setup_ignore_set
    ignore_csv = Configuration::Files.government_domains_ignore
    ignore_list = ignore_csv.to_a.flatten
    Set.new ignore_list
  end

  def self.validate publication_records
    errors_mapping = validate_mapping @mapping_info
    errors_accessdb = validate_records publication_records
    Array.new.concat(errors_mapping, errors_accessdb)
  end

  # @param [Enumerator::Lazy] publication_records 
  def self.validate_mapping mapping_info
    validation_state = mapping_info.map do |csv_entry|
      query = build_query csv_entry[:uri]
      records = LinkedDB.query query
      records = records.map { |r| { uri: r[:uri], label: r[:label].value } }

      {
        entry: csv_entry,
        records: records,
      }
    end

    export_mapping validation_state

    validation_state.each do |entry_state| 
      if entry_state[:records].empty?
        entry_state[:error] = "not in Kaleidos"
      elsif entry_state[:records].length > 1
        entry_state[:error] = "multiple in Kaleidos"
      else
        label_csv = entry_state[:entry][:label]
        label_kaleidos_db = entry_state[:records].first[:label]
        if !are_labels_equal(label_csv, label_kaleidos_db)
          entry_state[:error] = "different in Kaleidos"
        end
      end
    end

    errors = validation_state.select { |r| r[:error] }
    errors.map { |r| "beleidsdomein: #{r[:error]}: #{r[:entry][:label]}" }
  end

  # @param [Enumerator] publication_records 
  def self.validate_records publication_records
    # to_a: avoid lazy enumerator
    beleidsdomeinen = publication_records.flat_map { |r| prepare r }.uniq.to_a
    Mu.log.info beleidsdomeinen.to_s
    missing_beleidsdomeinen = beleidsdomeinen.select do |domein|
      not_found = !(@mapping.include? domein)
      required = !(@ignore_set === domein)
      Mu.log.info domein + ':' + (not_found && required).to_s
      not_found && required
    end
    
    missing_beleidsdomeinen.map { |it| "beleidsdomein: not found in AccessDB: #{it}" }
  end

  def self.export_mapping validation_state
    Configuration::Output.government_domains do |csv|
      validation_state.each do |entry_state|
        csv << [entry_state[:entry][:label], entry_state[:records].first[:label]]
      end
    end
  end

  def self.build_query uri
    query = %{
      PREFIX skos: <http://www.w3.org/2004/02/skos/core#>

      SELECT ?uri ?label
      WHERE {
        GRAPH <http://mu.semte.ch/graphs/public> {
          BIND (#{ uri.sparql_escape } AS ?uri)

          ?uri a skos:Concept .
          ?uri skos:topConceptOf <http://themis.vlaanderen.be/id/concept-schema/f4981a92-8639-4da4-b1e3-0e1371feaa81> . # Beleidsdomeinen
          ?uri skos:prefLabel ?label .
        }
      }
    }
  end

  def self.prepare rec
    beleidsdomein = rec.beleidsdomein
    
    return [] if beleidsdomein.nil?

    beleidsdomeinen = beleidsdomein.split '/'
    beleidsdomeinen.map { |d| d.strip.downcase }
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

  private
  # @param [String] label1
  # @param [String] label2
  def self.are_labels_equal label1, label2
    label1 = cleanup_label label1
    label2 = cleanup_label label2
    return label1 == label2
  end

  def self.cleanup_label label
    label_copy = +label.clone
    label_copy.downcase!
    label_copy.gsub! ' en ', ' '
    label_copy.gsub! '&', ' '
    label_copy.gsub! ' ', ''
    return label_copy
  end

  initialize
end
