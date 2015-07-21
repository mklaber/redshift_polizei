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
    var button = $(event.relatedTarget);
    var id = button.attr('data-id');
    var schema = button.attr('data-schema-name');
    var table = button.attr('data-table-name');
    var comment = button.attr('data-comment');
    var comment_el = $(this).find('input[name=comment]');
    var submit_button = $('#comment_submit');
    var label_el = $('#commentLabel');
    submit_button.attr('data-id', id);
    submit_button.attr('data-schema-name', schema);
    submit_button.attr('data-table-name', table);
    comment_el.val(comment);
    if (comment) {
      label_el.text("Edit Comment for " + schema + "." + table);
      submit_button.text("Confirm Edit");
    } else {
      label_el.text("New Comment for " + schema + "." + table);
      submit_button.text("Confirm Add");
    }
  });
  $('#comment_submit').on('click', function(e) {
    var row_id = $(e.target).attr("data-id");
    var schema_name = $(e.target).attr("data-schema-name");
    var table_name = $(e.target).attr("data-table-name");
    var comment = $('#inputComment').val();

    // saved in case user goes to a different page, which may move these out of view
    var comment_button = $('#comment_' + row_id);
    var loading_img = $('#comment_load_' + row_id);
    comment_button.hide();
    loading_img.show();
    $.ajax({
      "type":     'POST',
      "url":      'tables/comment',
      "data":     'schema_name=' + schema_name + '&table_name=' + table_name + '&comment=' + comment,
      "dataType": "json",
      "cache":    false,
      "timeout":  45000,
      "success":  function () {
        // Update tooltip info in the table.
        comment_button.removeClass('fa-comment fa-comment-o')
        if (comment.length == 0) {
          comment_button.removeAttr('data-comment');
          comment_button.addClass('fa-comment-o');
          comment_button.parent().attr('title', '*Add a new table comment*');
        } else {
          comment_button.attr('data-comment', comment);
          comment_button.addClass('fa-comment');
          comment_button.parent().attr('title', comment);
        }
        comment_button.parent().tooltip('destroy');
        comment_button.parent().tooltip();
        loading_img.hide();
        comment_button.show();
      },
      "error": function (req, textStatus, errorThrown) {
        loading_img.hide();
        comment_button.show();
        var errorCause = errorThrown;
        if (req.responseJSON['error'])
          errorCause = req.responseJSON['error'];
        alert("Error loading update, reason: '" + errorCause + "'");
      }
    });
    $('#comment_modal').modal('hide');
    return false;
  });

  // modal load up schema and table name
  $('#archive_modal').on('show.bs.modal', function (event) {
    var button = $(event.relatedTarget);
    var schema = button.attr('data-schema-name');
    var table = button.attr('data-table-name');
    $(this).find('input[name=schema]').val(schema);
    $(this).find('input[name=table]').val(table);
  });
  $('#restore_modal').on('show.bs.modal', function (event) {
    var button = $(event.relatedTarget);
    var schema = button.attr('data-schema-name');
    var table = button.attr('data-table-name');
    var bucket = button.attr('data-bucket');
    var prefix = button.attr('data-prefix');
    $(this).find('input[name=schema]').val(schema);
    $(this).find('input[name=table]').val(table);
    $(this).find('#restoreInputArchiveBucket').val(bucket);
    $(this).find('#restoreInputArchivePrefix').val(prefix);
  });
  $('#regenerate_modal').on('show.bs.modal', function (event) {
    var button = $(event.relatedTarget);
    var schema = button.attr('data-schema-name');
    $(this).find('input[name=schema]').val(schema);
    var table = button.attr('data-table-name');
    $(this).find('input[name=table]').val(table);
    var distStyle = button.attr('data-dist-style');
    $(this).find("input[name=distStyle][value=" + distStyle + "]").change();
    $(this).find("input[name=distStyle][value=" + distStyle + "]").prop('checked', true);
    $(this).find("input[name=distStyle][value=" + distStyle + "]").parent().addClass('active');
    $(this).find("input[name=distStyle][value!=" + distStyle + "]").prop('checked', false);
    $(this).find("input[name=distStyle][value!=" + distStyle + "]").parent().removeClass('active');
    var distKey = button.attr('data-dist-key');
    $(this).find('input[name=distKey]').val(distKey);
    var sortStyle = button.attr('data-sort-style');
    $(this).find("input[name=sortStyle][value=" + sortStyle + "]").change();
    $(this).find("input[name=sortStyle][value=" + sortStyle + "]").prop('checked', true);
    $(this).find("input[name=sortStyle][value=" + sortStyle + "]").parent().addClass('active');
    $(this).find("input[name=sortStyle][value!=" + sortStyle + "]").prop('checked', false);
    $(this).find("input[name=sortStyle][value!=" + sortStyle + "]").parent().removeClass('active');
    var sortKeys = button.attr('data-sort-keys');
    $(this).find('input[name=sortKeys]').val(sortKeys);
    // Cannot select keepCurrent encodings if table doesn't have any encodings.
    var hasColEncodings = button.attr('data-has-col-encodings') === 'true';
    if (hasColEncodings) {
      $(this).find('input[name=colEncode][value=keepCurrent]').prop('disabled', false);
      $(this).find('input[name=colEncode][value=keepCurrent]').parent().removeClass('disabled');
      $(this).find('input[name=colEncode][value=recompute]').prop('checked', false);
      $(this).find('input[name=colEncode][value=recompute]').parent().removeClass('active');
      $(this).find('input[name=colEncode][value=keepCurrent]').prop('checked', true);
      $(this).find('input[name=colEncode][value=keepCurrent]').parent().addClass('active');
    } else {
      $(this).find('input[name=colEncode][value=keepCurrent]').prop('disabled', true);
      $(this).find('input[name=colEncode][value=keepCurrent]').parent().addClass('disabled');
      $(this).find('input[name=colEncode][value=recompute]').prop('checked', true);
      $(this).find('input[name=colEncode][value=recompute]').parent().addClass('active');
      $(this).find('input[name=colEncode][value=keepCurrent]').prop('checked', false);
      $(this).find('input[name=colEncode][value=keepCurrent]').parent().removeClass('active');
    }
  });

  // modal submit buttons
  $('#archiveForm').submit(function () {
    if ($('#archiveRememberMe').is(':checked')) {
      Cookies.set('redshift_username', $('#archiveInputRedshiftUsername').val());
    }
    $('#archive_submit').button('loading');
  });
  $('#restoreForm').submit(function () {
    if ($('#restoreRememberMe').is(':checked')) {
      Cookies.set('redshift_username', $('#restoreInputRedshiftUsername').val());
    }
    $('#restore_submit').button('loading');
  });
  $('#regenerateForm').submit(function () {
    if ($('#regenerateRememberMe').is(':checked')) {
      Cookies.set('redshift_username', $('#regenerateInputRedshiftUsername').val());
    }
    $('#regenerate_submit').button('loading');
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
