begin
  require "neoid"
rescue 
  print "WARNING: neo4j database not found.\n"
end
#require "models/neo4j_ancestry/active_record_additions"
#require "models/neo4j_ancestry/node_instance_methods"
#require "models/neo4j_ancestry/link"
require "neo4j_ancestry/railtie"
require "neo4j_ancestry/version"