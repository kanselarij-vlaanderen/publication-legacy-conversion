module AccessDB
  FIELDS = {
    dossiernummer: { tag: 'dossiernummer' },
    opschrift: { tag:  'opschrift' },
    soort: { tag: 'soort' },
    datum: { tag: 'datum', type: :datetime } ,
    trefwoord: { tag: 'trefwoord' },
    bevoegde_ministers: { tag: 'bevoegde_x0020_minister_x0028_s_x0029_' },
    document_nr: { tag: 'document_x0020_nr' },
    aantal_bladzijden: { tag: 'aantal_x0020_blz' },
    opdrachtgever: { tag: 'opdrachtgever' },
    opdracht_formeel_ontvangen: { tag: 'opdracht_x0020_formeel_x0020_ontvangen', type: :datetime },
    wijze_van_publicatie: { tag: 'wijze_x0020_van_x0020_publicatie' },
    vertaling_aangevraagd: { tag: 'vertaling_x0020_aangevraagd', type: :datetime } ,
    limiet_vertaling: { tag: 'limiet_x0020_vertaling', type: :datetime } ,
    vertaling_ontvangen: { tag: 'vertaling_x0020_ontvangen', type: :datetime } ,
    drukproef_aangevraagd: { tag: 'drukproef_x0020_aangevraagd', type: :datetime } ,
    drukproef_ontvangen: { tag: 'drukproef_x0020_ontvangen', type: :datetime } ,
    naar_BS_voor_publicatie: { tag: 'naar_x0020_BS_x0020_voor_x0020_publicatie', type: :datetime } ,
    limiet_publicatie: { tag: 'limiet_x0020_publicatie', type: :datetime } ,
    gevraagde_publicatiedatum: { tag: 'gevraagde_x0020_publicatiedatum', type: :datetime } ,
    publicatiedatum: { tag: 'PUBLICATIEDATUM', type: :datetime },
    opmerkingen: { tag: 'opmerkingen' },
    werknummer_BS: { tag: 'werknummer_x0020_BS' },
    beleidsdomein: { tag: 'beleidsdomein' }
  }

  def self.initialize
    input_dir = ENV["INPUT_DIR"] || "/data/input"
    input_file = File.join(input_dir, "legacy_data.xml")
    @doc = Nokogiri::XML(File.open(input_file)) { |c| c.noblanks }
  end
  initialize

  def self.by_dossiernummer(dossiernummers)
    dossiernummers
      .lazy
      .map { |dossiernummer|
        @doc.xpath("//Dossieropvolging/dossiernummer[.=\"#{dossiernummer}\"]")[0].parent
      }
  end

  def self.nodes()
    return @doc.xpath('//Dossieropvolging')
  end

  def self.records(range = nil)
    records = @doc.xpath('//Dossieropvolging')

    if !range.nil?
      records = records[range]
    end
    
    records
      .lazy
      .map { |n| record(n) }
  end

  def self.record(node)
    Record.new node
  end
  
  def self.field(n, name)
    field = AccessDB::FIELDS[name]
    if !field
      raise "no field: #{name}"
    end
    field_nodes = n > field[:tag]
    if field_nodes.length === 0
      nil
    else
      field_node = field_nodes[0]
      text = field_node.content
      if field[:type] === :datetime
        DateTime.strptime(text, '%Y-%m-%dT%H:%M:%S')
      else
        text
      end
    end
  end

  class Record
    def initialize(record_node)
      @record_node = record_node
    end
  
    def method_missing name_sym
      AccessDB::field(@record_node, name_sym)
    end
  end
end