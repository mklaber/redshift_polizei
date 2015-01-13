$(document).ready(function() {
  $('button.tbl-update').click(function(e) {
    var tableid = $(e.target).attr("data-id");
    $('button#update_button_' + tableid).hide();
    $('img#loading_img_' + tableid).show();
    $.ajax({
      "type":     'GET',
      "url":      'tables/report',
      "data":     'tableid=' + tableid,
      "dataType": "json",
      "cache":    false,
      "timeout":  35000,
      "success":  function (json) {
        json_sort_keys = JSON.parse(json['sort_keys']);
        var dTable = $('table#tablereports').dataTable();

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
            sort_keys += ', ';
            if (i == 0)
              sort_keys += '<span class="label label-primary">' + json_sort_keys[i] + '</span>';
            else
              sort_keys += '<span class="label label-info">' + json_sort_keys[i] + '</span>';
          }
          sort_keys = sort_keys.substring(2);
        }
        if (json['dist_key'] && json['dist_key'] == json_sort_keys[0])
          dist_key = '<span class="label label-primary">' + json['dist_key'] + '</span>';
        else if (json['dist_key'] && json['dist_key'] != json_sort_keys[0])
          dist_key = '<span class="label label-info">' + json['dist_key'] + '</span>';
        else
          dist_key = '<span class="label label-danger">None!</span>';
        if (json['dist_style'])
          dist_key += '<br /><span class="label label-primary">' + json["dist_style"]+ ' distribution</span>';
        else
          dist_key += '<br /><span class="label label-danger">unknown distribution</span>';
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

        var row = $(e.target).parent().parent();
        dTable.fnUpdate(size, row, 2, false, false);
        dTable.fnUpdate(sort_keys, row, 3, false, false);
        dTable.fnUpdate(dist_key, row, 4, false, false);
        dTable.fnUpdate(col_encoding, row, 5, false, false);
        dTable.fnUpdate(skew, row, 6, false, false);
        dTable.fnUpdate(slices_populated, row, 7, false, false);

        $('button#update_button_' + tableid).show();
        $('img#loading_img_' + tableid).hide();
      },
      "error": function (req, textStatus, errorThrown) {
        $('button#update_button_' + tableid).show();
        $('img#loading_img_' + tableid).hide();
        alert("Error loading update, reason: '" + textStatus + "'");
      }
    });
    return false;
  })
});
