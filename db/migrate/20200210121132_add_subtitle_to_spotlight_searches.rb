class AddSubtitleToSpotlightSearches < ActiveRecord::Migration[5.1]
  def change
    add_column :spotlight_searches, :subtitle, :string
  end
end
