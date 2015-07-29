function customFilter( settings, data, dataIndex ) {
    var tableId = settings.sInstance;
    if (tableId == 'tablereports' || tableId == 'tablearchives'){  
      //If the table is not fully initialized with custom code and custom filters get fired (since filter configurations are global),
      //then allow the data to pass through
      if($('#'+tableId).dataTable().fnSettings().customInit != true)
        return true;
      var columnsSearchTerm = $('#'+tableId+'_columns_filter').val();
      var tableSearchTerm = $('#'+tableId+'_tables_filter').val();
      var schemaTableFilterFlag = false;
      var columnsFilterFlag = false;
      //try schema/table level match
      if (tableSearchTerm == ""){
        schemaTableFilterFlag = true;
      }
      else{
        var criteria = null;
        var searchable_data = "";
        var regex = new RegExp('<a .*>(.*)</a>');
        var value = regex.exec(data[1]);
        var extractedData = (value != null && value.length >= 2)?value[1]:data[1];
        searchable_data = data[0]+"."+extractedData;
        criteria = $.fn.dataTable.ext.internal._fnFilterCreateSearch(tableSearchTerm, 
                    false, settings.oPreviousSearch.bSmart, settings.oPreviousSearch.bCaseInsensitive);
        schemaTableFilterFlag = criteria.test(searchable_data);
      }
      //Now do column level filtering
      if (columnsSearchTerm == ""){
        columnsFilterFlag = true;
      }
      else{
        //Extract column names
        //search_against=data[1];
        var node = $.parseHTML(data[1]);
        var search_against = '';
        node = $(node).attr('data-content');
        $(node).find('li').each(function(){
          search_against += $(this).text() + ' ';
        });
        search_against = search_against.trim();
        criteria = $.fn.dataTable.ext.internal._fnFilterCreateSearch(columnsSearchTerm, 
                    settings.oPreviousSearch.bRegex, settings.oPreviousSearch.bSmart, settings.oPreviousSearch.bCaseInsensitive);
        columnsFilterFlag = (criteria.test(search_against))
      }
      return (schemaTableFilterFlag && columnsFilterFlag);
    }
    return true;
}

function customTableReportsArchivesInit(table, options){
  $.fn.dataTable.ext.type.order['complex-table-pre'] = function ( d ) {
            regex = new RegExp('<a .*>(.*)</a>');
            value = regex.exec(d);
            return (value != null && value.length >= 2)?value[1]:d;
  };
  var custom_div_id = '#'+$(table).attr('id')+'_filter';
  custom_options = {
      "columnDefs": [ {
          "type": "complex-table",
          "targets": 1
      } ],
      'aaSorting': [],
      'dom': "<'row'<'col-sm-6'l><'"+custom_div_id+".col-sm-6''>><'row'<'col-sm-12'tr>><'row'<'col-sm-6'i><'col-sm-6'p>>"
  };
  $.extend(options, custom_options);
  $(table).dataTable(options);
  var tableId = $(table).attr('id');
  var custom_div_id = '#'+tableId+'_filter';
  $(custom_div_id).append("<div style='text-align:right' >Search : <input placeholder='schema.table' id='"+tableId+"_tables_filter' class='form-control input-sm' type='search'></input>&nbsp<input id='"+tableId+"_columns_filter' placeholder='column' class='form-control input-sm' type='search'></input></div>");
  //Set a custom flag to mark that the table has been fully initialized and customized
  $('#'+tableId).dataTable().fnSettings().customInit = true;
  var tableSearchBox = $('#'+tableId+'_tables_filter');
  var columnsSearchBox = $('#'+tableId+'_columns_filter');
  var filterFunctions = $.fn.dataTable.ext.search;
  if (filterFunctions.indexOf(customFilter)==-1){
    $.fn.dataTable.ext.search.push(customFilter);
  }
  tableSearchBox.on('keyup click', function () {
        $(table).DataTable().draw();
      });
  columnsSearchBox.on('keyup click', function () {
        $(table).DataTable().draw();
      });
}

