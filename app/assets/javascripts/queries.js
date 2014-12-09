datatable_init($('#queries_running_tbl')[0], {
  'columnDefs': [
    {
      'targets': 0,
      'render': function (data, type, row) {
        return row['username'] + '<small class="secondary"> (' + row['user_id'] + ')</small>';
      }
    },
    {
      'targets': 1,
      'data': 'status'
    },
    {
      'targets': 2,
      'render': function(data, type, row) {
        var date = $.format.date(row['start_time'], 'dd.MM.yy');
        var time = $.format.date(row['start_time'], 'HH:mm:ss');
        return date + ' at ' + time + ' UTC';
      }
    },
    {
      'targets': 3,
      'render': function(data, type, row) {
        var duration;
        if (row['duration']) {
          duration = row['duration'];
        } else {
          duration = (new Date().getTime() / 1000) - row['start_time'];
        }
        if (duration < 0) duration = 0;
        var mins = Math.round(duration / 60);
        var secs = Math.round(duration % 60);
        if (mins > 0)
          return mins + ' min ' + secs + ' sec';
        else
          return secs + ' sec';
      }
    },
    {
      'targets': 4,
      'data': 'xid'
    },
    {
      'targets': 5,
      'data': 'query'
    }
  ]
});
