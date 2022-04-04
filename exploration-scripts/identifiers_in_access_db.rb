recs = AccessDB.records()
$errors_csv = CSV.open "/data/output/identifiers_in_access_db.csv", mode="w", encoding: "UTF-8"

suffixes = Set.new
recs.each { |r|
    dossiernummer = r.dossiernummer
    if !dossiernummer
        $errors_csv << ['no-dossiernummer']
    end

    identifier_match = r.dossiernummer.match '(?<number>\d+)[-/]?(?<version>.+)?'
    if identifier_match.nil?
        $errors_csv << ['irregular', r.dossiernummer]
    else
        local_id = Integer identifier_match[:number]
        version_id = identifier_match[:version]&.strip
        version_id = nil if version_id&.empty?
        
    
        suffixes << version_id if version_id
    end
}

(suffixes.to_a.sort_by &:downcase).each { |x|
    $errors_csv << [x]
}

$errors_csv.flush