/*tableSearchBox.on('keyup', function () {
      var searchTerm = $(this).val();
      splitted_terms=searchTerm.split('.');
      if(splitted_terms.length == 2){
        $(table).DataTable().column(0).search(splitted_terms[0],
            false,
            true
        ).column(1).search(splitted_terms[1],false,true);
        var filtered_data = $('#tablereports').dataTable().fnSettings().aiDisplay.slice();
        $(table).DataTable().columns().search('',
            false,
            true
        );
        $(table).DataTable().search(searchTerm,
            true,
            false
        );
        var filtered_data_global = $('#tablereports').dataTable().fnSettings().aiDisplay.slice();
        filtered_data.concat(filtered_data_global.filter(function (data){
          return filtered_data.indexOf(data)==-1;
        }));
        $('#tablereports').dataTable().fnSettings().aiDisplay=[];
        $('#tablereports').dataTable().fnSettings().aiDisplay=filtered_data;
        $.fn.dataTable.ext.internal._fnDraw($('#tablereports').dataTable().fnSettings())
      }else{
        //To make sure no columns filteres are applied along with the global search since all column level searches are preserved
        $(table).DataTable().columns().search('',
            false,
            true
        ).draw();
        $(table).DataTable().search(searchTerm,
            false,
            true
        ).draw();
      }
  });*/

// function custom_redshift_search_old(table){
//   var tableId = $(table).attr('id');
//   var filterContainer = $('div#' + tableId + '_filter label');
//   content = "<select id='redshift_table_select' class='form-control input-sm'><option value='schema_table' selected='selected'>Schema/Table</option><option value='columns'>Columns</option>"
//   $(content).prependTo(filterContainer);
//   var filterContainerContent = $(filterContainer).html()
//   filterContainerContent = filterContainerContent.replace('Search:','');
//   filterContainerContent = 'Search By : '+filterContainerContent;
//   filterContainer.html(filterContainerContent);
//   var searchBox = $('div#' + tableId + '_filter input');
//   searchBox.unbind();
//   $.fn.dataTable.ext.search.push(
//       function( settings, data, dataIndex ) {
//           tableid = settings.sInstance;
//           if (tableId == 'tablereports' || tableId == 'tablearchives'){
//             var searchTerm = $('div#' + tableId + '_filter input').val();
//             if (search_term == "") 
//               return true;
//             //var searchBox = $('div#' + tableId + '_filter input');
//             //is_search_by_columns = $("#redshift_table_select").val() == "schema_table"?false:true;
//             is_search_by_tables_first = false;
//             splitted_terms = search_term.split(".");
//             var criteria = null;
//             var searchable_data = "";
//             if(splitted_terms.length > 1){
//               is_search_by_tables_first = true;
//             }
//             if(is_search_by_tables_first){
//               searchable_data = data[0]+"."+data[1];
//               if (search_term.toLowerCase() == searchable_data.toLowerCase()) return true;
//             }
//             criteria = $.fn.dataTable.ext.internal._fnFilterCreateSearch(settings.oPreviousSearch.sSearch, settings.oPreviousSearch.bRegex,
//                          settings.oPreviousSearch.bSmart, settings.oPreviousSearch.bCaseInsensitive);
//             for(i=0;i<data.length;i++){
//               search_against=data[i];
//               if(i==1){
//                 regex = new RegExp('<a .*>(.*)</a>');
//                 value = regex.exec(data[i]);
//                 search_against = (value != null && value.length >= 2)?value[1]:"";
//               }
//               if(criteria.test(search_against))
//                 return true;
//             }
//             return false;
//           }
//           return true;
//       }
//   );
//   searchBox.on('keyup', function () {
//       var search_term = $(this).val();
//       is_search_by_columns = $("#redshift_table_select").val() == "schema_table"?false:true;
//       if(is_search_by_columns){
        
//       }
//       else{
//         search_term=search_term.replace('.',' ');
//         $(table).DataTable().columns([0, 1]).search(
//             search_term,
//             false,
//             true
//         ).draw();
//       }
//   }); 
// }

