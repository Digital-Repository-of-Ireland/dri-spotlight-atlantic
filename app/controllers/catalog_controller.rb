##
# Simplified catalog controller
class CatalogController < ApplicationController
  include Blacklight::Catalog

  configure_blacklight do |config|
    config.show.oembed_field = :oembed_url_ssm
    config.show.partials.insert(1, :oembed)

    config.show.document_actions.delete(:email)
    config.show.document_actions.delete(:sms)

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
    config.add_facet_field  'readonly_grant_ssim', label: 'Grant'
    config.add_facet_field  'readonly_temporal_coverage_ssim', label: 'Year of Grant'
    config.add_facet_field  'readonly_geographical_coverage_ssim', label: 'Location of Grantee'
    config.add_facet_field  'readonly_type_ssim', label: 'Type'
    config.add_facet_field  'readonly_subtheme_ssim', label: 'Sub-theme'
    config.add_facet_field  'readonly_theme_ssim', label: 'Theme'
    config.add_facet_field  'readonly_collection_ssim', label: 'Collection'

    config.add_facet_fields_to_solr_request!

    config.add_field_configuration_to_solr_request!

    # Set which views by default only have the title displayed, e.g.,
    # config.view.gallery.title_only_by_default = true
    config.add_show_field 'readonly_temporal_coverage_ssim', label: 'Year of Grant'
    config.add_show_field 'readonly_geographical_coverage_ssim', label: 'Location of Grantee'
  end

  # get search results from the solr index
  def index
    (@response, @document_list) = search_results(params)

    grants_and_grantees

    respond_to do |format|
      format.html { store_preferred_view }
      format.rss  { render layout: false }
      format.atom { render layout: false }
      format.json do
        @presenter = Blacklight::JsonPresenter.new(@response,
                                                   @document_list,
                                                   facets_from_request,
                                                   blacklight_config)
      end
      additional_response_formats(format)
      document_export_formats(format)
    end
  end

  # get a single document from the index
  # to add responses for formats other than html or json see _Blacklight::Document::Export_
  def show
    @response, @document = fetch params[:id]

    @grant = { 'grantee' => {}, 'grant' => {} }

    grantee_info(@document['readonly_grantee_tesim'])
    grant_info(@document['readonly_grant_tesim'])

    respond_to do |format|
      format.html { setup_next_and_previous_documents }
      format.json { render json: { response: { document: @document } } }
      additional_export_formats(@document, format)
    end
  end

  private

  def grants_and_grantees
    results = repository.search(
      fq: "readonly_subcollection_type_ssim:grantee OR readonly_subcollection_type_ssim:grant"
    )

    docs = results['response']['docs']
    grantees = facet_by_field_name('readonly_grantee_ssim').items.map(&:value)
    grants = facet_by_field_name('readonly_grant_ssim').items.map(&:value)

    @grantees = {}
    @grants = {}

    docs.each do |doc|
      if doc['readonly_subcollection_type_ssim'] == ['grantee']
        grantees.each do |grantee|
          if doc['readonly_subject_tesim'].any?{ |s| s.casecmp(grantee)==0 }
            @grantees[grantee] = doc['readonly_description_tesim'][0]
          end
        end
      end

      if doc['readonly_subcollection_type_ssim'] == ['grant']
        grants.each do |grant|
          if doc['full_title_tesim'].include?(grant)
            @grants[grant] = doc['readonly_description_tesim'][0]
          end
        end
      end
    end
  end

  def grantee_info(grantee)
    result = repository.search(
      q: "readonly_subject_tesim:\"#{grantee}\"",
      fq: "readonly_subcollection_type_ssim:grantee"
    )
    if result['response']['docs'].present?
      grantee_collection = result['response']['docs'][0]
      grantee_description = grantee_collection['readonly_description_tesim'][0]

      @grant['grantee']['name'] = grantee.first
      @grant['grantee']['description'] = grantee_description
    end
  end

  def grant_info(grant)
    result = repository.search(
      q: "readonly_title_tesim:\"#{grant}\"",
      fq: "readonly_subcollection_type_ssim:grant"
    )
    if result['response']['docs'].present?
      grant_collection = result['response']['docs'][0]
      grant_description = grant_collection['readonly_description_tesim'][0]

      @grant['grant']['number'] = grant.first
      @grant['grant']['description'] = grant_description
    end
  end
end
