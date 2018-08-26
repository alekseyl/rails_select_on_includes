require 'active_record'
require 'minitest/autorun'
require 'byebug'
require 'niceql'

ActiveRecord::Base.establish_connection(
    adapter:  'sqlite3',
    database: ':memory:'
)

ActiveRecord::Base.connection.create_table :combatants do |t|
  t.string :name
  t.integer :strength
  t.integer :dexterity
  t.integer :life
  t.string :speciality
  t.integer :war_group_id
end

ActiveRecord::Base.connection.create_table :war_groups do |t|
  t.string :coalition
end

class WarGroup < ActiveRecord::Base
  scope :test_select, -> (name) do
    includes(:combatants).where(combatants: {name: name }).select( 'COUNT(combatants.id) as warriors_count' )
  end

  scope :test_nested_as, ->( name ) do
    includes(:combatants).where(combatants: {name: name }).select( <<-NESTED )
        ( SELECT MAX( warriors_count ) as maxw FROM ( SELECT COUNT(id) AS warriors_count FROM combatants GROUP BY war_group_id ) as t ) as biggest_coalition
    NESTED
  end

  has_many :combatants
end

class Combatant < ActiveRecord::Base
  belongs_to :war_group
end

class ActiveSupport::TestCase
  include ActiveRecord::TestFixtures
  self.fixture_path = "#{Dir.pwd}/test/fixtures/"
  self.file_fixture_path = self.fixture_path + "files"

  fixtures :all

  def create_fixtures(*fixture_set_names, &block)
    FixtureSet.create_fixtures(ActiveSupport::TestCase.fixture_path, fixture_set_names, {}, &block)
  end

end

Minitest.after_run do
  ActiveRecord::Base.connection.drop_table :combatants
  ActiveRecord::Base.connection.drop_table :war_groups
end
