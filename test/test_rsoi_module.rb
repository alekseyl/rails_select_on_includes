require 'test_helper'
require 'rails_select_on_includes'

class RsoiModuleTest < ActiveSupport::TestCase
  test 'all kind of nested attributes' do
    assert_raise(NoMethodError) { WarGroup.first.warriors_count }
    assert( WarGroup.test_select('Uruk').where( coalition: 'nazguls & co' ).first.warriors_count == 1 )
    assert( WarGroup.test_select_without_as('Uruk').where( coalition: 'nazguls & co' ).first.warriors_count == 1 )

    assert( !WarGroup.test_select('Uruk').order('combatants.strength').where( coalition: 'nazguls & co' ).first.id.nil?)

    assert( WarGroup.test_select('Frodo').where( coalition: 'fellowship & co' ).first.warriors_count == 1 )


    assert_raise(NoMethodError) { WarGroup.first.biggest_coalition }
    assert( WarGroup.test_nested_as('Uruk').all?{ |wg| wg.biggest_coalition == 2 })
  end
end



