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
          sv.split( ", " ).each do |sub_sv|
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

::ActiveRecord::Associations::JoinDependency::JoinBase.class_eval do
  def instantiate(row, aliases, column_types = {}, &block)
    base_klass.instantiate(extract_record(row, aliases), column_types, &block)
  end
end

::ActiveRecord::Associations::JoinDependency.class_eval do
  def instantiate(result_set, aliases)
    primary_key = aliases.column_alias(join_root, join_root.primary_key)

    seen = Hash.new { |h,parent_klass|
      h[parent_klass] = Hash.new { |i,parent_id|
        i[parent_id] = Hash.new { |j,child_klass| j[child_klass] = {} }
      }
    }

    model_cache = Hash.new { |h,klass| h[klass] = {} }
    parents = model_cache[join_root]
    column_aliases = aliases.column_aliases join_root

    message_bus = ActiveSupport::Notifications.instrumenter

    payload = {
        record_count: result_set.length,
        class_name: join_root.base_klass.name
    }

    message_bus.instrument('instantiation.active_record', payload) do
      result_set.each { |row_hash|
        parent_key = primary_key ? row_hash[primary_key] : row_hash
        # DISTINCTION PART > join_root.instantiate(row_hash, column_aliases, aliases.slice_selected_attr_types( result_set.column_types ) )
        # PREVIOUS         > join_root.instantiate(row_hash, column_aliases )
        parent = parents[parent_key] ||= join_root.instantiate(row_hash, column_aliases, aliases.slice_selected_attr_types( result_set.column_types ) )
        construct(parent, join_root, row_hash, result_set, seen, model_cache, aliases)
      }
    end

    parents.values
  end
end


::ActiveRecord::FinderMethods.class_eval do
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


