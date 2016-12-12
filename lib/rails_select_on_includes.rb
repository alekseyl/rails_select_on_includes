require 'active_support/deprecation'
require 'active_support/core_ext/string/filters'

module ActiveRecord
  module Associations
    class JoinDependency # :nodoc:

      class Aliases # :nodoc:
        def initialize(tables)
          @tables = tables
          @alias_cache = tables.each_with_object({}) { |table,h|
            h[table.node] = table.columns.each_with_object({}) { |column,i|
              i[column.name] = column.alias
            }
          }
          @name_and_alias_cache = tables.each_with_object({}) { |table,h|
            h[table.node] = table.columns.map { |column|
              [column.name, column.alias]
            }
            @base_class_node_aliases ||= h[table.node] if table.node.is_a?(ActiveRecord::Associations::JoinDependency::JoinBase)
          }
        end
        # valid formats are:
        # 1 'table_name.column' or 'table_name.column as column_1' will be parsed! distinct on can be used also
        # 2 {table_name: column} or { table_name: [column1, column2] }
        # 3 table_name: 2
        def update_aliases_to_select_values( select_values )
          return if select_values.blank?
          select_values.each do |sv|
            # if sv is symbol that we assume that its a base table column and it will be aliased and added as usual
            # all we need is some specials joins+select from related tables
            if sv.is_a?(Hash)
              flatten_hash_values(sv).each{|sub_sv| @base_class_node_aliases << [sub_sv, sub_sv] }
            elsif sv.is_a?(String)
              # this is the case of long raw select
              sv.split( ", " ).each do |sub_sv|
                if sub_sv[/.+ as .+/i]
                  selected_column = sub_sv[/ as .+/i][4..-1]
                  @base_class_node_aliases << [selected_column, selected_column]
                elsif sub_sv[/.+\.[^\*]+/]
                  selected_column = sub_sv[/\..+/][1..-1]
                  @base_class_node_aliases << [selected_column, selected_column]
                end
              end
            end
          end
        end

        private
        def flatten_hash_values( some_hash )
          some_hash.values.map{ |value| value.is_a?(Hash) ? flatten_hash_values( value ) : value }.flatten
        end
      end
    end
  end
end
module ActiveRecord
  module FinderMethods

    def find_with_associations
      # NOTE: the JoinDependency constructed here needs to know about
      #       any joins already present in `self`, so pass them in
      #
      # failing to do so means that in cases like activerecord/test/cases/associations/inner_join_association_test.rb:136
      # incorrect SQL is generated. In that case, the join dependency for
      # SpecialCategorizations is constructed without knowledge of the
      # preexisting join in joins_values to categorizations (by way of
      # the `has_many :through` for categories).
      #
      join_dependency = construct_join_dependency(joins_values)

      aliases  = join_dependency.aliases
      relation = select aliases.columns
      relation = apply_join_dependency(relation, join_dependency)

      if block_given?
        yield relation
      else
        if ActiveRecord::NullRelation === relation
          []
        else
          arel = relation.arel
          rows = connection.select_all(arel, 'SQL', arel.bind_values + relation.bind_values)
          #DISTINCTION IS HERE:
          # now we gently mokey-patching existing column aliases with select values
          aliases.update_aliases_to_select_values(values[:select]) unless values[:select].blank?

          join_dependency.instantiate(rows, aliases)
        end
      end
    end

  end
end

