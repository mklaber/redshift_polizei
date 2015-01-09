function scrollToSelector(selector){
  var aTag = $(selector);
  $('html,body').animate({ scrollTop: aTag.offset().top }, 'slow');
}

$(document).ready(function() {
  $('table#jobs > tbody > tr').click(function() {
    window.document.location = $(this).attr("href");
  });
  $('input#inputExportOption').val(
    $('#export_options > li.export_option.active').text().toLowerCase()
  );
  // set flag to immediately execute job if corresponding button is pressed
  $('button#submitjob').click(function() {
    $('input#inputExecute').val(1);
  });

  $('#export_options > li.export_option').click(function(e) {
    /*
     * retrieves the tab dom element and searches the content container based on that:
     * - text of link says "CSV"
     * - export container has to have id '#export_option_csv'
     */
    var export_option = $(e.target).text();
    var prev_tab = $('#export_options > li.export_option.active');
    var new_tab  = $(e.target).parent();
    var prev_tab_container = $('#export_option_' + prev_tab.text().toLowerCase());
    var new_tab_container  = $('#export_option_' + new_tab.text().toLowerCase());
    prev_tab_container.hide();
    prev_tab.removeClass('active');
    new_tab.addClass('active');
    new_tab_container.show();
    // write the value into our hidden field so that we know what to export
    $('input#inputExportOption').val(new_tab.text().toLowerCase());
  });

  // test query button functionality
  $('button#testjob').click(function() {
    $('table#querytest').hide();
    if ($('table#querytest').hasClass('init')) {
      $('table#querytest').dataTable().fnDestroy();
      $('#querytest > thead > tr').empty();
      $('#querytest > tbody').empty();
    }
    $('#querytest_loading').show();
    scrollToSelector('#querytest_loading');

    $.ajax({
      "type":     'POST',
      "url":      '/query/test',
      "data":     {
        draw: 0,
        redshift: {
          username: $('#inputRedshiftUsername').val(),
          password: $('#inputRedshiftPassword').val()
        },
        query: $('#inputSQL').val()
      },
      "dataType": 'json',
      "cache":    false,
      "timeout":  90000,
      "success":  function (json, textStatus, req) {
        if (json['error']) {
          $('#querytest_loading').hide();
          alert(json['error']);
          return;
        }

        var columnDefs = [];
        for (var i = 0; i < json['columns'].length; i++) {
          $('#querytest > thead > tr').append('<th>' + json['columns'][i] + '</th>');
          columnDefs.push({ orderable: false, searchable: false, targets: i })
        }

        $('table#querytest').dataTable({
          "pageLength": 100,
          "ordering":   false,
          "searching":  false,
          "paging":     false,
          "aaSorting":  [],
          "processing": true,
          "serverSide": true,
          "columnDefs": columnDefs,
          "ajax":       $.fn.dataTable.pipeline(
          {
            method:    'POST',
            url:       '/query/test',
            pages:     5,
            data:      { query: $('#inputSQL').val() },
            cacheInit: json
          })
        });
        $('#querytest_info').text($('#querytest_info').text().replace(/\d+ entries/, "an unknown number of entries"));
        $('#querytest_loading').hide();
        $('table#querytest').show();
        $('table#querytest').addClass('init');
        scrollToSelector('#querytest');
      },
      "error":    function (req, textStatus, errorThrown) {
        $('#querytest_loading').hide();
        alert("Error loading query results, reason: '" + textStatus + "'");
      }
    });
  });
});
