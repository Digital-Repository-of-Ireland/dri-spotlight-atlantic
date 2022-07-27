##
# Simplified catalog controller
class CatalogController < ApplicationController
  include Blacklight::Catalog

  COLLECTION_MOUSEOVER = {
    "Grant documentation" => "To document Atlantic’s work on the island of Ireland this " +
                              "collection draws materials from grant making records of " +
                              "The Atlantic Philanthropies entire archive housed at " +
                              "Cornell University Library’s Division of Rare and " +
                              "Manuscript Collections in Ithaca, New York. " +
                              "This collection extends to 60 grant files, " +
                              "containing records that document the entire life cycle " +
                              "of grants-from proposals to final reports and printed ephemera, " +
                              "such as brochures.",
    "Oral histories" => "To document Atlantic’s work on the island of Ireland oral histories " +
                        "were captured by Digital Repository of Ireland as part of the " +
                        "Atlantic Philanthropies Archive Project (2017-2020) titled Amplifying " +
                        "change: A history of the Atlantic Philanthropies on island of Ireland. " +
                        "This collection extends to forty oral histories. " +
                        "Each oral history recording is accompanied by a transcript and a " +
                        "Polaroid photograph of the interviewee.",
    "Publications" => "The collection The Atlantic Philanthropies-Island of Ireland-Publications " +
                      "includes reports commissioned by The Atlantic Philanthropies on the topic of " +
                      "particular issues or countries that have benefited from the organisation’s " +
                      "grant making.",
    "Essays" => "To contextualise The Atlantic Philanthropies’ work on the island of Ireland, " +
                "essays were commissioned by the Digital Repository of Ireland as part the Atlantic " +
                " Philanthropies Archive Project (2017-2020) titled Amplifying change: A history of " +
                "the Atlantic Philanthropes on island of Ireland. This collection extends to six essays " +
                "that offer a wide range of perspectives to the organisation from authors that were " +
                "beneficiaries and bibliographers."
  }.freeze

  configure_blacklight do |config|
    config.show.oembed_field = :oembed_url_ssm
    config.show.partials.insert(1, :oembed)

    config.show.document_actions.delete(:email)
    config.show.document_actions.delete(:sms)
    config.index.document_actions.delete(:bookmark)

    config.navbar.partials.delete(:bookmark)
    config.navbar.partials.delete(:search_history)

    config.view.gallery(document_component: Blacklight::Gallery::DocumentComponent)
    config.view.masonry(document_component: Blacklight::Gallery::DocumentComponent)
    config.view.slideshow(document_component: Blacklight::Gallery::SlideshowComponent)

    config.view.gallery.partials = [:index_header, :index]
    config.view.masonry.partials = [:index]
    config.view.slideshow.partials = [:index]

    #config.index.thumbnail_method = :render_thumbnail

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
    config.view.index.thumbnail_field = 'thumbnail_url_ssm'
    config.view.list.thumbnail_field = 'thumbnail_square_url_ssm'

    config.add_search_field 'all_fields', label: 'Everything'

    config.add_sort_field 'relevance', sort: 'score desc', label: 'Relevance'

    config.add_facet_field  'readonly_grantee_ssim', label: 'Grantee', limit: 20
    config.add_facet_field  'readonly_grant_ssim', label: 'Grant', limit: 20
    config.add_facet_field  'readonly_temporal_coverage_ssim', label: 'Year of Grant', limit: 20
    config.add_facet_field  'readonly_geographical_coverage_ssim', label: 'Location of Grantee', limit: 20
    config.add_facet_field  'readonly_oral_history_ssim', label: 'Oral History', limit: 20
    config.add_facet_field  'readonly_type_ssim', label: 'Type', limit: 20
    config.add_facet_field  'readonly_subtheme_ssim', label: 'Sub-theme', limit: 20
    config.add_facet_field  'readonly_theme_ssim', label: 'Theme', limit: 20
    config.add_facet_field  'readonly_collection_ssim', label: 'Collection', collapse: false

    config.add_facet_fields_to_solr_request!

    config.add_field_configuration_to_solr_request!

    # Set which views by default only have the title displayed, e.g.,
    # config.view.gallery.title_only_by_default = true
    config.add_show_field 'readonly_temporal_coverage_ssim', label: 'Year of Grant'
    config.add_show_field 'readonly_geographical_coverage_ssim', label: 'Location of Grantee'
  end

  def index
    (@response, deprecated_document_list) = search_service.search_results

    @document_list = ActiveSupport::Deprecation::DeprecatedObjectProxy.new(deprecated_document_list, 'The @document_list instance variable is deprecated; use @response.documents instead.')
    facet_mouseover_info

    respond_to do |format|
      format.html { store_preferred_view }
      format.rss  { render layout: false }
      format.atom { render layout: false }
      format.json do
        @presenter = Blacklight::JsonPresenter.new(@response,
                                                   blacklight_config)
      end
      additional_response_formats(format)
      document_export_formats(format)
    end
  end

  # get a single document from the index
  # to add responses for formats other than html or json see _Blacklight::Document::Export_
  def show
    deprecated_response, @document = search_service.fetch(params[:id])
    @response = ActiveSupport::Deprecation::DeprecatedObjectProxy.new(deprecated_response, 'The @response instance variable is deprecated; use @document.response instead.')

    if @document['readonly_collection_tesim'].present?
      if @document['readonly_collection_tesim'].first == 'Grant documentation'
        @grant = { 'grantee' => {}, 'grant' => {} }
        grantee_info(@document['readonly_grantee_tesim'])
        grant_info(@document['readonly_grant_tesim'])
      elsif @document['readonly_collection_tesim'].first == 'Oral histories'
        @oral = oral_history_info(@document['readonly_oral_history_tesim'])
      end
    end

    respond_to do |format|
      format.html { @search_context = setup_next_and_previous_documents }
      format.json
      additional_export_formats(@document, format)
    end
  end

  private

  def facet_mouseover_info
    count_result = search_service.repository.search(
      fq: "readonly_subcollection_type_ssim:grantee OR readonly_subcollection_type_ssim:grant OR readonly_subcollection_type_ssim:oral",
      rows: 0
    )

    results = search_service.repository.search(
      fq: "readonly_subcollection_type_ssim:grantee OR readonly_subcollection_type_ssim:grant OR readonly_subcollection_type_ssim:oral",
      rows: count_result['response']['numFound']
    )

    docs = results['response']['docs']
    grantees = facet_by_field_name('readonly_grantee_ssim', @response).items.map(&:value)
    grants = facet_by_field_name('readonly_grant_ssim', @response).items.map(&:value)
    oral = facet_by_field_name('readonly_oral_history_ssim', @response).items.map(&:value)

    @grantees = {}
    @grants = {}
    @oral = {}
    @collections = COLLECTION_MOUSEOVER

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

      if doc['readonly_subcollection_type_ssim'] == ['oral']
        oral.each do |oral|
          if doc['full_title_tesim'].include?(oral)
            @oral[oral] = doc['readonly_description_tesim'][0]
          end
        end
      end
    end
  end

  def grantee_info(grantee)
    result = search_service.repository.search(
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
    result = search_service.repository.search(
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

  def oral_history_info(interviewee)
    result = search_service.repository.search(
      q: "readonly_title_tesim:\"#{interviewee}\"",
      fq: "readonly_subcollection_type_ssim:oral"
    )
    if result['response']['docs'].present?
      oral_history_collection = result['response']['docs'][0]
      oral_history_description = oral_history_collection['readonly_description_tesim'][0]

      oral_history_description
    end
  end
end
