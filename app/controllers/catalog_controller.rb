##
# Simplified catalog controller
class CatalogController < ApplicationController
  include Blacklight::Catalog

  configure_blacklight do |config|
          config.show.oembed_field = :oembed_url_ssm
          config.show.partials.insert(1, :oembed)

    config.view.gallery.partials = [:index_header, :index]
    config.view.masonry.partials = [:index]
    config.view.slideshow.partials = [:index]

    config.index.thumbnail_method = :render_thumbnail

    config.show.tile_source_field = :content_metadata_image_iiif_info_ssm
    config.show.partials.insert(1, :openseadragon)
    ## Default parameters to send to solr for all search-like requests. See also SolrHelper#solr_search_params
    config.default_solr_params = {
      qt: 'search',
      rows: 10,
      fl: '*'
    }

    config.document_solr_path = 'get'
    config.document_unique_id_param = 'ids'

    # solr field configuration for search results/index views
    config.index.title_field = 'full_title_tesim'

    config.add_search_field 'all_fields', label: 'Everything'

    config.add_sort_field 'relevance', sort: 'score desc', label: 'Relevance'

    config.add_facet_field  'readonly_grantee_ssim', label: 'Grantee'
    config.add_facet_field  'readonly_temporal_coverage_ssim', label: 'Year of Grant'
    config.add_facet_field  'readonly_geographical_coverage_ssim', label: 'Location of Grantee'
    config.add_facet_field  'readonly_type_ssim', label: 'Type'
    config.add_facet_field  'readonly_subtheme_ssim', label: 'Sub-theme'
    config.add_facet_field  'readonly_theme_ssim', label: 'Theme'

    config.add_facet_fields_to_solr_request!

    config.add_field_configuration_to_solr_request!

    # Set which views by default only have the title displayed, e.g.,
    # config.view.gallery.title_only_by_default = true
  end
end
