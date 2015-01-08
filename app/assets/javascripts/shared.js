$.fn.dataTable.pipeline = function (opts) {
    // Configuration options
    var conf = $.extend({
        pages: 5,     // number of pages to cache
        url: '',      // script url
        data: null,   // function or object with parameters to send to the server
                      // matching how `ajax.data` works in DataTables
        method: 'GET',// Ajax HTTP method
        cacheInit: null
    }, opts);

    // Private variables for storing the cache
    var cacheLower = -1;
    var cacheUpper = null;
    var cacheLastRequest = null;
    var cacheLastJson = null;
    var requestImmutable = false;
    if (conf.cacheInit != null) {
        requestImmutable = true;
        cacheLower = 0;
        cacheUpper = conf.cacheInit['data'].length;
        cacheLastJson = conf.cacheInit;
    }

    return function (request, drawCallback, settings) {
        var ajax          = false;
        var requestStart  = request.start;
        var drawStart     = request.start;
        var requestLength = request.length;
        var requestEnd    = requestStart + requestLength;

        if (settings.clearCache) {
            // API requested that the cache be cleared
            ajax = true;
            settings.clearCache = false;
        } else if (cacheLower < 0 || requestStart < cacheLower || requestEnd > cacheUpper) {
            // outside cached data - need to make a request
            ajax = true;
        } else if (!requestImmutable &&
               (JSON.stringify(request.order)   !== JSON.stringify(cacheLastRequest.order)   ||
                JSON.stringify(request.columns) !== JSON.stringify(cacheLastRequest.columns) ||
                JSON.stringify(request.search)  !== JSON.stringify(cacheLastRequest.search))) {
            // properties changed (ordering, columns, searching)
            ajax = true;
        }

        // Store the request for checking next time around
        cacheLastRequest = $.extend(true, {}, request);

        if (ajax) {
            // Need data from the server
            if (requestStart < cacheLower) {
                requestStart = requestStart - (requestLength * (conf.pages - 1));

                if (requestStart < 0) {
                    requestStart = 0;
                }
            }

            cacheLower = requestStart;
            cacheUpper = requestStart + (requestLength * conf.pages);

            request.start = requestStart;
            request.length = requestLength * conf.pages;

            // Provide the same `data` options as DataTables.
            if ($.isFunction (conf.data)) {
                // As a function it is executed with the data object as an arg
                // for manipulation. If an object is returned, it is used as the
                // data object to submit
                var d = conf.data(request);
                if (d) {
                    $.extend(request, d);
                }
            } else if ($.isPlainObject( conf.data)) {
                // As an object, the data given extends the default
                $.extend(request, conf.data);
            }

            settings.jqXHR = $.ajax({
                "type":     conf.method,
                "url":      conf.url,
                "data":     request,
                "dataType": "json",
                "cache":    false,
                "timeout":  30000,
                "success":  function (json, textStatus, req) {
                    cacheLastJson = $.extend(true, {}, json);

                    if (cacheLower != drawStart) {
                        json.data.splice(0, drawStart - cacheLower);
                    }
                    json.data.splice(requestLength, json.data.length);

                    drawCallback(json);
                },
                "error": function (req, textStatus, errorThrown) {
                    var errorContainer = 'div#' + settings.sTableId + '_processing';
                    var errorMsg = "Error loading table date, reason: '" + textStatus + "'";
                    $(errorContainer).text(errorMsg);
                }
            });
        } else {
            // already cached, no ajax request necessary
            json = $.extend(true, {}, cacheLastJson);
            json.draw = request.draw; // Update the echo for each response
            json.data.splice(0, requestStart - cacheLower);
            json.data.splice(requestLength, json.data.length);

            drawCallback(json);
        }
    }
};

// Register an API method that will empty the pipelined data, forcing an Ajax
// fetch on the next draw (i.e. `table.clearPipeline().draw()`)
$.fn.dataTable.Api.register('clearPipeline()', function () {
    return this.iterator('table', function (settings) {
        settings.clearCache = true;
    });
});

