#********** Copyright 2017 REDspace. All Rights Reserved. **********

require 'erb'

# Generate Brightscript documentation
class Docgen

  # Set the root directory
  def initialize(root_dir: nil)
    @ROOT_DIR = root_dir
    @BRS_DOC_REF = "https://sdkdocs.roku.com/display/sdkdoc/"
    FileUtils.cd(@ROOT_DIR)
    FileUtils.mkdir_p 'docs', :mode => 0755
    # Grab the document root
    @doc_dir = File.join(@ROOT_DIR, "docs")
  end

  # Generate html files for xml files and brs included via script tags
  def generate
    Dir.glob(File.join(@ROOT_DIR, "**", "*.xml")).each do |file|
      FileUtils.mkdir_p File.join(@doc_dir, File.dirname(file).split(@ROOT_DIR)[1]), :mode => 0755
      parsexml(file)
    end
  end

  # Look through the xml file and generate an html file with appropriate information
  def parsexml(filename)
    scripts = Array.new
    # Initialize the hash containing xml.html information
    xml_html_content = Hash.new
    xml_html_content[:fields] = Array.new
    xml_html_content[:brsfiles] = Array.new
    xml_html_content[:functionalfields] = Array.new

    # Iterate through lines in the file
    File.open(filename).each do |line|
      # Look for component name and optionally the extended class
      temp_component = /<component name="(?<name>[^"]*)" (extends="(?<extendedClass>[^"]*)")?.*>/.match(line)
      if (temp_component)
        xml_html_content[:componentName] = temp_component['name']
        xml_html_content[:componentExtendedClass] = temp_component['extendedClass']
        next
      end
      # Look for referenced brightscript files
      tempScript = /<script.*uri="pkg:(?<uri>[^"]*)".*>/.match(line)
      if (tempScript)
        scripts.push( tempScript )
        next
      end
      # Look for fields on the inferface
      tempField = /<field (id="(?<id>[^"]*)") (type="(?<type>[^"]*)").*>/.match(line)
      if (tempField)
          xml_html_content[:fields].push({
            :id => tempField['id'],
            :type => tempField['type']
          })
        next
      end
      # Look for functional fields on the interface
      tempFuncField = /<function (name="(?<name>[^"]*)").*>/.match(line)
      if (tempFuncField)
        xml_html_content[:functionalfields].push({
          :name => tempFuncField['name']
        })
      end
    # End looping through file
    end

    # Define the variable for the portion of the path after the root and before pkg:
    # Needs to be changes in order to account for relative paths
    packageDoc = nil

    # Parse the brightscript
    scripts.each do |script|

      packageDoc = File.dirname(filename.split(@ROOT_DIR)[1]).split(File.dirname(script['uri']))[0]
      xml_html_content[:brsfiles].push({
        :path => File.join(@doc_dir, packageDoc, File.path(script['uri'])),
        :name => File.basename(script['uri'])
      })

      brs_doc_contents = parsebrs( script['uri'], packageDoc, filename )
      # Pair up the functional field with the corresponding script
      xml_html_content[:functionalfields].each do |function|
        if brs_doc_contents[:content][:functions].empty?
          puts "Warn: Uncommented functional field located in #{brs_doc_contents[:ref]}"
        else
          brs_doc_contents[:content][:functions].each do |brsfunction|
            if brsfunction[:functionname] == function[:name]
              function.merge!(:file => brs_doc_contents[:file])
            end
          end
        end
      end
    end

    # Using the .xml.html.erb
    template = ERB.new(File.read(File.join(File.dirname(__FILE__), "docgenTemplates", "docgen.xml.html.erb")))
    # Document the xml file
    xml_file = File.open(
      File.join(
          @doc_dir,
          File.dirname(filename).split(@ROOT_DIR)[1],
          File.basename(filename)
      ) << ".html","w",0755)
    xml_file.write( template.result(binding) )
    xml_file.close
  end

  # Controls the parsing for the commands
  def parsebrs( script, package, parentxmlfile)

    # Account for the path being relative, versus using package root
    ref_brs_script = File.join(@ROOT_DIR, package, script)

    # html to be written to the documentation
    brs_doc_content = Hash.new
    brs_doc_content[:functions] = Array.new
    brs_doc_content[:name] = File.basename(ref_brs_script)

    begin
      lines = IO.readlines(ref_brs_script)
    rescue Errno::ENOENT
      puts "Warn: BrightScript file not found: #{ref_brs_script} Referenced from: #{parentxmlfile}"
      return
    else
      # look through the saved lines for comments to parse
      counter = 0;
      until counter > lines.length
        if  /^\s*(sub|function)/.match(lines[counter])
          rev_counter = counter - 1
          while rev_counter > 0
            break unless  /\s*('|(?i:rem))/.match(lines[rev_counter])
            rev_counter -= 1
          end
          brs_doc_content[:functions].push(
            parseComments(lines.slice(rev_counter+1, counter-rev_counter))
          ) if counter-rev_counter > 1
        end
        counter += 1
      # End of loop per file
      end

        # Using the .xml.html.erb
      template = ERB.new(File.read(File.join(File.dirname(__FILE__), "docgenTemplates", "docgen.brs.html.erb")))
      # Document brightscript file
      brs_doc_loc = File.join(
            @doc_dir,
            File.dirname(ref_brs_script).split(@ROOT_DIR)[1],
            File.basename(ref_brs_script)
      ) << ".html"
      brs_file = File.open(brs_doc_loc, "w", 0755)
      brs_file.write( template.result(binding) )
      brs_file.close
      return {:content => brs_doc_content, :file => brs_doc_loc, :ref => ref_brs_script }
    end
  end

  # Find all the comment components when generating the brightscript file
  def parseComments(comments)
    # Last line of the comments will be the function name
    brs_html_content = Hash.new
    brs_html_content[:description] = Array.new
    line_num = 0;

    # Parse description block
    while line_num < comments.length - 1
      if /('|(?i:rem))\s*$/.match(comments[line_num])
        line_num += 1
        break
      end
      full_comment = /('|(?i:rem))\s*(?<comment>\w.*$)/.match(comments[line_num])
      brs_html_content[:description].push( parseDescription(full_comment['comment'] ))
      line_num += 1
    end
    brs_html_content[:params] = Array.new
    # Parse the block tags if present
    while line_num < comments.length - 1
      # Look for deprecated tag
      dep_match = /'\s*@deprecated\s*(?<description>.*$)/.match(comments[line_num])
      if dep_match
        brs_html_content[:deprecated] = parseDescription(dep_match['description'])
        line_num += 1
        next
      end
      # Look for param tag
      param_match = /'\s*@param\s*(?<name>\w*)\s*(?<description>\w.*)?/.match(comments[line_num])
      if param_match
        brs_html_content[:params].push({
          :name => param_match['name'],
          :description => parseDescription(param_match['description'])
        })
        line_num += 1
        next
      end
      # Look for since tags
      since_match = /'\s*@since\s*(?<description>\w.*)/.match(comments[line_num])
      if since_match
        brs_html_content[:since] = parseDescription(since_match['description'])
        line_num += 1
        next
      end
      # Look for return tags
      return_match = /'\s*@return\s*(?<description>\w.*$)/.match(comments[line_num])
      if return_match
        brs_html_content[:return] = parseDescription(return_match['description'])
        line_num += 1
        next
      end
      line_num += 1
    end
    # Get the function details (name for now)
    function_info = /^\s*(sub|function)\s(?<name>[^(]*)\((?<inputs>[^)]*)\)\s*(?<returntype>\w.*)?/.match(comments[comments.length-1])
    if function_info
      brs_html_content[:functionname] = function_info['name']
      brs_html_content[:functioninputs] = function_info['inputs']
    end
    return brs_html_content
  end

  # Handle the description and the inline tags
  def parseDescription(des)
    return des unless inline_match = /^'(.*)(?<inline>{[^}]*})(.*)/.match(des)

    link_string = ""
    tag_match = /@(?<tag>\w*)\s+(?<component>\w*)\s+(?<link_text>[^}]*)/.match(inline_match['inline'])
    if tag_match
      case tag_match['tag']
      when "link"
        link_string = "<a href=\"#{ File.join(@BRS_DOC_REF,tag_match['component']) }\">#{tag_match['link_text']}</a>"
        return des.split(inline_match['inline']).join(link_string)
      end
      return des
    end
  end

# End class
end
