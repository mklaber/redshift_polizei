//This function will paginate everything with the class "paginateMe"  
function paginate_stuff() {
        
    //This will bring us to the correct page in the table
    function goToPage(pageNumber) {
        $('.paginateMe tr:not(:has(th))').hide();
        var startIndex = (pageNumber-1)*rowLimit;
        for(var i = startIndex; i < startIndex + rowLimit; i++) {
            $(tableRows[i]).show();
        }
    }
    
    //We need to keep track of which page we're on and set a limit to number of rows per page
    var currentPage = 1;
    var rowLimit = 10;    
    
    //We want to limit the number of rows we see in a table
    var tableRows = $('.paginateMe tr:not(:has(th))');
    for(var i = 0; i < tableRows.length; i++) {
        if(i >= rowLimit) {
            $(tableRows[i]).hide();
        }
    }
    
    //We also want a pagination at the bottom
    var numPages = Math.ceil(tableRows.length /rowLimit);
    var pageTabs = "<div class='pageTabber'>";
    pageTabs = pageTabs + "<a class='pageNav' id='fullBack' href='javascript:void(0);'> << </a>";
    pageTabs = pageTabs + "<a class='pageNav' id='oneBack' href='javascript:void(0);'> < </a>";
    pageTabs = pageTabs + "Page &nbsp;" + "<span id='pageNumber'>" + currentPage + "</span> &nbsp; / &nbsp;" + numPages;
    pageTabs = pageTabs + "<a class='pageNav' id='oneForward' href='javascript:void(0);'> > </a>";
    pageTabs = pageTabs + "<a class='pageNav' id='fullForward' href='javascript:void(0);'> >> </a>";
    pageTabs = pageTabs + "</div>";
    $('.paginateMe').after(pageTabs);
    
    //We now add the onclick listeners so each pagination arrow does it's thing
    $(".pageTabber a").click(function() {
        var id = $(this).attr("id");
        if(id == "fullBack") {
            currentPage = 1;
        }
        else if (id == "oneBack") {
            if(currentPage != 1) {
                currentPage = currentPage - 1;
            }
        }
        else if (id == "fullForward") {
            currentPage = numPages;
        }
        else {
            if(currentPage != numPages) {
                currentPage = currentPage + 1;
            }
        }
        goToPage(currentPage);
        $(".pageTabber #pageNumber").text(currentPage);    
    });
} 














