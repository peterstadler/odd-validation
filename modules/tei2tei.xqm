xquery version "3.0";

module namespace tei2tei="https://github.com/peterstadler/odd-validation/modules/tei2tei";

declare namespace tei="http://www.tei-c.org/ns/1.0";

import module namespace config="https://github.com/peterstadler/odd-validation/modules/config" at "config.xqm";

declare function tei2tei:dispatch($body as element(tei:body)) as element(tei:TEI) {
    tei2tei:recurse($config:TEItemplate/tei:TEI, $body)
};

declare function tei2tei:recurse($element as element(), $body as element(tei:body)) as element() {
    element {node-name($element)} {
        $element/@*,
        for $child in $element/node()
        return 
            typeswitch($child)
            case element(tei:body) return $body
            case element(tei:date) return <date xmlns="http://www.tei-c.org/ns/1.0" when="{current-dateTime()}"/>
            default return 
                if ($child instance of element()) then tei2tei:recurse($child, $body)
                else $child
       }
};