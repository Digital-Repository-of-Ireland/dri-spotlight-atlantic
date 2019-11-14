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
        add_label
        add_creator
        add_subject
        add_theme
        add_subtheme
        add_type
        add_temporal_coverage
        add_geographical_coverage
        add_metadata
        add_collection_id
        add_collection

        if metadata['type'] == ['Collection']
          add_subcollection_type
        else
          add_grantee
          add_grant
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

      def add_subject
        solr_hash['readonly_subject_ssim'] = metadata['subject']
      end

      def add_temporal_coverage
        solr_hash['readonly_temporal_coverage_ssim'] = metadata_class.dcmi_name(metadata['temporal_coverage']) if metadata.key?('temporal_coverage') && metadata['temporal_coverage'].present?
      end

      def add_theme
        return unless metadata.key?('subject') && metadata['subject'].present?
        solr_hash['readonly_theme_ssim'] = metadata['subject'].select { |s| s.start_with?('Curated collection')}.map { |t| t.split('--')[1] }[0]
      end

      def add_subtheme
        return unless metadata.key?('subject') && metadata['subject'].present?
        solr_hash['readonly_subtheme_ssim'] = metadata['subject'].select { |s| s.start_with?('Curated collection')}.map { |t| t.split('--')[1] }[1]
      end

      def add_geographical_coverage
        solr_hash['readonly_geographical_coverage_ssim'] = metadata_class.dcmi_name(metadata['geographical_coverage']) if metadata.key?('geographical_coverage') && metadata['geographical_coverage'].present?
      end

      def add_grantee
        solr_hash['readonly_grantee_ssim'] = metadata['subject'][0] if metadata.key?('subject') && metadata['subject'].present?
      end

      def add_grant
        return unless metadata.key?('subject') && metadata['subject'].present?
        solr_hash['readonly_grant_ssim'] = metadata['subject'].select { |s| s.start_with?('Grant') }
      end

      def add_type
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

      def add_collection
        return unless metadata.key?('subject') && metadata['subject'].present?
        solr_hash['readonly_collection_ssim'] = metadata['subject'].select { |s| s.start_with?('Curated collection')}.map { |t| t.split('--')[1] }[2]
      end

      def add_subcollection_type
        unless metadata['type'] == ['Collection']
          solr_hash['readonly_subcollection_type_ssim'] = nil
          return
        end

        solr_hash['readonly_subcollection_type_ssim'] = if metadata['title'].first.start_with?("Grant")
                                                          'grant'
                                                        else
                                                          'grantee'
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
      end

      def object_metadata
        item_metadata = metadata_class.new(metadata).to_solr
        return {} unless metadata.present?
        create_sidecars_for(*item_metadata.keys)

        item_metadata.each_with_object({}) do |(key, value), hash|
          next unless (field = exhibit_custom_fields[key])
          hash[field.field] = value
        end
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
          hash[value.label] = value
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
        def initialize(metadata)
          @metadata = metadata
        end

        def to_solr
          metadata_hash.merge(descriptive_metadata)
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
            when 'temporal_coverage', 'geographical_coverage'
              add_dcmi_field(field, hash)
              next
            when 'grantee'
              add_grantee(field, hash)
              next
            when 'grant'
              add_grant(field, hash)
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
            end

            next unless metadata[field].present?
            hash[field.capitalize] ||= []
            hash[field.capitalize] += Array(metadata[field])
          end
        end

        def desc_metadata_fields
          %w(description creator subject grantee grant theme subtheme collection temporal_coverage geographical_coverage type attribution rights license)
        end

        def add_attribution(field, hash)
          return unless metadata.key?('institute')

          hash[field.capitalize] ||= []
          metadata['institute'].each do |institute|
            hash[field.capitalize] += Array(institute['name'])
          end
        end

        def add_grantee(field, hash)
          return unless metadata.key?('subject') && metadata['subject'].present?

          hash[field.capitalize] ||= []
          hash[field.capitalize] = metadata['subject'][0]
        end

        def add_grant(field, hash)
          return unless metadata.key?('subject') && metadata['subject'].present?
          grant = metadata['subject'].select { |s| s.start_with?('Grant') }
          return if grant.empty?

          hash[field.capitalize] ||= []
          hash[field.capitalize] = grant[0]
        end

        def add_theme(field, hash)
          return unless metadata.key?('subject') && metadata['subject'].present?
          themes = metadata['subject'].select { |s| s.start_with?('Curated collection')}.map { |t| t.split('--')[1] }
          return if themes.empty?

          hash[field.capitalize] ||= []
          hash[field.capitalize] = themes[0]
        end

        def add_theme(field, hash)
          return if themes.empty?

          hash[field.capitalize] ||= []
          hash[field.capitalize] = themes[0]
        end

        def add_subtheme(field, hash)
          return if themes.empty? || themes.length < 2

          hash[field.capitalize] ||= []
          hash[field.capitalize] = themes[1]
        end

        def add_collection(field, hash)
          return if themes.empty? || themes.length < 3

          hash[field.capitalize] ||= []
          hash[field.capitalize] = themes[2]
        end

        def themes
          return [] unless metadata.key?('subject') && metadata['subject'].present?
          metadata['subject'].select { |s| s.start_with?('Curated collection')}.map { |t| t.split('--')[1] }
        end

        def add_dcmi_field(field, hash)
          return unless metadata.key?(field)

          hash[field.capitalize] ||= []
          hash[field.capitalize] = self.class.dcmi_name(metadata[field])
        end

        def self.dcmi_name(value)
          name = value.first[/\Aname=(?<name>.+?);/i, 'name']
          name || value
        end
      end
    end
  end
end