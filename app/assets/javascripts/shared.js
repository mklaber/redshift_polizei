$(document).ready(function() {
    
    //We want the first tab in the permissions page to be on by default
    $('div#users').show();
    
    //When we select one of the tabs within the permissions page, we want
    //the correct menu to pop up on screen
    $('ul#navigation li').click(
        function() {
            $('ul#navigation li.selected').removeClass('bg-primary');
            $('ul#navigation li.selected').removeClass('selected');
            $(this).addClass('selected');
            $(this).addClass('bg-primary');
            var id = $(this).attr('id');
            $('div.permissions_content div').hide();
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
                    $(table).addClass("table table-striped");
                    
                    //We create the column headers first
                    var p_types = ["Delete", "Select", "Insert", "References", "Update"];
                    var new_row = "<tr><td>Value</td>" ;
                    for(var i = 0; i < p_types.length; i++) {
                        new_row = new_row + "<td>" + p_types[i] + "</td>";           
                    }
                    new_row = new_row + "</tr>";
                    $(table).append(new_row);
                    
                    //Now we append the results of our query
                    for(var i = 0; i < data.length; i++) {
                        new_row = "<tr>";
                        new_row = new_row + "<td>" + data[i]["value"] + "</td>";
                        new_row = new_row + "<td>" + data[i]["has_delete"] + "</td>";
                        new_row = new_row + "<td>" + data[i]["has_select"] + "</td>";
                        new_row = new_row + "<td>" + data[i]["has_insert"] + "</td>";
                        new_row = new_row + "<td>" + data[i]["has_references"] + "</td>";
                        new_row = new_row + "<td>" + data[i]["has_update"] + "</td>";
                        new_row = new_row + "</tr>";
                        $(table).append(new_row);
                    }
                    
                    results.append(table);  
                }
            });
	});
});
