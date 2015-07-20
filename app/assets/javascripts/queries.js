$(document).ready(function() {
  datatable_init($('#queries_recent_tbl')[0], {
    'createdRow': function (row, data, index) {
      if (data['status'] == 'Running')
        $(row).addClass('running');
    },
    'columnDefs': [
      {
        'targets': 0,
        'render': function (data, type, row) {
          return row['username'] + '<small class="secondary"> (' + row['user_id'] + ')</small>';
        }
      },
      {
        'targets': 1,
        'render': function(data, type, row) {
          var start_moment = moment(row['start_time'], "X");
          var absolute = $('<span/>').addClass('absolute').text(start_moment.format("MM/DD, HH:mm:ss a")).hide();
          var relative = $('<span/>').addClass('relative').text(start_moment.fromNow());
          var container = $('<span/>').addClass('abs_rel').attr('title', absolute.text());
          container.append(absolute);
          container.append(relative);
          return container[0].outerHTML;
        }
      },
      {
        'targets': 2,
        'render': function(data, type, row) {
          if (row['status'] == 'Running') {
            return '<i class="fa fa-cogs orange"></i>';
          } else if (row['status'] == 'Completed') {
            return '<i class="fa fa-check-circle green"></i>';
          } else {
            return row['status'];
          }
        }
      },
      {
        'targets': 3,
        'render': function(data, type, row) {
          var duration;
          if (row['status'] == 'Completed') {
            duration = row['end_time'] - row['start_time'];
          } else {
            duration = (new Date().getTime() / 1000) - row['start_time'];
          }
          if (duration < 0) duration = 0;

          var duration_moment = moment.duration(duration, 'seconds');
          var absolute = $('<span/>').addClass('absolute').text(duration_moment.format()).hide();
          var relative = $('<span/>').addClass('relative').text(duration_moment.humanize());
          var container = $('<span/>').addClass('abs_rel').attr('title', absolute.text());
          container.append(absolute);
          container.append(relative);
          return container[0].outerHTML;
        }
      },
      {
        'targets': 4,
        'data': 'pid'
      },
      {
        'targets': 5,
        'data': 'query'
      }
    ]
  });

  // absolute/relative time display code
  function abs_rel_toggle() {
    $(this).find('span.absolute').toggle();
    $(this).find('span.relative').toggle();
  }
  $('#queries_recent_tbl').on('init.dt', function() {
    $('table#queries_recent_tbl tbody').on('click', 'tr > td:nth-child(2)', abs_rel_toggle);
    $('table#queries_recent_tbl tbody').on('click', 'tr > td:nth-child(4)', abs_rel_toggle);
  });
  $('#queries_recent_tbl').on('draw.dt', function() {
    $('.abs_rel').tooltip();
  });
});

// cpu utilization gauge
google.load("visualization", "1", {packages:["gauge"]});
google.setOnLoadCallback(drawChart);

function drawChart() {
  var data = google.visualization.arrayToDataTable([
    ['Label', 'Value'],
    ['Leader', 0.0],
    ['Computes', 0.0]
  ]);

  var options = {
    width: 400, height: 120,
    redFrom: 90, redTo: 100,
    yellowFrom: 75, yellowTo: 90,
    minorTicks: 5
  };
  var chart = new google.visualization.Gauge(document.getElementById('chart_div'));
  chart.draw(data, options);

  $.ajax({
    "type":     'GET',
    "url":      '/cluster/status',
    "dataType": "json",
    "cache":    false,
    "timeout":  10000,
    "success":  function (json, textStatus, req) {
      data.setValue(0, 1, json['cpu'][['leader']]);
      data.setValue(1, 1, json['cpu'][['computes']]);
      chart.draw(data, options);
    },
    "error": function (req, textStatus, errorThrown) {
      var error = errorThrown;
      var responseBody = $.parseJSON(req.responseText);
      if (responseBody['error'])
          error = responseBody['error'];
      console.log('error: ' + error);
    }
  });
}
