// exact formatting of a moment.js duration object
moment.duration.fn.format = function(){
    var str = "";
    if (this.days() > 0) str = str + Math.floor(this.days()) + " d ";
    if (this.hours() > 0) str = str + Math.floor(this.hours()) + " h ";
    if (this.minutes() > 0) str = str + Math.floor(this.minutes()) + " min ";
    str = str + Math.floor(this.seconds()) + " sec ";
    return str;
}

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
                "timeout":  90000,
                "success":  function (json, textStatus, req) {
                    cacheLastJson = $.extend(true, {}, json);

                    if (cacheLower != drawStart) {
                        json.data.splice(0, drawStart - cacheLower);
                    }
                    json.data.splice(requestLength, json.data.length);

                    drawCallback(json);
                },
                "error": function (req, textStatus, errorThrown) {
                    var error = errorThrown;
                    var responseBody = $.parseJSON(req.responseText);
                    if (responseBody['error'])
                        error = responseBody['error'];
                    var errorContainer = 'div#' + settings.sTableId + '_processing';
                    var errorMsg = "Error loading table data, reason: '" + error + "'";
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
        url: '',      // script url
        method: 'GET' // Ajax HTTP method
    }, opts);

    return function (request, drawCallback, settings) {
        $.ajax({
            "type":     conf.method,
            "url":      conf.url,
            "data":     request,
            "dataType": "json",
            "cache":    false,
            "timeout":  30000,
            "success":  function (json, textStatus, req) {
                drawCallback(json);
            },
            "error": function (req, textStatus, errorThrown) {
                var error = errorThrown;
                var responseBody = $.parseJSON(req.responseText);
                if (responseBody['error'])
                    error = responseBody['error'];
                var errorContainer = 'table#' + settings.sTableId + ' td.dataTables_empty';
                var errorMsg = "Error loading table data, reason: '" + error + "'";
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

function datatable_update_size() {
    $.each($('table.dataTable'), function(idx, table) {
        $(table).css({ width: $(table).parent().width() });
    });
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

    // modify search box
    var table_id = $(table).attr('id');
    var filterContainer = $('div#' + table_id + '_filter');
    var searchBox = $('div#' + table_id + '_filter input');
    searchBox.unbind(); // remove default action
    searchBox.bind('keyup', function (e) {
        if (e.keyCode == 13) { // search when enter is pressed
            $(table).DataTable().search(this.value).draw();
        }
    });
    // insert new search button
    var searchButton = $('<button type="button" class="btn btn-primary btn-sm" style="margin-left: 5px;">Search</button>');
    filterContainer.append(searchButton);
    searchButton.click(function (e) {
        $(table).DataTable().search(searchBox.val()).draw();
    });
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
    var options = null
    if($(table).attr('complex-search')=='true'){
        $.fn.dataTable.ext.type.order['complex-table-pre'] = function ( d ) {
            regex = new RegExp('<a .*>(.*)</a>');
            value = regex.exec(d);
            return (value != null && value.length >= 2)?value[1]:null;
        };
        options = {
            "columnDefs": [ {
                "type": "complex-table",
                "targets": 1
            } ]
        };
    }
    else{
        options = {
           'aaSorting': []
        }
    }
    $.extend(options, user_options);
    $(table).dataTable(options);

    var table_id = $(table).attr('id');
    var filterContainer = $('div#' + table_id + '_filter label');
    var searchBox = $('div#' + table_id + '_filter input');
    var cfilter = $('<span class="label label-default" style="position: relative; left: 195px;">RegEx</span>');
    filterContainer.prepend(cfilter);

    searchBox.unbind();
    searchBox.on('keyup click', function () {
        var search_term = $(this).val();
        $(table).DataTable().search(
            search_term,
            regex_is_valid(search_term), // only use as regex if valid
            true
        ).draw();
    });
}

// 'remember me' for redshift usernames
function remember_redshift_username() {
    $('.redshift_username').val(Cookies.get('redshift_username'));
}

$(document).ready(function() {
    // every bootstrap table is going to be a data table
    $.each($('table.table'), function(idx, table) {
        if ($(table).attr('data-auto'))
            datatable_init(table);
    });
    // datatables need to be resized when window is resized
    $(window).resize(function() {
        clearTimeout(window.refresh_size);
        window.refresh_size = setTimeout(function() { datatable_update_size(); }, 250);
    });
    // when shown, modal focus gets set to the first input
    $('.modal').on('shown.bs.modal', function () {
        $(this).find('form').find('input:visible:not([readonly]):first').select();
    });
    remember_redshift_username();
});
