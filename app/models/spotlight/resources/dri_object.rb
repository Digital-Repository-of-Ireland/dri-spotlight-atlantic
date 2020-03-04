module Spotlight
  module Resources
    ##
    # A PORO to construct a solr hash for a given Dri Object json
    class DriObject
      attr_reader :collection
      def initialize(attrs = {})
        @id = attrs[:id]
        @metadata = attrs[:metadata]
        @files = attrs[:files]
        @solr_hash = {}
      end

      def to_solr
        add_document_id
        add_depositing_institute
        add_label
        add_creator

        if metadata.key?('subject') && metadata['subject'].present?
          add_subject_facet
          add_theme_facet
          add_subtheme_facet
          add_type_facet
          add_oral_history_facet
          add_collection_facet

          if metadata['type'] != ['Collection']
            add_grantee_facet
            add_grant_facet
          end
        end

        add_temporal_coverage
        add_geographical_coverage
        add_metadata
        add_collection_id

        if metadata['type'] == ['Collection']
          add_subcollection_type
        else
          add_image_urls
        end

        solr_hash
      end

      def with_exhibit(e)
        @exhibit = e
      end

      def compound_id(id)
        Digest::MD5.hexdigest("#{exhibit.id}-#{id}")
      end

      private

      attr_reader :id, :exhibit, :metadata, :files, :solr_hash
      delegate :blacklight_config, to: :exhibit

      def add_creator
        solr_hash['readonly_creator_ssim'] = metadata['creator']
      end

      def add_depositing_institute
        if metadata.key?('institute')
          metadata['institute'].each do |institute|
            if institute['depositing'] == true
              solr_hash['readonly_depositing_institute_tesim'] = institute['name']
            end
          end
        end
      end

      def add_oral_history_facet
        solr_hash['readonly_oral_history_ssim'] = dri_object.oral_history
      end

      def add_subject_facet
        solr_hash['readonly_subject_ssim'] = metadata['subject']
      end

      def add_temporal_coverage
        return unless metadata.key?('temporal_coverage') && metadata['temporal_coverage'].present?
        solr_hash['readonly_temporal_coverage_ssim'] = dri_object.dcmi_name(metadata['temporal_coverage'])
      end

      def add_theme_facet
        themes = dri_object.themes
        return if themes.blank?
        solr_hash['readonly_theme_ssim'] = themes[0]
      end

      def add_subtheme_facet
        subthemes = dri_object.subthemes
        return if subthemes.blank?
        solr_hash['readonly_subtheme_ssim'] = subthemes[0]
      end

      def add_geographical_coverage
        return unless metadata.key?('geographical_coverage') && metadata['geographical_coverage'].present?
        solr_hash['readonly_geographical_coverage_ssim'] = dri_object.dcmi_name(metadata['geographical_coverage'])
      end

      def add_grantee_facet
        solr_hash['readonly_grantee_ssim'] = dri_object.grantee
      end

      def add_grant_facet
        solr_hash['readonly_grant_ssim'] = dri_object.grant
      end

      def add_type_facet
        solr_hash['readonly_type_ssim'] = metadata['type']
      end

      def add_document_id
        solr_hash['readonly_dri_id_ssim'] = id
        solr_hash[blacklight_config.document_model.unique_key.to_sym] = compound_id(id)
      end

      def add_collection_id
        if metadata.key?('isGovernedBy')
          solr_hash[collection_id_field] = [compound_id(metadata['isGovernedBy'])]
        end
      end

      def add_collection_facet
        return unless metadata.key?('subject') && metadata['subject'].present?
        solr_hash['readonly_collection_ssim'] = dri_object.collection
      end

      def add_subcollection_type
        unless metadata['type'] == ['Collection']
          solr_hash['readonly_subcollection_type_ssim'] = nil
          return
        end

        return unless metadata['ancestor_title'].present?

        root_title = metadata['ancestor_title'].last.downcase

        if root_title.include?("grant documentation")
          solr_hash['readonly_subcollection_type_ssim'] = if metadata['title'].first.start_with?("Grant")
                                                            'grant'
                                                          else
                                                            'grantee'
                                                          end
        elsif root_title.include?("oral histories")
          solr_hash['readonly_subcollection_type_ssim'] = 'oral'
        elsif root_title.include?("publications")
          solr_hash['readonly_subcollection_type_ssim'] = 'publications'
        end
      end

      def collection_id_field
        :collection_id_ssim
      end

      def add_image_urls
        solr_hash[tile_source_field] = image_urls
      end

      def add_label
        return unless title_field && metadata.key?('title')
        solr_hash[title_field] = metadata['title']
      end

      def add_metadata
        solr_hash.merge!(object_metadata)
        sidecar.update(data: sidecar.data.merge(object_metadata))

        sidecar.private! if metadata['type'] == ['Collection']
      end

      def object_metadata
        return {} unless metadata.present?
        item_metadata = dri_object.to_solr

        create_sidecars_for(*item_metadata.keys)

        item_metadata.each_with_object({}) do |(key, value), hash|
          next unless (field = exhibit_custom_fields[key])
          hash[field.field] = value
        end
      end

      def dri_object
        @dri_object ||= metadata_class.new(metadata)
      end

      def create_sidecars_for(*keys)
        missing_keys(keys).each do |k|
          exhibit.custom_fields.create! label: k, readonly_field: true
        end
        @exhibit_custom_fields = nil
      end

      def missing_keys(keys)
        custom_field_keys = exhibit_custom_fields.keys.map(&:downcase)
        keys.reject do |key|
          custom_field_keys.include?(key.downcase)
        end
      end

      def exhibit_custom_fields
        @exhibit_custom_fields ||= exhibit.custom_fields.each_with_object({}) do |value, hash|
          hash[value.configuration['label']] = value
        end
      end

      def iiif_manifest_base
        Spotlight::Resources::Dri::Engine.config.iiif_manifest_base
      end

      def image_urls
        @image_urls ||= files.map do |file|
          # skip unless it is an image
          next unless file && file.key?(surrogate_postfix)

          file_id = File.basename(
                      URI.parse(file[surrogate_postfix]).path
                    ).split("_#{surrogate_postfix}")[0]

          "#{iiif_manifest_base}/#{id}:#{file_id}/info.json"
        end.compact
      end

      def thumbnail_field
        blacklight_config.index.try(:thumbnail_field)
      end

      def tile_source_field
        blacklight_config.show.try(:tile_source_field)
      end

      def title_field
        blacklight_config.index.try(:title_field)
      end

      def sidecar
        @sidecar ||= document_model.new(id: compound_id(id)).sidecar(exhibit)
      end

      def surrogate_postfix
        Spotlight::Resources::Dri::Engine.config.surrogate_postfix
      end

      def document_model
        exhibit.blacklight_config.document_model
      end

      def metadata_class
        Spotlight::Resources::DriObject::Metadata
      end

      ###
      #  A simple class to map the metadata field
      #  in an object to label/value pairs
      #  This is intended to be overriden by an
      #  application if a different metadata
      #  strucure is used by the consumer
      class Metadata
        THEMES = ["human rights", "education", "communities"].freeze
        SUB_THEMES = [
          "lgbtq people", "disability", "migrants", "reconciliation",
          "infrastructure", "knowledge and learning", "knowledge application",
          "senior citizens", "children and youth", "citizen participation"
        ].freeze
        GRANTEES = ["glen (organisation)", "national lgbt federation (ireland)",
                    "transgender equality network ireland",
                    "national university of ireland, galway. centre for disability law and policy",
                    "irish penal reform trust", "akidwa", "irish refugee council",
                    "south tyrone empowerment programme", "genio (organization)",
                    "glencree centre for reconciliation", "disability action northern ireland",
                    "community foundation for northern ireland", "immigrant council of ireland"]
        COLLECTIONS = ["grant documentation", "oral histories"].freeze

        def initialize(metadata)
          @metadata = metadata
        end

        def to_solr
          metadata_hash.merge(descriptive_metadata)
        end

        def curated_collections
          @curated_collections ||= metadata['subject'].select { |s| s.start_with?('Curated collection')}.map { |t| t.split('--')[1] }
        end

        def collection
          return if curated_collections.blank?

          curated_collections.select { |c| COLLECTIONS.include?(c.downcase) }[0]
        end

        def dcmi_name(value)
          value.map do |v|
            name = v[/\Aname=(?<name>.+?);/i, 'name']
            name.try(:strip) || v
          end
        end

        def grantee
          return unless metadata.key?('subject') && metadata['subject'].present?

          metadata['subject'].select { |s| GRANTEES.include?(s.downcase) }[0]
        end

        def grant
          return unless metadata.key?('subject') && metadata['subject'].present?
          grant = metadata['subject'].select { |s| s.start_with?('Grant') }
          return if grant.empty?

          grant
        end

        def oral_history
          return if curated_collections.blank?

          curated_collections.reject do |c|
            COLLECTIONS.include?(c.downcase) || THEMES.include?(c.downcase) || SUB_THEMES.include?(c.downcase)
          end
        end

        def themes
          return [] if curated_collections.blank?

          curated_collections.select { |c| THEMES.include?(c.downcase) }
        end

        def subthemes
          return [] if curated_collections.blank?

          curated_collections.select { |c| SUB_THEMES.include?(c.downcase) }
        end

        private

        attr_reader :metadata

        def metadata_hash
          return {} unless metadata.present?
          return {} unless metadata.is_a?(Array)

          metadata.each_with_object({}) do |md, hash|
            next unless md['label'] && md['value']
            hash[md['label']] ||= []
            hash[md['label']] += Array(md['value'])
          end
        end

        def descriptive_metadata
          desc_metadata_fields.each_with_object({}) do |field, hash|
            case field
            when 'attribution'
              add_attribution(field, hash)
              next
            when 'temporal_coverage'
              add_dcmi_field(field, hash)
              next
            when 'geographical_coverage'
              add_dcmi_field(field, hash)
              next
            when 'grantee'
              add_grantee(field, hash)
              next
            when 'grant'
              add_grant(field, hash)
              next
            when 'oral_history'
              add_oral_history(field, hash)
              next
            when 'theme'
              add_theme(field, hash)
              next
            when 'subtheme'
              add_subtheme(field, hash)
              next
            when 'collection'
              add_collection(field, hash)
              next
            when 'doi'
              add_doi(field, hash)
              next
            end

            next unless metadata[field].present?
            hash[field.capitalize] ||= []
            hash[field.capitalize] += Array(metadata[field])
          end
        end

        def desc_metadata_fields
          %w(description doi creator subject grantee grant oral_history theme subtheme collection geographical_coverage temporal_coverage type attribution rights license)
        end

        def add_attribution(field, hash)
          return unless metadata.key?('institute')

          hash[field.capitalize] ||= []
          metadata['institute'].each do |institute|
            hash[field.capitalize] += Array(institute['name'])
          end
        end

        def add_doi(field, hash)
          if metadata['doi'].present? && metadata['doi'].first.key?('url')
            hash[field.capitalize] = metadata['doi'].first['url']
          end
        end

        def add_grantee(field, hash)
          hash[field.capitalize] ||= []
          hash[field.capitalize] = grantee
        end

        def add_grant(field, hash)
          hash[field.capitalize] ||= []
          hash[field.capitalize] = grant
        end

        def add_oral_history(field, hash)
          hash[field.capitalize] ||= []
          hash[field.capitalize] = oral_history
        end

        def add_theme(field, hash)
          return if themes.empty?

          hash[field.capitalize] ||= []
          hash[field.capitalize] = themes
        end

        def add_subtheme(field, hash)
          return if subthemes.empty?

          hash[field.capitalize] ||= []
          hash[field.capitalize] = subthemes
        end

        def add_collection(field, hash)
          hash[field.capitalize] ||= []
          hash[field.capitalize] = collection
        end

        def add_dcmi_field(field, hash)
          return unless metadata.key?(field)
          hash[field.capitalize] ||= []
          hash[field.capitalize] = dcmi_name(metadata[field])
        end
      end
    end
  end
end