$.fn.dataTable.ajaxload = function (opts) {
    // Configuration options
    var conf = $.extend({
        pages: 5,     // number of pages to cache
        url: '',      // script url
        data: null,   // function or object with parameters to send to the server
                      // matching how `ajax.data` works in DataTables
        method: 'GET' // Ajax HTTP method
    }, opts);

    return function (request, drawCallback, settings) {
        $.ajax({
            "type":     conf.method,
            "url":      conf.url,
            "data":     request,
            "dataType": "json",
            "cache":    false,
            "timeout":  15000,
            "success":  function (json, textStatus, req) {
                drawCallback(json);
            },
            "error": function (req, textStatus, errorThrown) {
                var errorContainer = 'table#' + settings.sTableId + ' td.dataTables_empty';
                var errorMsg = "Error loading table date, reason: '" + textStatus + "'";
                $(errorContainer).text(errorMsg);
            }
        });
    };
};

function regex_is_valid(regex) {
    try {
        new RegExp(regex);
        return true;
    } catch(e) {
        return false;
    }
}

function datatable_init(table, options) {
    if($(table).attr('data-server'))
        datatable_server_init(table, options);
    else if($(table).attr('data-ajax'))
        datatable_ajax_init(table, $(table).attr('data-ajax'), options);
    else if ($(table).attr('data-auto'))
        datatable_client_init(table, options);
    $(table).show();
}

function datatable_server_init(table, options) {
    var wl = window.location;
    var table_data_url = wl.protocol + '//' + wl.host + wl.pathname + '/table' + wl.search;
    options = options || {};
    $.extend(options, {
        "aaSorting": [],
        "processing": true,
        "serverSide": true,
        "ajax": $.fn.dataTable.pipeline({
            url: table_data_url,
            pages: 5 // number of pages to cache
        })
    });
    $(table).dataTable(options);
}

function datatable_ajax_init(table, url, options) {
    options = options || {};
    $.extend(options, {
        'ajax': $.fn.dataTable.ajaxload({
            url: url,
        })
    });
    datatable_client_init(table, options);
}

function datatable_client_init(table, user_options) {
    options = { 'dom': 'lrtip', 'aaSorting': [] };
    $.extend(options, user_options);
    $(table).dataTable(options);
    var table_id = $(table).attr('id');
    var wrapper_id = "div#" + table_id + "_wrapper";
    var length_id = "div#" + table_id + "_length";
    var info_id = "div#" + table_id + "_info";
    var paginate_id = "div#" + table_id + "_paginate";
    // fix bootstrap table style with custom dom option
    $(wrapper_id).css('overflow', 'auto');
    $(length_id).css('float', 'left');
    $(info_id).css('float', 'left');
    $(paginate_id).css('float', 'right');
    // create custom filter input field
    var filter_id = table_id + "_customfilter";
    var cfilter = $('<div id="' + filter_id + '" class="dataTables_filter">' +
            '<label>' +
                '<span class="label label-default" style="position: relative; left: 195px;">RegEx</span>' +
                'Search:' +
                '<input ' +
                    'type="search" ' +
                    'class="form-control input-sm" ' +
                    'placeholder="" ' +
                    'aria-controls="' + table_id + '">' +
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
}

$(document).ready(function() {
    // every bootstrap table is going to be a data table
    $.each($('table.table'), function(idx, table) {
        if ($(table).attr('data-auto'))
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
                timeout:  15000,
                beforeSend:function(){
                    results.html('<br>Loading....<br><br>'); 
                },
                success:function(data) {
                    
                    //Lets parse the json object and remove any old results
                    data = JSON.parse(data);
                    results.empty();
                    
                    //We create our nifty table to hold results
                    var table = document.createElement("table");
                    $(table).attr('data-auto', 'true');
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
                },
                "error": function (req, textStatus, errorThrown) {
                    results.empty();
                    alert("Error loading permissions, reason: '" + textStatus + "'");
                }
            });
        return false;
	});
});
