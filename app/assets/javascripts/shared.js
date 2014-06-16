
function viewPermissionChange()
{
	var tableName = $('select#table_name_dd option:selected').val();
	var permissionType = $('select#permission_type_dd option:selected').val();
	$.ajax({
  		type: 'GET',
  		url: '/permissions',
  		data: { "table_name": tableName, "permission_type": permissionType },
		beforeSend:function(){
    		$('div#users_with_access').html('<img src="/images/loading.gif" alt="Loading..." />');
  		},
		success:function(data) {
			$("div#users_with_access").empty();
			var users = JSON.parse(data);
			for(var i = 0; i < users.length; i++) {
				var user = users[i];
				$("div#users_with_access").append("<i>" + user + "</i><br>");
			}
		}
	});
}



