# frozen_string_literal: true

module SirTrevorRails
  module Blocks
    ##
    # Embed search results (from a browse category) into the page
    class LinkToSearchBlock < BrowseBlock
      include Displayable

      def tags
        @tags || exhibit_searches.all_tags
      end

      def searches(tag = nil)
        if tag
          exhibit_searches.tagged_with(tag).where(slug: item_ids)
        else
          exhibit_searches.where(slug: item_ids)
        end.sort do |a, b|
              ordered_items.index(a.slug) <=> ordered_items.index(b.slug)
            end
      end

      private

        def exhibit_searches
          @exhibit_searches ||= parent.exhibit.searches
        end
    end
  end
end
