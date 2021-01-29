#require "byebug"

# Read in files objectgraph.txt and typegraph.txt, which contain structural information about the SIF spec as a graph,
# and generate a single flat file containing all structural information about the spec

def get_objgraph(file)
  graph = {}
  root = ""
  while line = file.gets do 
    line.chomp!
    if /^\s*##1/.match line
        latest = graph[root][-1][:elems]
    elsif /^\s*##2/.match line
      latest = graph[root][-1][:elems][-1][:elems]
    elsif /^\s*##3/.match line
      latest = graph[root][-1][:elems][-1][:elems][-1][:elems]
    elsif /^\s*##4/.match line
      latest = graph[root][-1][:elems][-1][:elems][-1][:elems][-1][:elems]
    elsif /^\s*##5/.match line
      latest = graph[root][-1][:elems][-1][:elems][-1][:elems][-1][:elems][-1][:elems]
    elsif /^\s*##6/.match line
      latest = graph[root][-1][:elems][-1][:elems][-1][:elems][-1][:elems][-1][:elems][-1][:elems]
    elsif /ATTRIBUTE/.match line
    elsif !(/\S/.match line)
    else
      latest = graph[root]
    end

    line.sub!(/^\s*##\d+/, "")
      next unless /\S/.match line

    if /PARENT\s+\S+\s+\S+/.match(line)
      %r{PARENT (?<root>\S+)\s+(?<type>\S+)} =~ line
      graph[root] = [{inherits: type}]
      latest = graph[root]
    elsif /PARENT.*\/\//.match(line)
      %r{PARENT (?<root>\S+)//} =~ line
      graph[root] = []
      graph[root] << { attr: [] }
      latest = graph[root]
    elsif /%Inherits:\s+(?<inherits>[^;]+);/ =~ line
      latest[-1][:inherits] = inherits.sub(/\s*$/, "")
    elsif /ATTRIBUTE/.match(line)
      /ATTRIBUTE (?<attr>\S+?):\s+(?<type>\S+);/ =~ line
      latest[-1][:attr] << { attr: attr, type: type.sub(/\s*$/, "") }
    else
      /(?<elem>\S+?):\s+(?<list>LIST )?(?<type>[^;]+);/ =~ line
      warn line unless type
      latest << { elem: elem, type: type&.sub(/\s*$/, ""), attr: [], elems: [], list: !list.nil? }
    end
  end
  graph
end

@objgraph = {}
@typegraph = {}

# cut off mutual recursion: track all types invoked in current depth iteration
@types_used = []

def xpathtype(arr, path, object)
  arr.each do |a|
    elem = if a[:elem]
             a[:elem]
           elsif a[:attr] && !a[:attr].empty?
             "@#{a[:attr][0][:attr]}"
           else
             "node()"
           end
    if a[:elems] && !a[:elems].empty?
      puts "XPATHTYPE:\t#{elem}\t#{path}/#{a[:elem]}\tLOOKUP\t#{object}\t#{path}"
      xpathtype(a[:elems], "#{path}/#{a[:elem]}", "TYPE")
    elsif a[:type] && @typegraph[a[:type]]
      puts "XPATHTYPE:\t#{elem}\t#{a[:type]}\tLOOKUP\t#{object}\t#{path}"
    elsif a[:inherits] && @typegraph[a[:inherits]]
      puts "XPATHTYPE:\t#{elem}\t#{a[:inherits]}\tLOOKUP\t#{object}\t#{path}\tALIAS"
    elsif a[:type] || a[:inherits]
      puts "XPATHTYPE:\t#{elem}\t#{a[:type] || a[:inherits]}\t\t#{object}\t#{path}\tALIAS"
    end
  end
end

@counter = 0

def traverse(arr, path, currdepth, maxdepth, header)
  return if maxdepth > 0 && currdepth >= maxdepth
  arr.each do |a|
    display = path.gsub(%r{//+}, "/").sub(%r{/+$}, "") 
    display = "#{display}/#{a[:elem]}" if a[:elem]
    object = path.sub(%r{/.*$}, "")
    unless header == "TRAVERSE ALL:" && /SIF_Metadata|SIF_ExtendedElements|LocalCodeList/.match(display)
      if a[:elem]
        @counter+=1
        puts "#{header}\t#{display}\t#{object}\t#{a[:elem]}\t#{a[:type]}\t#{@counter}"
      end
      unless a[:attr].nil? || a[:attr].empty?
        a[:attr].each do |aa|
          @counter+=1
          puts "#{header}\t#{display}/@#{aa[:attr]}\t#{object}\t@#{aa[:attr]}\t#{aa[:type]}\t#{@counter}" 
        end
      end
    end
    if a[:elems] && !a[:elems].empty?
      traverse(a[:elems], "#{path}/#{a[:elem]}", currdepth+1, maxdepth, header)
    elsif a[:type] && @typegraph[a[:type]]
      unless @types_used.include? a[:type]
        @types_used << a[:type]
        traverse(@typegraph[a[:type]], "#{path}/#{a[:elem]}", currdepth+1, maxdepth, header)
        @types_used.pop()
      end
    end
    if a[:inherits] && @typegraph[a[:inherits]]
      traverse(@typegraph[a[:inherits]], "#{path}/#{a[:elem]}", currdepth+1, maxdepth, header)
    end
  end
end

def listfind(arr, path)
  arr.each do |a|
    if a[:list] 
      puts "LIST: #{path}/#{a[:elem]}"
    end
    if a[:elems] && !a[:elems].empty?
      listfind(a[:elems], "#{path}/#{a[:elem]}")
    elsif a[:type] && @typegraph[a[:type]]
      unless @types_used.include? a[:type]
        @types_used << a[:type]
        listfind(@typegraph[a[:type]], "#{path}/#{a[:elem]}")
        @types_used.pop()
      end
    end
    if a[:inherits] && @typegraph[a[:inherits]]
      listfind(@typegraph[a[:inherits]], "#{path}/#{a[:elem]}")
    end
  end
end

def booleanfind(arr, path)
  arr.each do |a|
    #pp a
    if a[:type] == "boolean"
      puts "BOOLEAN: #{path}/#{a[:elem]}"
    elsif a[:inherits] == "boolean"
      puts "BOOLEAN: #{path}/#{a[:elem]}"
    elsif a[:elems] && !a[:elems].empty?
      booleanfind(a[:elems], "#{path}/#{a[:elem]}")
    elsif a[:type] && @typegraph[a[:type]]
      unless @types_used.include? a[:type]
        @types_used << a[:type]
        booleanfind(@typegraph[a[:type]], "#{path}/#{a[:elem]}")
        @types_used.pop()
      end
    end
    if a[:inherits] && @typegraph[a[:inherits]]
      booleanfind(@typegraph[a[:inherits]], "#{path}/#{a[:elem]}")
    end
  end
end

def numericfind(arr, path)
  arr.each do |a|
    #pp a
    elem = a[:elem] ? ( "/" + a[:elem] ) : ""
    if a[:type] == "number"
      puts "NUMERIC: #{path}#{elem}"
    elsif a[:inherits] == "number"
      puts "NUMERIC: #{path}#{elem}"
    elsif a[:elems] && !a[:elems].empty?
      numericfind(a[:elems], "#{path}#{elem}")
    elsif a[:type] && @typegraph[a[:type]]
      unless @types_used.include? a[:type]
        @types_used << a[:type]
        numericfind(@typegraph[a[:type]], "#{path}#{elem}")
        @types_used.pop()
      end
    end
    if a[:inherits] && @typegraph[a[:inherits]]
      numericfind(@typegraph[a[:inherits]], "#{path}#{elem}")
    end
  end
end

def isSimpleType(a)
  #pp a
  #byebug
  return isSimpleType(type: @typegraph[a[:type]]) if @typegraph[a[:type]]
  return isSimpleType(type: a[:inherits]) if a[:inherits]
  return isSimpleType(type: a[:type][0][:inherits]) if a[:type].is_a?(Array) && a[:type][0] && a[:type][0][:inherits]
  return true if a[:type] == "number"
  return true if a[:type] == "string"
  return false if a[:type] == "EMPTY"
  return false if a[:type] == "ExtendedContentType"
  return false if a[:type].nil?
  return false if a[:elems] && !a[:elems].empty?
  return false if a[:type].is_a?(Array) && a[:type][1] && a[:type][1][:elem]
  return false if @typegraph[a[:type]] && @typegraph[a[:type]].is_a?(Array)
end

def simpleattrfind(arr, path)
  arr.each do |a|
    elem = a[:elem] ? ( "/" + a[:elem] ) : ""
    if a[:attr] && !a[:attr].empty? && isSimpleType(a)
      puts "SIMPLE ATTRIBUTE: #{path}#{elem}\t#{a[:type] || a[:inherits]}"
    end
    if a[:elems] && !a[:elems].empty?
      simpleattrfind(a[:elems], "#{path}#{elem}")
    elsif a[:type] && @typegraph[a[:type]]
      unless @types_used.include? a[:type]
        @types_used << a[:type]
        simpleattrfind(@typegraph[a[:type]], "#{path}#{elem}")
        @types_used.pop()
      end
    end
    if a[:inherits]  && @typegraph[a[:inherits]]
      simpleattrfind(@typegraph[a[:inherits]], "#{path}#{elem}")
    end
  end
end

def complexattrfind(arr, path)
  #byebug
  arr.each do |a|
    #pp a
    elem = a[:elem] ? ( "/" + a[:elem] ) : ""
    if a[:attr] && !a[:attr].empty? && !isSimpleType(a)
      a[:attr].each do |aa|
        #byebug if /Address/.match a[:type]
        outtype = a[:type] || a[:inherits]
        #byebug
        outtype ||= "RefId" if aa[:attr] == "RefId"
        outtype ||= "Address" if %r{/Address$}.match path
        outtype ||= "PhoneNumber" if %r{/PhoneNumber$}.match path
        outtype ||= "MapReference" if %r{/MapReference$}.match path
        outtype ||= arr.to_s
        elem = a[:elem] ? ( "/" + a[:elem] ) : ""
        puts "COMPLEX ATTRIBUTE: #{path}#{elem}/@#{aa[:attr]}\t#{outtype}"
      end
    end
    if a[:elems] && !a[:elems].empty?
      complexattrfind(a[:elems], "#{path}#{elem}")
    elsif a[:type] && @typegraph[a[:type]]
      unless @types_used.include? a[:type]
        @types_used << a[:type]
        complexattrfind(@typegraph[a[:type]], "#{path}#{elem}")
        @types_used.pop()
      end
    end
    if a[:inherits]  && @typegraph[a[:inherits]]
      complexattrfind(@typegraph[a[:inherits]], "#{path}#{elem}")
    end
  end
end


objgraph = get_objgraph(File.open("objectgraph.txt", encoding: "utf-8"))
@typegraph = get_objgraph(File.open("typegraph.txt", encoding: "utf-8"))

# what are the base objects?
objgraph.keys.each { |k| puts "OBJECT: #{k}" }

# where are the attributes on complex elements?
objgraph.keys.each { |k| complexattrfind(objgraph[k], k) }

# where are the attributes on simple elements?
objgraph.keys.each { |k| simpleattrfind(objgraph[k], k) }

# where are the lists?
objgraph.keys.each { |k| listfind(objgraph[k], k) }

# where are the numbers?
objgraph.keys.each { |k| numericfind(objgraph[k], k) }

# where are the booleans?
objgraph.keys.each { |k| booleanfind(objgraph[k], k) }

# what are the paths to all types?
objgraph.keys.each { |k| xpathtype(objgraph[k], k, "OBJECT") }
@typegraph.keys.each { |k| xpathtype(@typegraph[k], k, "TYPE") }

@counter = 0
objgraph.keys.each { |k| traverse(objgraph[k], k, 0, 1, "TRAVERSE ALL, DEPTH 1") }
@counter = 0
objgraph.keys.each { |k| traverse(objgraph[k], k, 0, -1, "TRAVERSE ALL, DEPTH ALL") }
@counter = 0
@typegraph.keys.each { |k| traverse(@typegraph[k], k, 0, 1, "TRAVERSE COMMON TYPES, DEPTH 1") }
@counter = 0
@typegraph.keys.each { |k| traverse(@typegraph[k], k, 0, -1, "TRAVERSE COMMON TYPES, DEPTH ALL") }

puts "END"
