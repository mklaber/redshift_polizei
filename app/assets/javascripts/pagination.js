//This function will paginate everything with the class "paginateMe"  
function paginate_stuff() {
    
    //Synchronizes the bottom and top navigation bars hackishly
    function syncPageNavs() {
        var pageNavs  = $(".pagination").get();
        $(pageNavs[1]).remove();
        $(".paginateMe").after($(pageNavs[0]).clone());
        $(".pageTab").unbind();
        $(".pageTab").click(pageTabClickListener);
        $(".arrowNav").unbind();
        $(".arrowNav").click(arrowClickListener);
    }
    
    //This will bring us to the correct page in the table
    function goToPage(currentPage, pageRequested) {
        
        $('.paginateMe tr:not(:has(th))').hide();
        var rows = $('.paginateMe tr:not(:has(th))');
        var startIndex = (pageRequested-1)*rowLimit;
        for(var i = startIndex; i < startIndex + rowLimit; i++) {
            $(rows[i]).show();
        }
        $(".pageTab#" + pageRequested).parent().attr("class", "active");
        $(".pageTab#" + currentPage).parent().attr("class", "");
        
        //Check to see if we have to shift the pageTabs left or right
        //Calculate the shift amount required and do it
        var rightEdge = Number($(".pageTab:eq(" + (pageLimit-1) + ")").attr("id"));
        var leftEdge = Number($(".pageTab:eq(0)").attr("id"));
        if(rightEdge <= pageRequested && isLotsPages) {
            var shift = Math.min(Math.ceil(pageLimit/2), numPages - pageRequested);
            if(pageRequested > rightEdge) shift = pageRequested - rightEdge;
            updateLongPageNav(pageRequested, shift);
        } 
        else if(leftEdge >= pageRequested && isLotsPages && leftEdge > 1) {
            var shift = Math.max(-Math.ceil(pageLimit/2), 1 - pageRequested);
            if(pageRequested < leftEdge) shift = pageRequested - leftEdge;  
            updateLongPageNav(pageRequested, shift);
        }
    }
    
    //Disable navigation arrows if current page makes it reasonable to do so
    //As an example, if you are pn page 1, the left arrows should not be active
    function updateArrows(pageNumber) {
        //We disable the page navigators if we reach either edge of the results
        if(pageNumber == 1) {
            $("li:has(a#oneBack)").attr("class", "disabled");
            $("li:has(a#fullBack)").attr("class", "disabled");
            $("li:has(a#oneFront)").attr("class", "");
            $("li:has(a#fullFront)").attr("class", "");
        }
        else if(pageNumber == numPages) {
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
    }
    
    //Create the navigation bar
    function createPageNavigation(numPages) {
        var pageTabs = "<ul class='pagination'>";
        pageTabs = pageTabs + "<li class='disabled'><a class='arrowNav' id='fullBack' href='javascript:void(0);'> << </a></li>";
        pageTabs = pageTabs + "<li class='disabled'><a class='arrowNav' id='oneBack' href='javascript:void(0);'> < </a></li>";
        
        if(numPages > pageLimit) {
            for(var i = 1; i <= pageLimit; i++) {
                if(i == 1) {
                    pageTabs = pageTabs + "<li class='active'>";
                } else {
                    pageTabs = pageTabs + "<li>";
                }
                pageTabs = pageTabs + "<a class='pageTab' id='" + i + "' href='javascript:void(0);'>" + i + "</a>";
                pageTabs = pageTabs + "</li>";
            }            
        } 
        else {
            for(var i = 1; i <= numPages; i++) {
                if(i == 1) {
                    pageTabs = pageTabs + "<li class='active'>";
                } else {
                    pageTabs = pageTabs + "<li>";
                }
                pageTabs = pageTabs + "<a class='pageTab' id='" + i + "' href='javascript:void(0);'>" + i + "</a>";
                pageTabs = pageTabs + "</li>";
            }
        }
        
        pageTabs = pageTabs + "<li><a class='arrowNav' id='oneFront' href='javascript:void(0);'> > </a></li>";
        pageTabs = pageTabs + "<li><a class='arrowNav' id='fullFront' href='javascript:void(0);'> >> </a></li>";
        pageTabs = pageTabs + "</ul>";
        return pageTabs;
    }

    //If there's a lot of pages, we want to using a sliding door to view the individual pages
    function updateLongPageNav(pageNumber, shift) {
        
        //Now, we add the pageTabs to the left
        for(var i = 0; i < pageLimit; i++) {
            var pageTab = $(".pagination a.pageTab:eq(" + i + ")");
            var newID = Number($(pageTab).attr("id")) + shift;
            $(pageTab).attr("id", newID);
            $(pageTab).text(newID);
            if(newID == pageNumber) {
                $(pageTab).parent().attr("class", "active");
            } else {
                $(pageTab).parent().attr("class", "");
            }
        }
    }
    
    //OnClickListener for each page tab
    function pageTabClickListener() {
        var isDisabled = $(this).parent().attr("class") == "active";
        if(isDisabled) return;
        
        pageRequested = Number($(this).attr("id"));
        goToPage(currentPage, pageRequested);
        updateArrows(pageRequested);
        currentPage = pageRequested;
        syncPageNavs();
    }

    //OnClickListener for each arrow in the page navigation bar
    function arrowClickListener() {
        
        //First, we make sure that this page navigation event isn't disabled
        var isDisabled = $(this).parent().attr("class") == "disabled";
        if(isDisabled) return;
        
        //Depending on the pagination arrow clicked, we update the page counter
        var id = $(this).attr("id");
        var pageRequested = 1;
        if(id == "fullBack") {
            pageRequested = 1;
        }
        else if(id == "oneBack") {
            pageRequested = currentPage - 1;
        }
        else if(id == "oneFront") {
            pageRequested = currentPage + 1;
        }
        else {
            pageRequested = numPages;
        }
        goToPage(currentPage, pageRequested);
        updateArrows(pageRequested);
        currentPage = pageRequested;
        syncPageNavs();
    }
    
    //Makes all the pageTabs inactive.  Useful for refreshes
    function cleanPageTabs() {
        var pageTabs = $(".pageTab").get();
        $(pageTabs[0]).parent().attr("class", "active");
        for(var i = 1; i < pageTabs.length; i++) {
            $(pageTabs[i]).parent().attr("class", "");
        }
    }

    //We need to keep track of which page we're on and set a limit to number of rows per page
    var currentPage = 1;
    var rowLimit = 20;    
    var pageLimit = 10;    
    var isLotsPages = false;    
    
    //We want to limit the number of rows we see in a table
    var tableRows = $('.paginateMe tr:not(:has(th))');
    var numPages = Math.ceil(tableRows.length /rowLimit);
    if(numPages > pageLimit) isLotsPages = true    
    
    for(var i = 0; i < tableRows.length; i++) {
        if(i >= rowLimit) {
            $(tableRows[i]).hide();
        }
    }
    
    //We do this in case of a refresh (ie.  when the rows get sorted by tablesorter)
    if(arguments.length > 0 && arguments[0] == true) {
        cleanPageTabs();
        $(".pageTab").unbind();
        $(".arrowNav").unbind();
        $(".pageTab").click(pageTabClickListener);
        $(".arrowNav").click(arrowClickListener);
        goToPage(2, 1);
        return;
    }
    
    //Add a navigation bar at the bottom
    //Display a tab for each page if number of pages < page limit
    //Otherwise, show 3 tabs before and after current page
    var pageTabs = createPageNavigation(numPages);
    $('.paginateMe').after(pageTabs);
    $(".paginateMe").before(pageTabs);
    
    //Add onclick listeners
    $(".pageTab").click(pageTabClickListener);
    $(".arrowNav").click(arrowClickListener);
} 




