require "byebug"; byebug
require "pp"

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
    else
      latest = graph[root]
    end

    line.sub!(/^\s*##\d+/, "")
    next unless /\S/.match line

    if /PARENT/.match(line)
      %r{PARENT (?<root>\S+)//} =~ line
      graph[root] = []
      graph[root] << { attr: [] }
    elsif /%Inherits:\s+(?<inherits>[^;]+);/ =~ line
      latest[-1][:inherits] = inherits
    elsif /ATTRIBUTE/.match(line)
      /ATTRIBUTE (?<attr>\S+?):\s+(?<type>\S+);/ =~ line
      latest[-1][:attr] << { attr: attr, type: type }
    else
      /(?<elem>\S+?):\s+(?<list>LIST )?(?<type>[^;]+);/ =~ line
      latest << { elem: elem, type: type, attr: [], elems: [], list: !list.nil? }
    end
  end
  graph
end

@objgraph = {}
@typegraph = {}

def listfind(arr, path)
  arr.each do |a|
    #pp a
    if a[:list] 
      puts "LIST: #{path}/#{a[:elem]}"
    elsif a[:elems] && !a[:elems].empty?
        listfind(a[:elems], "#{path}/#{a[:elem]}")
    elsif a[:type] && @typegraph[a[:type]]
      listfind(@typegraph[a[:type]], "#{path}/#{a[:elem]}")
    end
  end
end

def booleanfind(arr, path)
  arr.each do |a|
    #pp a
    if a[:type] == "boolean"
      puts "BOOLEAN: #{path}/#{a[:elem]}"
    elsif a[:elems] && !a[:elems].empty?
        booleanfind(a[:elems], "#{path}/#{a[:elem]}")
    elsif a[:type] && @typegraph[a[:type]]
      booleanfind(@typegraph[a[:type]], "#{path}/#{a[:elem]}")
    end
  end
end

def numericfind(arr, path)
  arr.each do |a|
    #pp a
    if a[:type] == "number"
      puts "NUMERIC: #{path}/#{a[:elem]}"
    elsif a[:elems] && !a[:elems].empty?
        numericfind(a[:elems], "#{path}/#{a[:elem]}")
    elsif a[:type] && @typegraph[a[:type]]
      numericfind(@typegraph[a[:type]], "#{path}/#{a[:elem]}")
    end
  end
end

def simpleattrfind(arr, path)
  arr.each do |a|
    #pp a
    #byebug
    if a[:type] && a[:type] != "EMPTY" && a[:type] != "ExtendedContentType" && a[:attr] && !a[:attr].empty?
      puts "SIMPLE ATTRIBUTE: #{path}/#{a[:elem]}\t#{a[:type]}"
    end
    if a[:elems] && !a[:elems].empty?
        simpleattrfind(a[:elems], "#{path}/#{a[:elem]}")
    elsif a[:type] && @typegraph[a[:type]]
      simpleattrfind(@typegraph[a[:type]], "#{path}/#{a[:elem]}")
    end
  end
end

def complexattrfind(arr, path)
  arr.each do |a|
    #pp a
    if (!a[:type] || a[:type] == "EMPTY" || a[:type] == "ExtendedContentType") && a[:attr] && !a[:attr].empty?
      a[:attr].each do |aa|
        puts "COMPLEX ATTRIBUTE: #{path}/#{a[:elem]}/@#{aa[:attr]}"
      end
    end
    if a[:elems] && !a[:elems].empty?
        complexattrfind(a[:elems], "#{path}/#{a[:elem]}")
    elsif a[:type] && @typegraph[a[:type]]
      complexattrfind(@typegraph[a[:type]], "#{path}/#{a[:elem]}")
    end
  end
end


objgraph = get_objgraph(File.open("objectgraph.txt"))
@typegraph = get_objgraph(File.open("typegraph.txt"))

# where are the lists?
objgraph.keys.each { |k| listfind(objgraph[k], k) }

# where are the attributes on simple elements?
objgraph.keys.each { |k| simpleattrfind(objgraph[k], k) }

# where are the attributes on complex elements?
objgraph.keys.each { |k| complexattrfind(objgraph[k], k) }

# where are the numbers?
objgraph.keys.each { |k| numericfind(objgraph[k], k) }

# where are the booleans?
objgraph.keys.each { |k| booleanfind(objgraph[k], k) }
