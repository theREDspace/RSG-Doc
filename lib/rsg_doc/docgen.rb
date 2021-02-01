#********** Copyright 2017 REDspace. All Rights Reserved. **********

require 'erb'

module RSGDoc

  # Generate Brightscript documentation
  class Docgen

    # Set the root directory
    def initialize(options:)
      @verbose = options[:verbose]
      @ROOT_DIR = Dir.pwd()

      # For setting up links to roku docs later on
      @BRS_DOC_REF = "https://sdkdocs.roku.com/display/sdkdoc/"

      # Grab the list of files/directories to be ignored
      ignoreFile = ".rsgignore"
      @IgnoreRules = Array.new
      if File.exist? (File.join(@ROOT_DIR, ignoreFile))
        File.open(File.join(@ROOT_DIR,ignoreFile)).each do |line|
          @IgnoreRules.push( @ROOT_DIR + "/" + line )
        end
      else
        warn(".rsgignore not found at: " + @ROOT_DIR)
      end
    end

    # Generate html files for xml files and brs included via script tags
    def generate
      xmlFiles = Dir.glob(File.join(@ROOT_DIR, "**", "*.xml"))

      if nil != xmlFiles.first()
        FileUtils.cd(@ROOT_DIR)

        # Grab the documentation root
        @doc_dir = File.join(@ROOT_DIR, "docs")

        if Dir.exist? @doc_dir
          warn "Removing old document folder."
          FileUtils.rm_r(@doc_dir)
        end
        FileUtils.mkdir 'docs', :mode => 0755

        # Copy over styling file
        @styleFile = File.join(@doc_dir, "defaultStyling.css")
        FileUtils.copy(File.join(File.dirname(__FILE__), "docgenTemplates", "defaultStyling.css"), @styleFile)

        paths = []
        xmlFiles.each do |file|
          paths.push [File.join(
                @doc_dir,
                File.dirname(file).split(@ROOT_DIR)[1],
                File.basename(file)
            ) << ".html", File.basename(file)]
          parsexml(file)
        end

        index_file = File.open(
          File.join(
              @doc_dir,
              "index.html"
          ),"w",0755)
  
        paths.sort!{|x,y| x[1] <=> y[1]}
        # The binding here is the current context
        template = ERB.new(File.read(File.join(File.dirname(__FILE__), "docgenTemplates", "docgen.index.html.erb")))

        stylePath = "defaultStyling.css"

        index_file.write(template.result(binding))
        index_file.close

      else
        warn("No xml files found")
      end
    end

    # Look through the xml file and generate an html file with appropriate information
    def parsexml(filename)

      # Look for ignore rules on directories and xml filenames
      if @IgnoreRules.any? { |igrule| File.fnmatch(igrule, filename) }
        warn("Ignoring .xml file: " + filename)
        return
      end

      scripts = Array.new
      # Initialize the hash containing xml.html information
      xml_html_content = Hash.new
      xml_html_content[:fields] = Array.new
      xml_html_content[:brsfiles] = Array.new
      xml_html_content[:functionalfields] = Array.new

      packagePath = String.new

      # Iterate through lines in the xml file
      File.open(filename).each { |line|
        # Look for component name and optionally the extended class
        temp_component = /<component name="(?<name>[^"]*)" (extends="(?<extendedClass>[^"]*)")?.*>/.match(line)
        if (temp_component)
          xml_html_content[:componentName] = temp_component['name']
          xml_html_content[:componentExtendedClass] = temp_component['extendedClass']
          next
        end
        # Look for referenced brightscript files
        # Files defined using package
        tempScript = /<script.*uri="(?<uri>[^"]*)".*>/.match(line)
        if (tempScript)
          scripts.push( tempScript['uri'] )

          # Need to determine the package path if pkg: is used in a script reference
          if tempScript['uri'].include?("pkg:")
            scriptExtension = tempScript['uri'].split("pkg:")[1]
            tempPathArr = File.dirname(filename).split(@ROOT_DIR)[1].split("/")

            while packagePath == ""
              potentialPath = File.join(@ROOT_DIR, tempPathArr.join("/"), scriptExtension)
              packagePath = tempPathArr.join("/") if File.exist? potentialPath
              tempPathArr.pop
              break if tempPathArr.length <= 0
            end
          end
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
      # End Iteration block
      }

      FileUtils.mkdir_p File.join(@doc_dir, File.dirname(filename).split(@ROOT_DIR)[1]), :mode => 0755

      # Parse the brightscript files
      scripts.each do |script|
        # Determine full path to the file
        if script.include? "pkg:"
          prefix = File.join(@ROOT_DIR, packagePath)
          script = File.join(prefix, File.expand_path( script.split("pkg:")[1], prefix))
        else
          # Exclusively relative
          script = File.expand_path(script, File.dirname(filename))
        end

        # Checking for ignore rules on .brs files

        if @IgnoreRules.any? { |igrule| File.fnmatch(igrule, script) }
          warn("Ignoring .brs file: " + script)
          puts script
          next
        end

        # Check if documentation was already produced for a particular file
        documentationPath = File.join(@doc_dir, script.split(@ROOT_DIR)[1])

        if File.exist? documentationPath + ".html"
          # warn(".brs file already documented: "+ documentationPath)
          next
        end

        brs_doc_contents = parsebrs( script, filename )

        xml_html_content[:brsfiles].push({
          :path => documentationPath,
          :name => File.basename(script),
          :content => brs_doc_contents
        })

        # Pair up the functional field with the corresponding script
        xml_html_content[:functionalfields].each do |function|
          if brs_doc_contents[:content][:functions].empty?
             warn("Uncommented functional field located in #{brs_doc_contents[:ref]}")
          else
            brs_doc_contents[:content][:functions].each do |brsfunction|
              if brsfunction[:functionname] == function[:name]
                function.merge!(
                  :file => brs_doc_contents[:file],
                  :filename => File.basename(brs_doc_contents[:file]))
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

        # determine relative path to the style file
        filebreaks = File.dirname(File.path(xml_file).split(@doc_dir)[1]).split("/")
        stylePath = "../" * (filebreaks.length < 1 ? 0 : filebreaks.length - 1) + "defaultStyling.css"

        # The binding here is the current context
        xml_file.write( template.result(binding)
      )
      xml_file.close
    end

    # Parses a brightscript file
    # script        - full path to the brightscript file
    # parentxmlfile - full path to the xml file where the brightscript was referenced
    def parsebrs(script, parentxmlfile)

      # html to be written in the documentation
      brs_doc_content = Hash.new
      brs_doc_content[:functions] = Array.new
      brs_doc_content[:name] = File.basename(script)

      begin
        lines = IO.readlines(script)
      rescue Errno::ENOENT
        warn "BrightScript file not found: #{script} Referenced from: #{parentxmlfile}"
        return
      rescue IOError
        warn "Warn: Unable to read BrightScript file: #{script}"
        return
      else
        # look through the saved lines for comments to parse
        counter = 0
        until counter > lines.length
          if  /^\s*(sub|function)/.match(lines[counter])
            rev_counter = counter - 1
            while rev_counter > 0
              break unless  /\s*('|(?i:rem))/.match(lines[rev_counter])
              rev_counter -= 1
            end

            if counter - rev_counter
              commentInfo = parseComments(lines.slice(rev_counter+1, counter-rev_counter))
              if nil != commentInfo
                brs_doc_content[:functions].push(commentInfo)
              end
            end
          end
          counter += 1
        # End of loop per file
        end

        # Using the .brs.html.erb template to generate documentation
        template = ERB.new(File.read(File.join(File.dirname(__FILE__), "docgenTemplates", "docgen.brs.html.erb")))
        # Document brightscript file
        brs_doc_loc = File.join(
              @doc_dir,
              File.dirname(script).split(@ROOT_DIR)[1],
              File.basename(script)
        ) << ".html"

        filebreaks = File.dirname(brs_doc_loc.split(@doc_dir)[1]).split("/")
        stylePath = "../" * (filebreaks.length < 1 ? 0 : filebreaks.length - 1) + "defaultStyling.css"

        # Checks if directories are in place and adds them if they are not
        FileUtils.mkdir_p File.dirname(brs_doc_loc), :mode => 0755

        return {:content => brs_doc_content, :file => brs_doc_loc, :ref => script, :html => template.result(binding) }
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
        full_comment = /('|(?i:rem))\s*(?<comment>.*$)/.match(comments[line_num])
        if not full_comment
          warn "Bad comment in file #{@ref_brs_script}"
          return
        else
          brs_html_content[:description].push( parseDescription(full_comment['comment'] ))
        end
        line_num += 1
      end
      isParamBlock = false
      paramPath = []
      brs_html_content[:params] = Array.new
      brs_html_content[:public] = false
      # Parse the block tags if present
      while line_num < comments.length - 1
        # Look for deprecated tag
        dep_match = /'\s*@deprecated\s*(?<description>.*$)/.match(comments[line_num])
        if dep_match
          isParamBlock = false
          brs_html_content[:deprecated] = parseDescription(dep_match['description'])
          line_num += 1
          next
        end
        # Look for public tag
        dep_match = /'\s*@public/.match(comments[line_num])
        if dep_match
          isParamBlock = false
          brs_html_content[:public] = true
          line_num += 1
          next
        end
        # Look for param tag
        param_match = /'\s*@param\s*(?<type>{[\w.]*})?\s*(?<name>[\w.]*),?\s*(?<description>\w.*)?/.match(comments[line_num])
        if param_match
          isParamBlock = true
          paramPath = [param_match['name']]
          brs_html_content[:params].push({
            :name => param_match['name'].split("."),
            :type => param_match['type'],
            :description => parseDescription(param_match['description'])
          })
          line_num += 1
          next
        end
        # Look for since tags
        since_match = /'\s*@since\s*(?<description>\w.*)/.match(comments[line_num])
        if since_match
          isParamBlock = false
          brs_html_content[:since] = parseDescription(since_match['description'])
          line_num += 1
          next
        end
        # Look for return tags
        return_match = /'\s*@return\s*(?<description>\w.*$)/.match(comments[line_num])
        if return_match
          isParamBlock = false
          brs_html_content[:return] = parseDescription(return_match['description'])
          line_num += 1
          next
        end

        if isParamBlock === true
          param_match = /'\s*(?<type>{[\w:]*})?\s*(?<name>[\w.]*),?\s*(?<description>\w.*)?/.match(comments[line_num])
          if param_match
            curParamPath = param_match['name'].split(".")

            insertedAt = -1
            for i in 0..paramPath.length
              curIndex = paramPath.length - 1 - i

              if paramPath[curIndex] === curParamPath[0]
                paramPath[curIndex+1] = curParamPath[curParamPath.length-1]
                insertedAt = curIndex+1
                break
              end
            end
            paramPath.slice!(insertedAt + 1, paramPath.length - insertedAt - 1)
            brs_html_content[:params].push({
              :name => paramPath.map(&:clone),
              :type => param_match['type'],
              :description => parseDescription(param_match['description'])
            })
            line_num += 1
            next
          end
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

    def warn(message)
      puts "Warning: " + message if @verbose
    end

  # End class
  end

# End module
end