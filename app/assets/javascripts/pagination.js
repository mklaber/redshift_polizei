//This function will paginate everything with the class "paginateMe"  
function paginate_stuff() {
    
    //We need to keep track of which page we're on and set a limit to number of rows per page
    var currentPage = 1;
    var rowLimit = 10;    
    
    //In the case of a page refresh, we merely want to update the pagination results and nothing else
    if(arguments.length > 0 && arguments[0] == true) {
        goToPage(currentPage);
        return;
    }
    
    //This will bring us to the correct page in the table
    function goToPage(pageNumber) {
        $('.paginateMe tr:not(:has(th))').hide();
        var rows = $('.paginateMe tr:not(:has(th))');
        var startIndex = (pageNumber-1)*rowLimit;
        for(var i = startIndex; i < startIndex + rowLimit; i++) {
            $(rows[i]).show();
        }
    }
    
    //We want to limit the number of rows we see in a table
    var tableRows = $('.paginateMe tr:not(:has(th))');
    for(var i = 0; i < tableRows.length; i++) {
        if(i >= rowLimit) {
            $(tableRows[i]).hide();
        }
    }
    
    //We also want a pagination at the bottom
    var numPages = Math.ceil(tableRows.length /rowLimit);
    var pageTabs = "<ul class='pagination'>";
    pageTabs = pageTabs + "<li class='disabled'><a id='fullBack' href='javascript:void(0);'> << </a></li>";
    pageTabs = pageTabs + "<li class='disabled'><a id='oneBack' href='javascript:void(0);'> < </a></li>";
    pageTabs = pageTabs + "<li class='disabled'>";
    pageTabs = pageTabs + "<a id='pageInfo' href='javascript:void(0);'>Page &nbsp;"+currentPage+" &nbsp; / &nbsp;"+numPages+"</a></li>";
    pageTabs = pageTabs + "<li><a id='oneFront' href='javascript:void(0);'> > </a></li>";
    pageTabs = pageTabs + "<li><a id='fullFront' href='javascript:void(0);'> >> </a></li>";
    pageTabs = pageTabs + "</ul>";
    $('.paginateMe').after(pageTabs);
    
    //We now add the onclick listeners so each pagination arrow does it's thing
    $(".pagination a").click(function() {
        //First, we make sure that this page navigation event isn't disabled
        var isDisabled = $(this).parent().attr("class") == "disabled";
        if(isDisabled) return;
        //Depending on the pagination arrow clicked, we update the page counter
        var id = $(this).attr("id");
        if(id == "fullBack") {
            currentPage = 1;
        }
        else if(id == "oneBack") {
            currentPage = currentPage - 1;
        }
        else if(id == "oneFront") {
            currentPage = currentPage + 1;
        }
        else {
            currentPage = numPages;
        }
        //We disable the page navigators if we reach either edge of the results
        if(currentPage == 1) {
            $("li:has(a#oneBack)").attr("class", "disabled");
            $("li:has(a#fullBack)").attr("class", "disabled");
            $("li:has(a#oneFront)").attr("class", "");
            $("li:has(a#fullFront)").attr("class", "");
        }
        else if(currentPage == numPages) {
            $("li:has(a#oneBack)").attr("class", "");
            $("li:has(a#fullBack)").attr("class", "");
            $("li:has(a#oneFront)").attr("class", "disabled");
            $("li:has(a#fullFront)").attr("class", "disabled");
        }
        else {
            $("li:has(a#oneBack)").attr("class", "");
            $("li:has(a#fullBack)").attr("class", "");
            $("li:has(a#oneFront)").attr("class", "");
            $("li:has(a#fullFront)").attr("class", "");
        }
        //We update the page results
        goToPage(currentPage);
        $("#pageInfo").text("Page " + currentPage + " / " + numPages);    
    });
} 




