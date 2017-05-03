# Roku SceneGraph/BrightScript Documentation Generator

[![Gem Version](https://badge.fury.io/rb/rsg_doc.svg)](https://badge.fury.io/rb/rsg_doc)

A tool to generate documentation for Brightscript referenced in Scenegraph XML.

## Installation

    $ gem install rsg_doc

## Usage

From within the root directory for a project:

    $ rsg

### Result

The generator targets Scenegraph xml files and parses Brightscript associated through the use of script tags.

    <script type="text/brightscript" uri="pkg:/somebrightscript.brs"></script>'
A docs folder is created containing same directory structure as the project with .brs.html and .xml.html files located where the source would be.

For information on how the html files are generated check out the [Standard](#standard).

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b feature/my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin feature/my-new-feature`)
5. Create a new Pull Request

## Standard



### Function Comment Structure

Comments on functions need to be in two blocks separated by an empty commented line:
 * **Description block**<br>
 A section for an explanation of the sub/function. Multiple lines will be stitched together to form a single description.
 <br><br>
 * **Tag block**<br>
 A section where tags can be used to effect how content is rendered.

### Available Tags

* **@deprecated** :_description_:<br>
* **@param** :_attribute_name_: :_description_:
* **@return** :_description_:
* **@since** :_version_:

Example:
```BrightScript
' Description block: any commented lines prior to an empty line
' the is part of the description
' this is also part of the description but the line below is not
'
' @deprecated Removed in 0.0.2 in favor of new function
' @param params contains information useful to this function
' @param anotherArg a string used for something
' @return 0 if successful, error code if not
' @since version 0.0.1
function myFunction(params as Object, anotherArg as String) as Int
...
end function
```