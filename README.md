# New Features
Selected virtual attributes will be now typecasted as usual attributes

#Rails version
Supports rails 4.x and rails 5-5.1.4, and 5.1.5 now! 

Master is now runs on rails 5.1.5, 
rails_5.1.4 branch is for rails less than 5.1.5,
rails_4 branch is for rails 4 support

# RailsSelectOnIncludes

This gem solves issue in rails: https://github.com/rails/rails/issues/15185 for base_class. 

It was impossible to select virtual attributes to object from its relations or any other way 
when using includes and where ( actually when includes becomes eager_load, i.e. when you add not SOME_CONDITION, but SOME_CONDITION_ON_INCLUDES, http://blog.bigbinary.com/2013/07/01/preload-vs-eager-load-vs-joins-vs-includes.html ). 

Example from upper rails issue: 

```ruby
post = Post.includes(:comments).select("posts.*, 1 as testval").where( SOME_CONDITION ).first
post.testval # Undefined method!
```

This gem solves problem for base class i.e. 

```ruby
post = Post.includes(:comments).select("posts.*, 1 as testval").where( SOME_CONDITION ).first
post.testval # 1
```

but of course it doesn't include virtual attributes in included relations

```ruby
post = Post.includes(:comments).select("posts.*, 1 as testval").where( SOME_CONDITION ).first
post.comments.first.testval # Undefined method!
```

# RailsSelectOnIncludes (Рус)

Данный gem решает проблему в рельсах с виртуальными аттрибутами при использовании includes, 
когда рельсы собирают в запрос в joins с алиасами на все аттрибуты. В настоящий момент в модель не собираются 
никаким боком виртуальные аттрибуты ( имеется ввиду когда includes ведет себя как eager_load и создает сложный одинарный запрос, подробнее: http://blog.bigbinary.com/2013/07/01/preload-vs-eager-load-vs-joins-vs-includes.html ).

В частности проблема описана здесь: https://github.com/rails/rails/issues/15185 

В коде примера по ссылке выше это выглядит так: 

```ruby
post = Post.includes(:comments).select("posts.*, 1 as testval").where( SOME_CONDITION ).first
post.testval # Undefined method!
```

Данный gem решает эту проблему для базового класса, т.е.:  

```ruby
post = Post.includes(:comments).select("posts.*, 1 as testval").where( SOME_CONDITION ).first
post.testval # 1
```

Но это не касается, объектов попадающих под инклюд:

```ruby
post = Post.includes(:comments).select("posts.*, 1 as testval").where( SOME_CONDITION ).first
post.comments.first.testval # Undefined method!
```


## Installation 

Add this line to your application's Gemfile:

```ruby
#rails 4
gem 'rails_select_on_includes', '~> 0.4.10' 

#rails 5
gem 'rails_select_on_includes', '~> 0.5.6' 
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install rails_select_on_includes

## Usage

Works out of the box, monkey-patches base-class alias columns, for select attributes, and JoinBase with JoinDependency to proper typecasting. 

It not affecting query creation, since query already contains all columns, i.e. to_sql returns same string.
Works with selection in all formats:

  1. 'table_name.column' or 'table_name.column as column_1' will be parsed! distinct on can be used also
  2. '(subquery with AS) AS column_1 '
  3. Select with aliased arel function: .select(Comment.arel_table[:id].count.as('comments_count'))
  4. Select with aliased arel attirubte: .select(Comment.arel_table[:column].as('column_alias'))


## Usage (рус)

Работает из коробки, нежно манки-патча алиасы прямо перед инстанцированием коллекции, а так же не менее нежно JoinBase и JoinDependency :), чтобы полученные аттрибуты были приличных типов, а не только строк, не влияет на создаваемый запрос в БД т.е to_sql не меняется.  

Поддерживает select в следующих форматах :

  1. 'table_name.column' or 'table_name.column as column_1' will be parsed! distinct on can be used also
  2. '(subquery with AS) AS column_1 '
  3. Select with aliased arel function: .select(Comment.arel_table[:id].count.as('comments_count'))
  4. Select with aliased arel attirubte: .select(Comment.arel_table[:column].as('column_alias'))

## Testing 

rake test

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/rails_select_on_includes.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

