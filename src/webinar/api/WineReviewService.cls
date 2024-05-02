Class webinar.api.WineReviewService Extends %CSP.REST
{

Parameter HandleCorsRequest = 0;

Parameter CHARSET = "utf-8";

XData UrlMap [ XMLNamespace = "https://www.intersystems.com/urlmap" ]
{
<Routes>
	<Route Url="/similar" Method="GET" Call="SearchSimilarDescription" />   
</Routes>
}

ClassMethod OnPreDispatch(pUrl As %String, pMethod As %String, ByRef pContinue As %Boolean) As %Status
{
    set %response.ContentType = "application/json"
    Quit $$$OK
}

ClassMethod SearchSimilarDescription() As %Status
{
    set ret = $$$OK
    try {
        set description = $get(%request.Data("description",1))

        set sql = 
            "SELECT TOP 3 "_
            "uid, country, designation, region, variety, description FROM webinar_data.WineReviews "_
            "WHERE country in ('Spain', 'France') "_
            "ORDER BY VECTOR_DOT_PRODUCT(description_vector, TO_VECTOR(webinar_data.WineReviews_GetEncoding(?))) DESC"
		set statement = ##class(%SQL.Statement).%New()
		$$$ThrowOnError(statement.%Prepare(sql))
        set rs = statement.%Execute(description)

        set array = []
        while rs.%Next() {
            do array.%Push({
                    "uid": (rs.%Get("uid")),
                    "country": (rs.%Get("country")),
                    "designation": (rs.%Get("designation")),
                    "region": (rs.%Get("region")),
                    "variety": (rs.%Get("variety")),
                    "description": (rs.%Get("description"))
                })
        }
        set %response.Status = ..#HTTP200OK
        write array.%ToJSON()

    } catch ex {
        set %response.Status = ..#HTTP400BADREQUEST
        return ex.DisplayString()
    }
    quit ret
}

}
