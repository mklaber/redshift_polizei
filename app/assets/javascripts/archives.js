$(document).ready(function() {
  // archive modal load up schema and table name
  $('#restore_modal').on('show.bs.modal', function (event) {
    var button = $(event.relatedTarget);
    var schema = button.attr('data-schema-name');
    var table = button.attr('data-table-name');
    $('#inputSchema').val(schema);
    $('#inputTable').val(table);
  });

  // focus input when modal is shown
  $('#restore_modal').on('shown.bs.modal', function () {
    $('#inputRedshiftUsername').focus();
  });

  // hide modal after submitting form
  $('#restoreForm').submit(function () {
    $('#restore_modal').modal('hide')
  });

});
