module ConvertGovernmentDomainsFullName
  def self.initialize
    @mapping = setup_mapping
  end

  def self.setup_mapping
    Configuration::Files.government_domains_full_name do |csv|
      mapping_raw = csv.to_h
      mapping_raw.map { |abbr, full_name|
        [abbr.strip.downcase, full_name.strip]
      } .to_h
    end
  end

  def self.validate publication_records
    validate_entries publication_records
  end

  def self.validate_entries publication_records
    beleidsdomein_accdb_list = publication_records.flat_map { |r| prepare r }.uniq
    not_found = beleidsdomein_accdb_list.select do |domein|
      not_found = !(@mapping.include? domein)
      required = !(@ignore_set === domein)
      next not_found && required
    end
    if !not_found.empty?
      raise StandardError.new "Unknown govenment domains: #{ not_found.join "," }"
    end
  end

  def self.prepare rec
    beleidsdomein_field_accdb = rec.beleidsdomein
    
    return [] if beleidsdomein_field_accdb.nil?

    beleidsdomein_list_accdb = beleidsdomein_field_accdb.split '/'
    return beleidsdomein_list_accdb.map { |d| d.strip.downcase }
  end

  # @return [Array] always returns an array (empty if no results)
  def self.convert rec
    beleidsdomein_list_accdb = prepare rec

    return beleidsdomein_list_accdb.filter_map { |beleidsdomein_accdb|
      convert_entry beleidsdomein_accdb
    }
  end

  def self.convert_entry beleidsdomein_accdb
    full_name = @mapping[beleidsdomein_accdb]
    if full_name.nil?
      $errors_csv << [rec.dossiernummer, "government-domain", "not-found", d]
      return
    end

    return full_name
  end

  initialize
end
