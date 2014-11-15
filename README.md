# ODD Validation

This is a first draft of an envisioned web service for validating TEI files against their respective ODD files.

The more or less generic parts (validating ODD files) can be found in the file `modules/validate.xqm` while most of the rest is designed to work within an [eXist database](http://exist-db.org).

## How to build

Simply run `ant` from the root folder of the project. That will provide you with a xar-package in the build folder. Upload this via the dashboard into your eXist database.


## ToDo

* Much …
* About page
* Demo website
* Error details for invalid files
* Error and sanity checks for user inputs
* API documentation
* Code cleanup
* Code documentation
* support for MEI files?!



## License


This piece of sofware is released to the public under the terms of the [GNU GPL v.3](http://www.gnu.org/copyleft/gpl.html) open source license.