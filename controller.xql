xquery version "3.0";

declare variable $exist:path external;
declare variable $exist:resource external;
declare variable $exist:controller external;
declare variable $exist:prefix external;
declare variable $exist:root external;

(:~
 : Content Negotiation 
 : Evaluate Accept header and request-parameter 'format' to serve appropriate media type
 :
 : @return 'html' | 'xml' | 'json'
~:)
declare function local:media-type() as xs:string {
    let $format := request:get-parameter('format', '')[1]
    (:let $log := util:log-system-out(request:get-parameter-names()):)
    let $accepted-content-types := tokenize(normalize-space(request:get-header('accept')), ',\s?')
    return
        (: explicit request parameter takes precedence :)
        if(matches($format, '^x?html?$')) then 'html'
        else if(matches($format, '^x[mq]l$')) then 'xml'
        else if(matches($format, '^json$')) then 'json'
        
        (: Accept header follows if no suffix is given :)
        else if($accepted-content-types[1] = ('text/html', 'application/xhtml+xml')) then 'html'
        else if($accepted-content-types[1] = ('application/xml', 'application/tei+xml')) then 'xml'
        else if($accepted-content-types[1] = ('application/json')) then 'json'
        
        (: if nothing matches fall back to xml :)
        else 'xml'
};

if ($exist:path eq '') then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <redirect url="{request:get-uri()}/"/>
    </dispatch>
    
else if ($exist:path eq "/") then
    (: forward root path to index.xql :)
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <redirect url="index.html"/>
    </dispatch>
    
else if (ends-with($exist:resource, ".html")) then
    (: the html page is run through view.xql to expand templates :)
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{$exist:controller}/templates/{$exist:resource}" method="get"/>
        <view>
            <forward url="{$exist:controller}/modules/view.xql"/>
        </view>
		<error-handler>
			<forward url="{$exist:controller}/templates/error-page.html" method="get"/>
			<forward url="{$exist:controller}/modules/view.xql"/>
		</error-handler>
    </dispatch>
    
(: Resource paths starting with $shared are loaded from the shared-resources app :)
else if (contains($exist:path, "/$shared/")) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="/shared-resources/{substring-after($exist:path, '/$shared/')}">
            <set-header name="Cache-Control" value="max-age=3600, must-revalidate"/>
        </forward>
    </dispatch>

else if($exist:resource eq 'results.xql') then 
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{$exist:controller}/modules/{$exist:resource}">
            <set-attribute name="format" value="{local:media-type()}"/>
        </forward>
    </dispatch>

else
    (: everything else is passed through :)
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <cache-control cache="yes"/>
    </dispatch>
