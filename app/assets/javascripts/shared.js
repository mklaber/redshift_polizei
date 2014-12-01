function regex_is_valid(regex) {
    try {
        new RegExp(regex);
        return true;
    } catch(e) {
        return false;
    }
}

function datatable_init(table) {
    $(table).dataTable({
        'dom': 'lrtip'
    });
    var table_id = $(table).attr('id');
    var table_no = table_id.substr(table_id.lastIndexOf("_") + 1);
    var wrapper_id = "div#DataTables_Table_" + table_no + "_wrapper";
    var length_id = "div#DataTables_Table_" + table_no + "_length";
    var info_id = "div#DataTables_Table_" + table_no + "_info";
    var paginate_id = "div#DataTables_Table_" + table_no + "_paginate";
    // fix bootstrap table style with custom dom option
    $(wrapper_id).css('overflow', 'auto');
    $(length_id).css('float', 'left');
    $(info_id).css('float', 'left');
    $(paginate_id).css('float', 'right');
    // create custom filter input field
    var filter_id = "DataTables_Table_" + table_no + "_customfilter";
    var cfilter = $('<div id="' + filter_id + '" class="dataTables_filter">' +
            '<label>Search:' +
                '<input ' +
                    'type="search" ' +
                    'class="form-control input-sm" ' +
                    'placeholder="" ' +
                    'aria-controls="DataTables_Table_' + table_no + '">' +
            '</label>' +
        '</div>');
    cfilter.insertAfter($(length_id));

    $('div#' + filter_id + ' input').on('keyup click', function () {
        var search_term = $(this).val();
        $(table).DataTable().search(
            search_term,
            regex_is_valid(search_term), // only use as regex if valid
            true
        ).draw();
    });
    $('table.table').show();
}

$(document).ready(function() {
    // every bootstrap table is going to be a data table
    $('table.table').each(function(table) {
        datatable_init(table);
    });

    //We want the first tab in the permissions page to be on by default
    $('div#users').show();
    
    //When we select one of the tabs within the permissions page, we want
    //the correct menu to pop up on screen
    $('ul#navigation li').click(
        function() {
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
       
    //Whenever we click the get permissions button, we send an ajax request to
    //get 1) users with permissions to a table 
    //or 2) tables that a user has access to
    //or 3) tables that a group has access to   
	$('.permissions_button').click(
        function(e) {
            
            var id = $(this).attr('id');
            var selected = $('#'+id+'_dd option:selected').attr('id');
            var results = $('div#access_results');
            results.show();
            
            $.ajax({
                type: 'GET',
                url: '/permissions/' + id,
                data: { "value": selected },
                beforeSend:function(){
                    results.html('<br>Loading....<br><br>'); 
                },
                success:function(data) {
                    
                    //Lets parse the json object and remove any old results
                    data = JSON.parse(data);
                    results.empty();
                    
                    //We create our nifty table to hold results
                    var table = document.createElement("table");
                    $(table).addClass("table table-bordered table-striped table-condensed table-hover");
                    
                    //We create the column headers first
                    var p_types = ["Delete", "Select", "Insert", "References", "Update"];
                    var new_row = "<thead><tr><th>Value</th>" ;
                    for(var i = 0; i < p_types.length; i++) {
                        new_row = new_row + "<th>" + p_types[i] + "</th>";           
                    }
                    new_row = new_row + "</tr></thead>";
                    $(table).append(new_row);
                    
                    //Now we append the results of our query
                    var revoked = "<td><span class=\"label label-danger\">No</span></td>";
                    var granted = "<td><span class=\"label label-success\">Yes</span></td>";
                    for(var i = 0; i < data.length; i++) {
                        new_row = "<tr>";
                        new_row += "<td>" + data[i]["value"] + "</td>";
                        new_row += (data[i]["has_delete"] ? granted : revoked);
                        new_row += (data[i]["has_select"] ? granted : revoked);
                        new_row += (data[i]["has_insert"] ? granted : revoked);
                        new_row += (data[i]["has_references"] ? granted : revoked);
                        new_row += (data[i]["has_update"] ? granted : revoked);
                        new_row += "</tr>";
                        $(table).append(new_row);
                    }
                    
                    results.append(table);
                    datatable_init(table);
                }
            });
        return false;
	});
});
