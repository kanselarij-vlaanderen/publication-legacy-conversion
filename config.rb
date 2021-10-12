module Config
  ACCESS_DB_EXPORT = ENV["INPUT_FILE"] || "/data/input/legacy_data.xml"
  MANDATEES_CORRECTION_PATH = File.join(__dir__, "configuration/mandatees-corrections.csv")
end