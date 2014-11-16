xquery version "3.0";

module namespace validate="http://edirom.de/odd-tools/validate";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace rng="http://relaxng.org/ns/structure/1.0";
declare namespace validation="http://exist-db.org/xquery/validation";
declare namespace httpclient = "http://exist-db.org/xquery/httpclient";
declare namespace expath-http = "http://expath.org/ns/http-client";
declare namespace compression = "http://exist-db.org/xquery/compression";

import module namespace functx="http://www.functx.com";
import module namespace config="http://edirom.de/odd-tools/config" at "config.xqm";

(:~
 : Main entry function:
 : Validate an XML file against an ODD schema 
 :
 : @author Peter Stadler
 : @param 
 : @return
~:)
declare function validate:odd-schema($input as node(), $tei-version as xs:string, $odd as node(), $fragment as xs:boolean, $remove-foreign-ns as xs:boolean) {
    let $p5subset := config:p5subset($tei-version)
    let $org-schema := config:tei-schema($tei-version)
    let $substitutes := map:new(
        for $i in $odd//tei:elementSpec[@mode = ('add')] 
        let $sub := validate:element-substitutes($i, $p5subset, true())
        return 
            if($sub[1]) then map:entry($i/string(@ident), $sub[1])
            else ()
    )
    let $replaced-input := validate:replace-element-names($input, $substitutes)
    let $schema := 
        if($fragment) then validate:replace-start-element($input, $org-schema)
        else $org-schema
    return
        validation:jing-report($replaced-input, $schema)
};


declare function validate:tei-schema($input as node(), $tei-version as xs:string, $fragment as xs:boolean, $remove-foreign-ns as xs:boolean) {
    let $org-schema := config:tei-schema($tei-version)
    let $schema := 
        if($fragment) then validate:replace-start-element($input, $org-schema)
        else $org-schema
    let $input := 
        if($remove-foreign-ns) then validate:strip-non-tei-ns($input)
        else $input
    return 
        validation:jing-report($input, $schema)
};


