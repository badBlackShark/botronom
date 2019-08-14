require "db"
require "pg"

class Db
  getter db : DB::Database

  def initialize
    succeeded = false

    # This is in case the app needs longer to start than the db.
    db = nil
    until succeeded
      begin
        db = DB.open("postgres://db:5432/botronom_db?retry_attempts=3&retry_delay=5")
        succeeded = true
      rescue e : Exception
        sleep 2
      end

    end
    @db = db.not_nil!
  end

  def close
    @db.close
  end

  def create_table(name : String, columns : Array(String))
    @db.exec("create table if not exists #{name} (#{columns.join(", ")})")
  end

  def get_value(table : String, column : String, filter : String, value, klass : Class)
    @db.query_one?("select #{column} from #{table} where #{filter} = #{value} limit 1", as: klass)
  end

  def delete_row(table : String, column : String, value)
    @db.exec("delete from #{table} where #{column} = #{value}")
  end

  def update_value(table : String, column : String, value, filter : String, filter_value)
    @db.exec("update #{table} set #{column} = ($1) where #{filter} = #{filter_value}", value)
  end

  def insert_row(table : String, values)
    placeholders = Array(String).new
    values.size.times { |i| placeholders << "$#{i+1}" }
    placeholders = "(" + placeholders.join(", ") + ")"

    @db.exec("insert into #{table} values #{placeholders}", values)
  end
end
