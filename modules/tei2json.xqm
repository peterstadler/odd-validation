xquery version "3.0";

module namespace tei2json="http://edirom.de/odd-tools/tei2json";

declare namespace tei="http://www.tei-c.org/ns/1.0";

import module namespace xqjson="http://xqilla.sourceforge.net/lib/xqjson";

declare function tei2json:serialize($body as element(tei:body)) as xs:string? {
    xqjson:serialize-json(tei2json:dispatch($body))
};

declare function tei2json:dispatch($node as node()) as item()* {
    typeswitch($node)
        case text() return $node
        case element(tei:body) return tei2json:body($node)
        case element(tei:div) return tei2json:div($node)
        case element(tei:head) return tei2json:head($node)
        case element(tei:list) return tei2json:list($node)
        case element(tei:label) return tei2json:label($node)
(:        case element(tei:item) return tei2json:item($node):)
        default return ()
};

declare function tei2json:body($node as node()) as element(json) {
    <json type="object">
        {$node/node() ! tei2json:dispatch(.)}
    </json>
};

declare function tei2json:div($node as node()) as element(pair) {
    <pair type="object" name="{$node/string(@type)}">
        {$node/node() ! tei2json:dispatch(.)}
    </pair>
};

declare function tei2json:head($node as node()) as element(pair) {
    <pair name="{$node/string(@type)}" type="string">
        {$node/node() ! tei2json:dispatch(.)}
    </pair>
};

declare function tei2json:list($node as node()) as element(pair)* {
    (:<pair type="object">
        {$node/tei:label ! tei2json:dispatch(.)}
    </pair>:)
    $node/tei:label ! tei2json:dispatch(.)
};

declare function tei2json:label($node as node()) as element(pair) {
    <pair type="string" name="{$node/string()}">
        {$node/following-sibling::tei:item[1]/string()}
    </pair>
};

