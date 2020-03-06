module FacetsHelper
  include Blacklight::FacetsHelperBehavior

  ##
  # Standard display of a facet value in a list. Used in both _facets sidebar
  # partial and catalog/facet expanded list. Will output facet value name as
  # a link to add that to your restrictions, with count in parens.
  #
  # @param [Blacklight::Solr::Response::Facets::FacetField] facet_field
  # @param [Blacklight::Solr::Response::Facets::FacetItem] item
  # @param [Hash] options
  # @option options [Boolean] :suppress_link display the facet, but don't link to it
  # @return [String]
  def render_facet_value(facet_field, item, options = {})
    path = path_for_facet(facet_field, item)
    content_tag(:span, class: "facet-label") do

      if %w(readonly_grantee_ssim readonly_grant_ssim
            readonly_oral_history_ssim readonly_collection_ssim).include?(facet_field)
        link_to_unless(options[:suppress_link],
                       facet_display_value(facet_field, item),
                       path,
                       class: "facet-select facet-popover",
                       "data-content" => facet_info(item.value),
                       "data-trigger" => "hover",
                       "data-placement" => "right")
      else
        link_to_unless(options[:suppress_link],
                       facet_display_value(facet_field, item),
                       path,
                       class: "facet-select")
      end
    end + render_facet_count(item.hits)
  end

  def facet_info(value)
    return @grantees[value] if @grantees && @grantees.key?(value)
    return @grants[value] if @grants && @grants.key?(value)
    return @oral[value] if @oral && @oral.key?(value)
    return @collections[value] if @collections && @collections.key?(value)
  end
end
