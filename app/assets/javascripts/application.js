// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, or any plugin's
// vendor/assets/javascripts directory can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// compiled file. JavaScript code in this file should be added after the last require_* statement.
//
// Read Sprockets README (https://github.com/rails/sprockets#sprockets-directives) for details
// about supported directives.
//
//= require jquery3
//= require rails-ujs
//= require turbolinks
//
// Required by Blacklight
//= require popper
// Twitter Typeahead for autocomplete
//= require twitter/typeahead
//= require bootstrap
//= require blacklight/blacklight
//= require blacklight_gallery


//= require_tree .

$(document).ready(function() {
	$('.facet-popover').popover( {container: 'body', delay: { show: 100, hide: 100 }} );
});

$(document).on('page:change', function(){
  $('facet-popover').popover( {container: 'body', delay: { show: 100, hide: 100 }} );
});