(:~
 : Remove elements and attributes which are not in the TEI or XML namespace
 :
 : @author Peter Stadler
 : @param $node The input node to remove the foreign nodes from
 : @return node() The output node without the foreign nodes
~:)
declare function validate:strip-non-tei-ns($node as node()*) as node()* {
    typeswitch($node)
        case document-node() return validate:strip-non-tei-ns($node/*)
        case element() return
            if(namespace-uri($node) eq 'http://www.tei-c.org/ns/1.0') then 
                element {node-name($node)} {
                    for $attr in $node/@* return validate:strip-non-tei-ns($attr),
                    for $child in $node/node()
                    return 
                        if ($child instance of element()) then validate:strip-non-tei-ns($child)
                        else $child
                }
            (: removes the complete subtree! :)
            else ()
        case attribute() return
            if(namespace-uri($node) = ('', 'http://www.w3.org/XML/1998/namespace')) then $node
            else ()
        default return error(xs:QName('validate:unsupported-type'), 'type ' || node-name($node) || ' not supported')
};


(:~
 : Check whether the input tei:classes is a subset of the vanilla tei:classes defined by $ident in $p5subset
 :
 : @author Peter Stadler
 : @param $ident The canonical name of a TEI element
 : @param $classes A list of classes in a format as defined by ref-classes.html
 : @param $p5subset The p5subset.xml 
 : @return xs:boolean
~:)
declare function validate:classes-is-subset($ident as xs:string, $classes as element(tei:classes)?, $p5subset as node()) as xs:boolean {
    every $i in $classes/tei:memberOf[@mode = 'add' or not(@mode)]/@key satisfies $i = $p5subset//tei:elementSpec[@ident = $ident]/tei:classes/tei:memberOf/@key
};


(:~
 : Check whether the input tei:attList is a subset of the vanilla tei:attList defined by $ident in $p5subset
 :
 : @author Peter Stadler
 : @param $ident The canonical name of a TEI element
 : @param $attList An attribute list in a format as defined by ref-attList.html
 : @param $p5subset The p5subset.xml 
 : @return xs:boolean
~:)
declare function validate:attrs-is-subset($ident as xs:string, $attList as element(tei:attList)?, $p5subset as node()) as xs:boolean {
    let $direct-attrs := $p5subset//tei:elementSpec[@ident = $ident]//tei:attList/tei:attDef/@ident
    let $class-attrs := $p5subset//tei:elementSpec[@ident = $ident]/tei:classes/tei:memberOf[starts-with(@key, 'att.')] ! validate:expand-att-class(./string(@key), $p5subset) 
    return
        every $i in $attList/tei:attDef[@mode = ('add', 'change', 'replace') or not(@mode)]/@ident satisfies $i = ($direct-attrs, $class-attrs)
};


(:~
 : Expand attribute class and list the individual attributes
 :
 : @author Peter Stadler
 : @param $ident The class name, e.g. 'att.global'
 : @param $p5subset The p5subset.xml 
 : @return xs:string* The attribute names as a sequence of strings
~:)
declare function validate:expand-att-class($ident as xs:string, $p5subset as node()) as xs:string* {
    (: what are nested attLists? :)
    $p5subset//tei:classSpec[@ident = $ident]//tei:attList/tei:attDef/string(@ident),
    
    (: recurse into included attribute classes :)
    $p5subset//tei:classSpec[@ident = $ident]/tei:classes/tei:memberOf[starts-with(@key, 'att.')] ! validate:expand-att-class(./string(@key), $p5subset)
};


(:~
 : Check whether the input tei:content is a subset of the vanilla tei:content defined by $ident in $p5subset
 : ATTENTION: Currently only lexical identity is checked
 :
 : @author Peter Stadler
 : @param $ident The canonical name of a TEI element
 : @param $content The content definition as defined by ref-content.html
 : @param $p5subset The p5subset.xml 
 : @return xs:boolean
~:)
declare function validate:content-is-subset($ident as xs:string, $content as element(tei:content), $p5subset as node()) as xs:boolean {
    (: how to check whether two schemas (grammars?) define the same language :)
    deep-equal(validate:normalize-element($content), validate:normalize-element($p5subset//tei:elementSpec[@ident = $ident]/tei:content))
};


(:~
 : Find element substitutes from vanilla TEI 
 : (i.e. Check whether the input tei:elementSpec is modeled according to some existing element as defined in $p5subset)
 :
 : @author Peter Stadler
 : @param $elementSpec
 : @param $p5subset The p5subset.xml
 : @param $cumulative Whether attributes, class membership and content model may be a mixin of existing elements. 
            If false(), all three must be modeled after one already existing element
            ATTENTION: Currently not implemented
 : @return A sequence of TEI canonical element names that serve as a model
~:)
declare function validate:element-substitutes($elementSpec as element(tei:elementSpec), $p5subset as node(), $cumulative as xs:boolean) as xs:string* {
    let $model-classes := $elementSpec//tei:memberOf[starts-with(@key, 'model')]/string(@key)
    let $context-models := $p5subset//tei:elementSpec[every $class in $model-classes satisfies .//tei:memberOf[@key = $class]]/string(@ident)
    let $attr-models := $context-models ! (if(validate:attrs-is-subset(., $elementSpec/tei:attList, $p5subset)) then . else ())
    let $content-models := $context-models ! (if(validate:content-is-subset(., $elementSpec/tei:content, $p5subset)) then . else ())
    return 
        (:$content-models and $attr-models and $context-models:)
        functx:value-intersect($attr-models, $content-models)
};

(:~
 : Helper function: Recursively removes text (whitespace!) from element content and returns only(!) elements
 :
 : @author Peter Stadler
 : @param $el The element node to normalize
 : @return The normalized element node without any comments, processing-instructions or text
~:)
declare %private function validate:normalize-element($el as element()?) as element()? {
    if($el) then
        element {node-name($el)} {
            $el/@*,
            for $child in $el/element() return validate:normalize-element($child) 
        }
    else ()
};


declare %private function validate:replace-element-names($node as node(), $replacements as map(*)) as element()? {
    typeswitch($node)
    case element() return
        element {
            if(local-name($node) = map:keys($replacements) and namespace-uri($node) = 'http://www.tei-c.org/ns/1.0') 
                then QName('http://www.tei-c.org/ns/1.0', $replacements(local-name($node)))
                else node-name($node)
            } {
            $node/@*,
            for $child in $node/node() return 
                if ($child instance of element()) then validate:replace-element-names($child, $replacements)
                else $child
        }
    case document-node() return validate:replace-element-names($node/*, $replacements)
    default return error(xs:QName('validate:unsupported-type'), 'type ' || node-name($node) || ' not supported')
};


declare %private function validate:replace-start-element($input as node(), $schema as document-node()) as element(rng:grammar) {
    let $start-node-name := 
        typeswitch ($input)
            case element() return local-name($input)
            case document-node() return local-name($input/*)
            default return error(xs:QName('validate:unsupported-node'), 'type ' || node-name($input) || ' not supported')
    return
        if(node-name($schema/*) ne xs:QName('rng:grammar')) then error(xs:QName('validate:wrong-schema'), 'RelaxNG XML syntax required')
        else 
            element rng:grammar {
                $schema/rng:grammar/@*,
                $schema/rng:grammar/*[not(node-name(.) = xs:QName('rng:start'))],
                <rng:start><rng:ref name="{$start-node-name}"/></rng:start>
            }
};


declare function validate:create-schema($odd as node()) {
    (: http://www.w3.org/TR/html401/interact/forms.html#form-content-type :)
    (: http://expath.org/spec/http-client :)
    (: http://www.posttestserver.com :)
    (: https://github.com/adamretter/expath-http-client-java/blob/master/samples/post-params.xq :)
    let $url := 
(:        'http://posttestserver.com/post.php':)
        'http://www.tei-c.org/ege-webservice/Conversions/ODD%3Atext%3Axml/ODDC%3Atext%3Axml/'
        (:'http://www.tei-c.org/ege-webservice/Conversions/ODD%3Atext%3Axml/ODDC%3Atext%3Axml/relaxng%3Aapplication%3Axml-relaxng/':)
(:        'http://www.tei-c.org/ege-webservice/Conversions/' || string-join((encode-for-uri('ODD:text:xml'), encode-for-uri('ODDC:text:xml'), encode-for-uri('relaxng:application:xml-relaxng')), '/') || '/':)
    let $serializationParameters := ('method=xml', 'media-type=application/xml', 'indent=no', 'omit-xml-declaration=no', 'encoding=utf-8')
(:    let $req := <http:request href="{$url}" method="post"><http:multipart media-type="application/xml" boundary="upload"/></http:request>:)
    let $req := 
        <http:request href="{$url}" method="post" http-version="1.0">
            <http:multipart media-type="multipart/form-data" boundary="foobar">
                <http:header name="Content-Disposition" value='form-data; name="upload"; filename="file1.xml"'/>
                <http:body media-type="application/xml">{$odd}</http:body>
            </http:multipart>
        </http:request>
(:        <http:body media-type="application/octet-stream" method="xml">{util:string-to-binary(util:serialize($odd, $serializationParameters))}</http:body>:)
(:    let $content := <httpclient:fields><httpclient:field name="upload" value="{encode-for-uri(util:serialize($odd//tei:TEI, $serializationParameters))}" type="string"/></httpclient:fields>:)
(:    let $content := <httpclient:fields><httpclient:field name="upload" value="{xs:anyURI('xmldb:exist:///db/TEI/WeGA_diaries.odd.xml')}" type="file"/></httpclient:fields>:)
    return
(:        httpclient:post-form($url, $content, false(), <headers><header name="content-type" value="application/xml"/></headers>):)
        util:binary-to-string(expath-http:send-request($req)[2])
};