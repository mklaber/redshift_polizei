$(document).ready(function() {
    
    //We want the first tab in the permissions page to be on by default
    $('div#users').show();
    
    //When we select one of the tabs within the permissions page, we want
    //the correct menu to pop up on screen
    $('ul#navigation li').click(
        function() {
            $('ul#navigation li.selected').removeClass('selected');
            $(this).addClass('selected');
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
            var permissionType = $('#'+id+'_permissions_dd option:selected').attr('id');
            var results = $('div#access_results');
            results.show();
            
            $.ajax({
                type: 'GET',
                url: '/permissions/' + id,
                data: { "value": selected, "permission_type": permissionType },
                beforeSend:function(){
                    results.html('<br>Loading....<br><br>'); 
                },
                success:function(data) {
                    data = JSON.parse(data);
                    results.empty();
                    results.append('<p><b>Here are the results: </b></p><ul>');
                    for(var i = 0; i < data.length; i++) {
                        results.append("<li>"+data[i]);
                    }
                    results.append('</ul>');  
                }
            });
	});
});
