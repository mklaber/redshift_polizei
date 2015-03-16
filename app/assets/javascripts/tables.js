$(document).ready(function() {
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
        $('div.modal').modal('toggle');
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
  })
});
