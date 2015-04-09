$(document).ready(function() {
  // show relative or absolute date of last data update
  var last_update_container = $('#last_update');
  var last_update = $('#last_update_store').text();
  var update_moment = moment(last_update, "X");
  var absolute = $('<span/>').addClass('absolute').text(
    (last_update == '0' ? 'unknown' : update_moment.format("MM/DD/YYYY, HH:mm:ss a"))
  ).hide();
  var relative = $('<span/>').addClass('relative').text(
    (last_update == '0' ? 'unknown' : update_moment.fromNow())
  );
  last_update_container.attr('title', absolute.text());
  last_update_container.append(absolute);
  last_update_container.append(relative);
  $('.abs_rel').tooltip();
  $('.abs_rel').click(function () {
    $(this).find('span.absolute').toggle();
    $(this).find('span.relative').toggle();
  });

  //We want the first tab in the permissions page to be on by default
  $('div#user2tables').show();
  
  //When we select one of the tabs within the permissions page, we want
  //the correct menu to pop up on screen
  $('ul#navigation li').click(function() {
      var id = $(this).attr('id');
      window.location.hash = id;
      $('ul#navigation li.active').removeClass('active');
      $(this).addClass('active');
      $('div#permissions_tab_content > div.tabbedMenuContent').hide();
      $('div#'+id).show();
      $('div#access_results').empty();
      $('div#access_results').show();
    }
  );

  // restore latest selected tab if encoded in url hash
  var hash = window.location.hash.split('#')[1];
  if (hash && hash.length > 0) {
    var last_tab = $('#navigation li#' + hash);
    if (hash && last_tab.length) last_tab.click();
  }
     
  //Whenever we click the get permissions button, we send an ajax request to
  //get 1) users with permissions to a table 
  //or 2) tables that a user has access to
  //or 3) tables that a group has access to   
  $('.permissions_button').click(
    function(e) {
      
      var id = $(this).attr('id');
      var selected = $('#'+id+'_dd option:selected').attr('id');
      var results = $('div#access_results');
      var showing_tables = false;
      var showing_entities = false;
      if (id == 'user2tables' || id == 'group2tables')
        showing_tables = true;
      else if (id == 'table2users' || id == 'table2groups')
        showing_entities = true;
      else
        console.log('Unsupported selection "' + id + '"');
      results.show();
      
      $.ajax({
        type: 'GET',
        url: '/permissions/' + id,
        data: { "value": selected },
        timeout:  15000,
        beforeSend: function(){
          results.html('<br>Loading....<br><br>'); 
        },
        success: function(data) {
          //Lets parse the json object and remove any old results
          data = JSON.parse(data);
          results.empty();
          
          //We create our nifty table to hold results
          var table = $('<table/>');
          $(table).attr('data-auto', 'true');
          $(table).addClass('table table-bordered table-striped table-condensed table-hover');
          var header = $('<tr/>');
          $(table).append($('<thead/>').append(header));
          var body = $('<tbody/>');
          $(table).append($(body));
          //We create the column headers first
          var p_types = ["Select", "Insert", "Update", "Delete", "References"];

          if (showing_tables) {
            $(header).append($('<th/>').text('Schema'));
            $(header).append($('<th/>').text('Table'));
          } else if (showing_entities) {
            $(header).append($('<th/>').text('Name'));
          }
          for(var i = 0; i < p_types.length; i++) {
            $(header).append($('<th/>').text(p_types[i]));          
          }
          
          //Now we append the results of our query
          var new_revoked = function () {
            return $('<td/>').append($('<span/>').addClass('label label-danger').text('No'));
          }
          var new_granted = function () {
            return $('<td/>').append($('<span/>').addClass('label label-success').text('Yes'));
          }
          var new_row;
          for (var i = 0; i < data.length; i++) {
            new_row = $('<tr/>');
            if (showing_tables) {
              new_row.append($('<td/>').text(data[i]['dbobject']['schema_name']));
              new_row.append($('<td/>').text(data[i]['dbobject']['table_name']));
            } else if (showing_entities) {
              new_row.append($('<td/>').text(data[i]['entity']['name']));
            }
            new_row.append(data[i]['has_select']     ? new_granted() : new_revoked());
            new_row.append(data[i]['has_insert']     ? new_granted() : new_revoked());
            new_row.append(data[i]['has_update']     ? new_granted() : new_revoked());
            new_row.append(data[i]['has_delete']     ? new_granted() : new_revoked());
            new_row.append(data[i]['has_references'] ? new_granted() : new_revoked());
            $(body).append(new_row);
          }
          
          results.append(table);
          datatable_init(table);
        },
        error: function (req, textStatus, errorThrown) {
          results.empty();
          alert("Error loading permissions, reason: '" + errorThrown + "'");
        }
      });
    return false;
  });
});
