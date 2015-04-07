$(document).ready(function() {
  datatable_init($('#auditlog_tbl')[0], {
    'dom': "<'row'<'col-sm-6'><'col-sm-6'f>><'row'<'col-sm-6'l><'col-sm-6'p>><'row'<'col-sm-12'tr>><'row'<'col-sm-6'i><'col-sm-6'p>>",
    'columnDefs': [
      {
        'targets': 0,
        'render': function(data, type, row) {
          return moment(row['record_time'], "X").format("MM/DD/YYYY HH:mm:ss a");
        }
      },
      {
        'targets': 1,
        'render': function (data, type, row) {
          return row['user'] + '<small class="secondary"> (' + row['userid'] + ')</small>';
        }
      },
      {
        'targets': 2,
        'data': 'xid'
      },
      {
        'targets': 3,
        'data': 'query'
      }
    ]
  });
});