$(document).ready(function() {

  // init tooltips
  $('[data-toggle="tooltip"]').tooltip();
  $("[data-toggle=popover]").popover();
  $('#tablereports').on('draw.dt', function() {
    // after rerender we need to reinitialize
    $('[data-toggle=tooltip]').tooltip();
    $("[data-toggle=popover]").popover();
  });
  //Search box auto focus
  var searchBox = $('div.dataTables_filter input');
  searchBox.focus();
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

  // export schemas button
  $('#schema_export_submit').on('click', function(e) {
    $('#schema_export_submit').hide();
    $('#schema_export_loading').show();
    $('#error_alert').hide();
    $.ajax({
      "type":     'POST',
      "url":      'tables/structure_export',
      "data":     'email=' + $('#inputEmail').val(),
      "cache":    false,
      "timeout":  45000,
      "success":  function (json) {
        $('#export_structure_modal').modal('toggle');
      },
      "error":  function (req, textStatus, errorThrown) {
        $('#error_alert').text("Invalid emails");
        $('#error_alert').show();
      },
      "complete": function (req, textStatus) {
        $('#schema_export_submit').show();
        $('#schema_export_loading').hide();
      }
    });
    return false;
  });

  $('#update_all_tables').click(function(e) {
    $('#update_all_tables').hide();
    $('#update_all_tables_loading').show();
    $.ajax({
      "type":     'POST',
      "url":      'tables/report',
      "data":     '',
      "dataType": "json",
      "cache":    false,
      "timeout":  45000,
      "success":  function (json) {
        window.location.reload();
      },
      "error": function (req, textStatus, errorThrown) {
        alert("Error during update, reason: '" + errorThrown + "'");
      },
      "complete": function (req, textStatus, errorThrown) {
        $('#update_all_tables').show();
        $('#update_all_tables_loading').hide();
      }
    });
  });

  // update buttons
  $('#tablereports tbody').on('click', 'button.tbl-update', function(e) {
    var entry_id = $(e.target).attr("data-id");
    var table_name = $(e.target).attr("data-table-name");
    var schema_name = $(e.target).attr("data-schema-name");

    // saved in case user goes to a different page, which may move these out of view
    var update_button = $('button#update_button_' + entry_id);
    var loading_img = $('img#loading_img_' + entry_id);
    update_button.hide();
    loading_img.show();
    $.ajax({
      "type":     'POST',
      "url":      'tables/report',
      "data":     'schema_name=' + schema_name + '&table_name=' + table_name,
      "dataType": "json",
      "cache":    false,
      "timeout":  45000,
      "success":  function (json) {
        var dTable = $('table#tablereports').dataTable();
        var row = $(e.target).parent().parent();
        if (json['doesnotexist']) {
          row.addClass('strikeout');
        } else {
          row.removeClass('strikeout');
          json_sort_keys = json['sort_keys'];

          var size = (json['size_in_mb'] / 1024.0).toFixed(2);
          var sort_keys = '';
          var dist_key;
          var col_encoding;
          var skew;
          var slices_populated;
          if (json_sort_keys.length == 0)
            sort_keys = '<span class="label label-danger">None!</span>';
          else {
            for (var i = 0; i < json_sort_keys.length; i++) {
              sort_keys += '<br />';
              if (i == 0)
                sort_keys += '<span class="label label-primary">' + json_sort_keys[i] + '</span>';
              else
                sort_keys += '<span class="label label-info">' + json_sort_keys[i] + '</span>';
            }
            sort_keys = sort_keys.substring(6);
          }
          if (json['dist_key']) {
            if (json['dist_key'] == json_sort_keys[0]) {
              dist_key = '<span class="label label-primary">' + json['dist_key'] + '</span>';
            } else {
              dist_key = '<span class="label label-info">' + json['dist_key'] + '</span>';
            }
          } else {
            if (json['dist_style'])
              dist_key = '<span class="label label-info">' + json["dist_style"]+ ' distribution</span>';
            else
              dist_key = '<span class="label label-danger">unknown distribution</span>';
          }
          if (json['has_col_encodings'])
            col_encoding = '<span class="label label-success">Yes</span>';
          else
            col_encoding = '<span class="label label-danger">No</span>';
          if (json['pct_skew_across_slices'] > 100.0)
            skew = '<span class="label label-danger">' + json['pct_skew_across_slices'].toFixed(2) + '%</span>';
          else
            skew = '<span class="label label-success">' + json['pct_skew_across_slices'].toFixed(2) + '%</span>';
          if (json['pct_slices_populated'] < 50.0)
            slices_populated = '<span class="label label-danger">' + json['pct_slices_populated'].toFixed(2) + '%</span>';
          else
            slices_populated = '<span class="label label-success">' + json['pct_slices_populated'].toFixed(2) + '%</span>';

          dTable.fnUpdate(size, row, 2, false, false);
          dTable.fnUpdate(sort_keys, row, 3, false, false);
          dTable.fnUpdate(dist_key, row, 4, false, false);
          dTable.fnUpdate(col_encoding, row, 5, false, false);
          dTable.fnUpdate(skew, row, 6, false, false);
          dTable.fnUpdate(slices_populated, row, 7, false, false);
        }

        update_button.show();
        loading_img.hide();
      },
      "error": function (req, textStatus, errorThrown) {
        update_button.show();
        loading_img.hide();
        var errorCause = errorThrown;
        if (req.responseJSON['error'])
          errorCause = req.responseJSON['error'];
        alert("Error loading update, reason: '" + errorCause + "'");
      }
    });
    return false;
  });

  // comment modal
  $('#comment_modal').on('show.bs.modal', function(event) {
    var $button = $(event.relatedTarget);
    var id = $button.attr('data-id');
    var schema = $button.attr('data-schema-name');
    var table = $button.attr('data-table-name');
    var comment = $button.attr('data-comment');
    var $comment = $(this).find('input[name=comment]');
    var $submit = $('#comment_submit');
    var $label = $('#commentLabel');
    $submit.attr('data-id', id);
    $submit.attr('data-schema-name', schema);
    $submit.attr('data-table-name', table);
    $comment.val(comment);
    if (comment) {
      $label.text("Edit Comment for " + schema + "." + table);
      $submit.text("Confirm Edit");
    } else {
      $label.text("New Comment for " + schema + "." + table);
      $submit.text("Confirm Add");
    }
  });
  $('#comment_submit').on('click', function(e) {
    var row_id = $(e.target).attr("data-id");
    var schema_name = $(e.target).attr("data-schema-name");
    var table_name = $(e.target).attr("data-table-name");
    var comment = $('#inputComment').val();

    // saved in case user goes to a different page, which may move these out of view
    var $comment_btn = $('#comment_' + row_id);
    var $loading_img = $('#comment_load_' + row_id);
    $comment_btn.hide();
    $loading_img.show();
    $.ajax({
      "type":     'POST',
      "url":      'tables/comment',
      "data":     'schema_name=' + schema_name + '&table_name=' + table_name + '&comment=' + comment,
      "dataType": "json",
      "cache":    false,
      "timeout":  45000,
      "success":  function () {
        // Update tooltip info in the table.
        $comment_btn.removeClass('fa-comment fa-comment-o')
        if (comment.length == 0) {
          $comment_btn.removeAttr('data-comment');
          $comment_btn.addClass('fa-comment-o');
          $comment_btn.parent().attr('title', '*Add a new table comment*');
        } else {
          $comment_btn.attr('data-comment', comment);
          $comment_btn.addClass('fa-comment');
          $comment_btn.parent().attr('title', comment);
        }
        $comment_btn.parent().tooltip('destroy');
        $comment_btn.parent().tooltip();
      },
      "error": function (req, textStatus, errorThrown) {
        var errorCause = errorThrown;
        if (req.responseJSON['error'])
          errorCause = req.responseJSON['error'];
        alert("Error submitting, reason: '" + errorCause + "'");
      },
      "complete": function () {
        $loading_img.hide();
        $comment_btn.show();
      }
    });
    $('#comment_modal').modal('hide');
    return false;
  });

  // Common code for modal submit forms. Should only be called from form elements.
  function asyncModalSubmitForm($form, targetURL) {
    if ($form.find('input.redshift_username_remember').is(':checked')) {
      Cookies.set('redshift_username', $form.find('input.redshift_username').val());
    }
    var $modal = $form.closest("div.modal");
    var $submit = $form.find('button[type=submit]');
    $submit.button('loading');
    $.ajax({
      "type"    : 'POST',
      "url"     : targetURL,
      "data"    : $form.serialize(),
      "dataType": "json",
      "cache"   : false,
      "timeout" : 45000,
      "error": function (req, textStatus, errorThrown) {
        alert("Error submitting, reason: '" + errorThrown + "'");
      },
      "complete": function () {
        $modal.modal('hide');
        $form.trigger('reset');
        $submit.button('reset');
        remember_redshift_username();
      }
    });
  }

  // Archive Table
  $('#archive_modal').on('show.bs.modal', function (event) {
    var button = $(event.relatedTarget);
    var schema = button.attr('data-schema-name');
    var table = button.attr('data-table-name');
    $(this).find('input[name=schema]').val(schema);
    $(this).find('input[name=table]').val(table);
  });
  $('#archiveForm').submit(function() {
    asyncModalSubmitForm($(this), 'tables/archive');
    return false;
  });

  // Restore Table
  $('#restore_modal').on('show.bs.modal', function (event) {
    var $button = $(event.relatedTarget);
    var schema = $button.attr('data-schema-name');
    var table = $button.attr('data-table-name');
    var bucket = $button.attr('data-bucket');
    var prefix = $button.attr('data-prefix');
    $(this).find('input[name=schema]').val(schema);
    $(this).find('input[name=table]').val(table);
    $(this).find('#restoreInputArchiveBucket').val(bucket);
    $(this).find('#restoreInputArchivePrefix').val(prefix);
  });
  $('#restoreForm').submit(function() {
    asyncModalSubmitForm($(this), 'tables/restore');
    return false;
  });

  // Regenerate Table
  $('#regenerate_modal').on('show.bs.modal', function (event) {
    var $button = $(event.relatedTarget);
    var schema = $button.attr('data-schema-name');
    $(this).find('input[name=schema]').val(schema);
    var table = $button.attr('data-table-name');
    $(this).find('input[name=table]').val(table);
    var distStyle = $button.attr('data-dist-style');
    var $targetDistStyle = $(this).find("input[name=distStyle][value=" + distStyle + "]");
    var $otherDistStyles = $(this).find("input[name=distStyle][value!=" + distStyle + "]");
    $targetDistStyle.change();
    $targetDistStyle.prop('checked', true);
    $targetDistStyle.parent().addClass('active');
    $otherDistStyles.prop('checked', false);
    $otherDistStyles.parent().removeClass('active');
    var distKey = $button.attr('data-dist-key');
    $(this).find('input[name=distKey]').val(distKey);
    var sortStyle = $button.attr('data-sort-style');
    var $targetSortStyle = $(this).find("input[name=sortStyle][value=" + sortStyle + "]");
    var $otherSortStyles = $(this).find("input[name=sortStyle][value!=" + sortStyle + "]");
    $targetSortStyle.change();
    $targetSortStyle.prop('checked', true);
    $targetSortStyle.parent().addClass('active');
    $otherSortStyles.prop('checked', false);
    $otherSortStyles.parent().removeClass('active');
    var sortKeys = $button.attr('data-sort-keys');
    $(this).find('input[name=sortKeys]').val(sortKeys);
    // Cannot select keepCurrent encodings if table doesn't have any encodings.
    var hasColEncodings = $button.attr('data-has-col-encodings') === 'true';
    var $keepCurrent = $(this).find('input[name=colEncode][value=keepCurrent]');
    var $recompute = $(this).find('input[name=colEncode][value=recompute]');
    if (hasColEncodings) {
      $keepCurrent.prop('disabled', false);
      $keepCurrent.parent().removeClass('disabled');
      $recompute.prop('checked', false);
      $recompute.parent().removeClass('active');
      $keepCurrent.prop('checked', true);
      $keepCurrent.parent().addClass('active');
    } else {
      $keepCurrent.prop('disabled', true);
      $keepCurrent.parent().addClass('disabled');
      $recompute.prop('checked', true);
      $recompute.parent().addClass('active');
      $keepCurrent.prop('checked', false);
      $keepCurrent.parent().removeClass('active');
    }
  });
  $('#regenerateForm').submit(function() {
    asyncModalSubmitForm($(this), 'tables/regenerate');
    return false;
  });

  // show/hide additional inputs on Regenerate modal
  $("input[type=radio][name=distStyle]").change(function() {
    var selector = $('#distKeySelection');
    var inp = $('#distKey');
    if (this.value == 'key') {
      selector.show();
      inp.attr('required', '');
      inp.attr('title', 'Input a single valid key.');
    } else {
      selector.hide();
      inp.removeAttr('required');
    }
  });
  $("input[type=radio][name=sortStyle]").change(function() {
    var selector = $('#sortKeySelection');
    var inp = $('#sortKeys');
    if (this.value == 'single') {
      selector.show();
      inp.attr('placeholder', 'key');
      inp.attr('required', '');
      inp.attr('title', 'Input a single valid key.');
    } else if (this.value == 'compound' || this.value == 'interleaved') {
      selector.show();
      inp.attr("placeholder", "key1, key2");
      inp.attr('required', '');
      inp.attr('title', 'Input a comma-separated list of valid keys.');
    } else {
      selector.hide();
      inp.removeAttr('required');
    }
  });

});
