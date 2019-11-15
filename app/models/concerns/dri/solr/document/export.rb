module DRI::Solr::Document::Export

  # Exports the citation in DRI format
  # @return [String] the citation as html-safe text
  def export_as_dri_citation
  	text = ''

  	authors_list = []
  	authors_list_final = []

  	authors = author_list
  	authors.each do |author|
  	  next if author.blank?
  	  authors_list.push(author)
  	end
  	authors_list.each do |author|
  	  if author == authors_list.first # first
  	    authors_list_final.push(author.strip)
  	  elsif author == authors_list.last # last
  	    authors_list_final.push(', &amp; ' + author.strip)
  	  else # all others
  	    authors_list_final.push(', ' + author.strip)
  	  end
  	end

  	text += authors_list_final.join

  	unless text.blank?
  	  if text[-1, 1] != '.'
  	    text += '. '
  	  else
  	    text += ' '
  	  end
  	end

  	# Get Pub Date
  	#text << '(' + setup_pub_date('dri') + ') ' unless setup_pub_date('dri').nil?
  	title_info = ''
  	self['full_title_tesim'].each do |t|
  	  title_info += clean_end_punctuation(CGI.escapeHTML(t)).strip + ', '
  	end
  	text += title_info unless title_info.blank?
  	# Set database name
  	text += setup_database_name

    unless self['readonly_depositing_institute_tesim'].blank?
  	  text += ", #{self['readonly_depositing_institute_tesim'].first} [Depositing Institution]"
    end

    unless self['readonly_doi_tesim'].blank?
      text += ", https://doi.org/#{self['readonly_doi_tesim'].first}"
    end

  	text.html_safe
  end

  def setup_database_name
    'Digital Repository of Ireland [Distributor]'
  end

  def citation_title(title_text)
    prepositions = %w(a about across an and before but by for it of the to with without)
  	new_text = []
  	title_text.split(' ').each_with_index do |word, index|
  	  if (index == 0 && word != word.upcase) ||
  	     (word.length > 1 && word != word.upcase && !prepositions.include?(word))
  	    # the split("-") will handle the capitalization of hyphenated words
  	    new_text << word.split('-').map!(&:capitalize).join('-')
  	  else
  	    new_text << word
  	  end
  	end
  	new_text.join(' ')
  end

  def setup_title_info
  	text = ''
  	title = self['full_title_tesim'].first
  	unless title.blank?
  	  title = CGI.escapeHTML(title)
  	  title_info = clean_end_punctuation(title.strip)
  	  text << title_info
  	end

  	return nil if text.strip.blank?

  	clean_end_punctuation(text.strip) + '.'
  end

  def clean_end_punctuation(text)
  	return text[0, (text.length - 1)] if %w(. , : ; /).include? text[-1, 1]

  	text
  end

  def author_list
  	self['readonly_creator_tesim'].map { |author| clean_end_punctuation(CGI.escapeHTML(author)) }.uniq
  end

  def all_authors
  	authors = self['readonly_creator_tesim']

  	return nil if authors.empty?

  	authors.map { |author| CGI.escapeHTML(author) }
  end

  def abbreviate_name(name)
  	abbreviated_name = ''
  	name = name.join('') if name.is_a? Array
  	# make sure we handle "Cher" correctly
  	return name if !name.include?(' ') && !name.include?(',')
  	surnames_first = name.include?(',')
  	delimiter = surnames_first ? ', ' : ' '
  	name_segments = name.split(delimiter)
  	given_names = surnames_first ? name_segments.last.split(' ') : name_segments.first.split(' ')
  	surnames = surnames_first ? name_segments.first.split(' ') : name_segments.last.split(' ')
  	abbreviated_name << surnames.join(' ')
  	abbreviated_name << ', '
  	abbreviated_name << given_names.map { |n| "#{n[0]}." }.join if given_names.is_a? Array
  	abbreviated_name << "#{given_names[0]}." if given_names.is_a? String

  	abbreviated_name
  end

  def name_reverse(name)
  	name = clean_end_punctuation(name)
  	return name unless name =~ /,/
  	temp_name = name.split(', ')

  	temp_name.last + ' ' + temp_name.first
  end
end
