require 'active_support/deprecation'
require 'active_support/core_ext/string/filters'


::ActiveRecord::Associations::JoinDependency::Aliases.class_eval do # :nodoc:
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

    @virtual_attributes_names = []
  end
  # valid formats are:
  # 'table_name.column' or 'table_name.column as column_1' will be parsed! distinct on can be used also
  # '(subquery with AS) AS column_1 '
  # Select with aliased arel function: .select(Comment.arel_table[:id].count.as('comments_count'))
  # Select with aliased arel attirubte: .select(Comment.arel_table[:column].as('column_alias'))
  def update_aliases_to_select_values( select_values )
    return if select_values.blank?
    select_values.each do |sv|

      # if sv is symbol that we assume that its a base table column and it will be aliased and added as usual
      # all we need is some specials joins+select from related tables
      case sv
       when String
          sv.split(/,[\s$]*/).each do |sub_sv|
            if sub_sv[/.+ as .+/i]
              add_virtual_attribute(sub_sv.rpartition(/ as /i).last.strip)
            elsif sub_sv[/.+\.[^\*]+/]
              add_virtual_attribute(sub_sv[/\..+/][1..-1].strip)
            end
          end
        when Arel::Nodes::As
          add_virtual_attribute(sv.right)
        when Arel::Nodes::TableAlias
          add_virtual_attribute(sv.right)
        when Arel::Nodes::Function
          add_virtual_attribute(sv.alias) if sv.alias.present?
      end
    end
  end

  def slice_selected_attr_types( column_types )
    column_types.slice( *@virtual_attributes_names )
  end

  private
  def flatten_hash_values( some_hash )
    some_hash.values.map{ |value| value.is_a?(Hash) ? flatten_hash_values( value ) : value }.flatten
  end

  def add_virtual_attribute(selected_column)
    @base_class_node_aliases << [selected_column, selected_column]
    @virtual_attributes_names << selected_column
  end
end

#
::ActiveRecord::Associations::JoinDependency::JoinBase.class_eval do
  def instantiate(row, aliases, column_types = {}, &block)
    base_klass.instantiate(extract_record(row, aliases), column_types, &block)
  end
end


::ActiveRecord::Associations::JoinDependency.class_eval do
  def instantiate(result_set, &block)
    primary_key = aliases.column_alias(join_root, join_root.primary_key)

    seen = Hash.new { |i, object_id|
      i[object_id] = Hash.new { |j, child_class|
        j[child_class] = {}
      }
    }

    model_cache = Hash.new { |h, klass| h[klass] = {} }
    parents = model_cache[join_root]
    column_aliases = aliases.column_aliases join_root

    message_bus = ActiveSupport::Notifications.instrumenter

    payload = {
        record_count: result_set.length,
        class_name: join_root.base_klass.name
    }

    message_bus.instrument("instantiation.active_record", payload) do
      result_set.each { |row_hash|
        parent_key = primary_key ? row_hash[primary_key] : row_hash
        # DISTINCTION PART > join_root.instantiate(row_hash, column_aliases, aliases.slice_selected_attr_types( result_set.column_types ) )
        # PREVIOUS         > join_root.instantiate(row_hash, column_aliases )
        # parent = parents[parent_key] ||= join_root.instantiate(row_hash, column_aliases, &block)

        parent = parents[parent_key] ||=
            join_root.instantiate(row_hash, column_aliases, aliases.slice_selected_attr_types( result_set.column_types ), &block )
        construct(parent, join_root, row_hash, result_set, seen, model_cache, aliases)
      }
    end

    parents.values
  end
end


::ActiveRecord::Relation.class_eval do
  private

  def exec_queries(&block)
    skip_query_cache_if_necessary do
      @records =
          if eager_loading?
            apply_join_dependency do |relation, join_dependency|
              if ActiveRecord::NullRelation === relation
                []
              else
                rows = connection.select_all(relation.arel, "SQL")
                #1 DISTINCTION IS HERE:
                # now we gently mokey-patching existing column aliases with select values
                join_dependency.aliases.update_aliases_to_select_values(values[:select]) unless values[:select].blank?

                join_dependency.instantiate(rows, &block)
              end.freeze
            end
          else
            klass.find_by_sql(arel, &block).freeze
          end

      preload = preload_values
      preload += includes_values unless eager_loading?
      preloader = nil
      preload.each do |associations|
        preloader ||= build_preloader
        preloader.preload @records, associations
      end

      @records.each(&:readonly!) if readonly_value

      @loaded = true
      @records
    end
  end


end
