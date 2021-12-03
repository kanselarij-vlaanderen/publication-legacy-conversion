module Files
  def self.regulation_types_keys
    path = File.join(__dir__, "configuration/regulation-types-keys.csv")
    # relative path does not work in Docker container because of different working directory
    return CSV.open path, "rt", encoding: "UTF-8"
  end

  def self.regulation_types_uris
    path = File.join(__dir__, "configuration/regulation-types-uris.csv")
    # relative path does not work in Docker container because of different working directory
    return CSV.open path, "rt", encoding: "UTF-8"
  end
end