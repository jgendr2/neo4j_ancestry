module Neo4jAncestry
  module NodeInstanceMethods
    
    # Neo4j Association Methods
    # ========================================================================================

    # The neoid gem provides a neo_node method, which returns an object
    # representing the node in the neo4j database that corresponds to this
    # object.
    # 
    # Overriding the neo_node method ensures that for STI the same neo_node
    # is returned for the same object regardless of the subclass.
    # 
    # That means: group.neo_node == group.becomes(SpecialGroup).neo_node
    #
    def neo_node
      super || self.becomes(self.class.base_class).neo_node
    end
    
    # The unique id of the neo4j node that corresponds to this object.
    #
    def neo_id
      neo_node.try(:neo_id)
    end
    
    
    # Basic Traversing Methods
    # ========================================================================================
    
    # Methods to query the neo4j database for parents, children,
    # ancestors, descendants and siblings.
    #
    def parents
      find_related_nodes_via_cypher("
        match (parents)-[:is_parent_of]->(self)
        return parents
      ")
    end
    def children
      find_related_nodes_via_cypher("
        match (self)-[:is_parent_of]->(children)
        return children
      ")
    end
    def ancestors(options = {})
      find_related_nodes_via_cypher("
        match (self)<-[:is_parent_of*1..100]-(ancestors)
        #{where('ancestors.ar_type' => options[:type])}
        return distinct ancestors
      ")
    end
    def descendants(options = {})
      find_related_nodes_via_cypher("
        match (self)-[:is_parent_of*1..100]->(descendants)
        #{where('descendants.ar_type' => options[:type])}
        return distinct descendants
      ")
    end
    def siblings
      find_related_nodes_via_cypher("
        match (self)<-[:is_parent_of]-(parent)-[:is_parent_of]->(siblings)
        return distinct siblings
      ")
    end
    
    
    # Route Traversing Methods
    # ========================================================================================
    
    def find_routes_to(destination_object, options = {})
      
      if options[:via]
        unless options[:via].kind_of? Array
          options[:via] = [ options[:via] ]
        end
      end
      options[:via] ||= []
      
      counter = 0
      via_object_names = []
      via_object_declarations = options[:via].collect do |active_record_object|
        counter += 1
        via_object_names << "obj#{counter}"
        "obj#{counter} = node(#{active_record_object.neo_id})"
      end
      
      via_object_declarations_str = via_object_declarations.join(', ')
      via_object_declarations_str += ", " if via_object_declarations_str.present?
      nodes_to_connect = ["self"] + via_object_names + ["destination_object"]
      
      find_related_nodes_via_cypher(",
        #{via_object_declarations_str}
        destination_object = node(#{destination_object.neo_id})
        match paths = (#{nodes_to_connect.join(')-[:is_parent_of*1..100]-(')})
        return paths
        order by length(paths)
      ")

      
      # find_related_nodes_via_cypher(",
      #   other_object = node(#{other_object.neo_id})
      #   match path = (self)-[:is_parent_of*1..100]-(other_object)
      #   return path
      # ")
  
      # self.neo_node.all_paths_to(other_object.neo_node)
      #   .both(:is_parent_of).depth(100).nodes.collect do |path|
      #     path.collect { |neo_node| neo_node.to_active_record }
      #   end
      
    end
    
    
    # Query Methods 
    # ========================================================================================
    
    # This method returns all ActiveRecord objects found by a cypher
    # neo4j query defined through the given query_string.
    # 
    # Within the query_string, no START expression is needed, 
    # because the start node is given by the neo_node of this
    # structureable object. It is referred to just by 'self'. 
    #
    # Example:
    #   group.find_related_nodes_via_cypher("
    #     match (self)-[:is_parent_of]->(children)
    #     return children
    #   ")  # =>  [child_group1, child_group2, ...]
    #
    def find_related_nodes_via_cypher(query_string)
      query_string = "
        start self=node(#{neo_id})
        #{query_string}
      "
      result = CypherResult.new(Neoid.db.execute_query(query_string))
      result.to_active_record || []
    end
    
    # This is a helper for Cypher where clauses.
    # Example:
    #
    #     where( 'user.name' => 'Bob', 'user.age' => 16 )
    #
    # results in
    #
    #     "WHERE user.name = 'Bob' AND 'user.age' = '16'"
    #
    def where(conditions_hash = {})
      conditions_array = []
      conditions_hash.each do |key, value|
        conditions_array << "#{key} = '#{value}'" if value.present?
      end
      conditions_str = ""
      if conditions_array.count > 0
        conditions_str = "WHERE " + conditions_array.join(" AND ")
      end
      return conditions_str
    end
  end
end