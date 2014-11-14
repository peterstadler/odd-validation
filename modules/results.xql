xquery version "3.0";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace edirom="http://www.edirom.de";
declare namespace expath-http="http://expath.org/ns/http-client";

import module namespace tei2tei="http://edirom.de/odd-tools/tei2tei" at "tei2tei.xqm";
import module namespace tei2json="http://edirom.de/odd-tools/tei2json" at "tei2json.xqm";
import module namespace validate="http://edirom.de/odd-tools/validate" at "validate.xqm";
import module namespace config="http://edirom.de/odd-tools/config" at "config.xqm";
import module namespace templates="http://exist-db.org/xquery/templates";
import module namespace xqjson="http://xqilla.sourceforge.net/lib/xqjson";

(:declare option exist:serialize "method=html5 media-type=text/html enforce-xhtml=yes";:)

(: This should be set to application/tei+xml, but that makes Firefox open a fresh tab, which is annoying. :)
declare option exist:serialize "method=xml media-type=application/xml encoding=utf-8 indent=yes";

(:
    1. Create compiled ODD
    2. create Relax schema 
    3. Check valid against its own customization
    4. check valid against abstract model
:)

declare function local:create-session-map() as map(*) {
    let $request-params := request:get-parameter-names()[. = $config:valid-request-params]
    return 
        map:new(
            for $param in $request-params
            return 
                if(ends-with($param, 'File')) then (
                    map:entry($param, local:parse-upload($param)),
                    map:entry($param || 'Name', request:get-uploaded-file-name($param))
                )
                else 
                    map:entry(
                        $param, request:get-parameter($param, ())
                    )
        )
};

declare function local:upload() as element(tei:body) {
    let $store-session := session:set-attribute('session-map', local:create-session-map())
    return 
        <tei:body><tei:head type="sessionID">{session:get-id()}</tei:head></tei:body>
};

(: task = oddc|relax:)
(:declare function local:create-schema($odd as document-node()?, $task as xs:string) {
    let $url := 
        switch($task)
        case 'oddc' return 'http://www.tei-c.org/ege-webservice/Conversions/ODD%3Atext%3Axml/ODDC%3Atext%3Axml/'
        case 'relax' return 'http://www.tei-c.org/ege-webservice/Conversions/ODDC%3Atext%3Axml/relaxng%3Aapplication%3Axml-relaxng/'
        default return error(xs:QName('edirom:unsupported-task'), 'task' || $task || ' not supported')
    let $req := 
        <http:request href="{$url}" method="post" http-version="1.0">
            <http:multipart media-type="multipart/form-data" boundary="foobar">
                <http:header name="Content-Disposition" value='form-data; name="upload"; filename="file1.xml"'/>
                <http:body media-type="application/xml">{$odd}</http:body>
            </http:multipart>
        </http:request>
    return 
        if($odd) then 
            try { parse-xml(util:binary-to-string(expath-http:send-request($req)[2])) }
            catch * {error(xs:QName('edirom:parser-fail'), 'failed to parse as xml file')}
        else ()
};:)

declare function local:parse-upload($req-param as xs:string) as node()? {
    let $input := request:get-uploaded-file-data($req-param)
    return
        try { parse-xml(util:binary-to-string($input)) }
        catch * {error(xs:QName('edirom:parser-fail'), 'failed to parse as xml file')}
};

declare function local:tei-validate($params as map(*)) as element(tei:body) {
    let $session-map := session:get-attribute('session-map')
    let $file := $session-map('xmlFile')
    let $fragment := not($file/root()/node-name(*) = (xs:QName('tei:TEI'), xs:QName('tei:teiCorpus')))
    let $external-ns := distinct-values($file//*/namespace-uri()) != 'http://www.tei-c.org/ns/1.0'
    let $validation := validate:tei-schema($file, $params('version'), $fragment, $external-ns)
    return 
        <body xmlns="http://www.tei-c.org/ns/1.0">
            <div type="properties">
                <list type="gloss">
                    {for $i in map:keys($params) return (<label>{$i}</label>,<item>{$params($i)}</item>)}
                    <label>fragment</label>
                    <item>{$fragment cast as xs:string}</item>
                    <label>rootElement</label>
                    <item>{$file/name(*) cast as xs:string}</item>
                    <label>externalNS</label>
                    <item>{$external-ns cast as xs:string}</item>
                    {for $fileName in map:keys($session-map)[ends-with(., 'Name')] return (<label>{$fileName}</label>,<item>{$session-map($fileName)}</item>)}
                </list>
            </div>
            {local:jing-report2tei($validation)}
        </body>
};

declare function local:jing-report2tei($report as element(report)) as element(tei:div) {
    <tei:div type="results">
        <tei:head type="status">{normalize-space($report/status)}</tei:head>
        {for $message in $report//message
        return 
            <tei:div type="message">
                <tei:list type="gloss">
                    {for $attr in $message/@*
                    return (<tei:label>{local-name($attr)}</tei:label>,<tei:item>{normalize-space($attr)}</tei:item>)
                    }
                    <tei:label>messageText</tei:label>
                    <tei:item>{normalize-space($message)}</tei:item>
                </tei:list>
            </tei:div>
        }
    </tei:div>
};

declare function local:serialize-output($result as element(tei:body), $format as xs:string?) {
    switch($format)
        case 'html' return (
            (:response:set-header('Content-Type', 'text/html'),
            ():)
            error(xs:QName('edirom:format-error'), 'format "' || $format || '" not supported')
        )
        case 'json' return (
            response:set-header('Content-Type', 'application/json'),
            tei2json:serialize($result)
        )
        default return (
            response:set-header('Content-Type', 'application/xml'),
            tei2tei:dispatch($result)
        )
};

let $task := request:get-parameter('task', ())
let $format := 
    (: controller problems: Request parameters of POST are not visible :)
    if($task = 'upload') then 'json'
    else request:get-attribute('format')
let $version := request:get-parameter('version', 'current')
let $params := map { 'task' := $task, 'format' := $format, 'version' := $version }
(:let $log := util:log-system-out(request:get-parameter-names()):)
let $result :=
    switch($task)
    case 'tei-validate' return local:tei-validate($params)
    case 'upload' return local:upload()
    case 'test' return <tei:body>foobar</tei:body>
    default return error(xs:QName('edirom:task-error'), 'task "' || $task || '" not supported')

return 
    local:serialize-output($result, $format)
