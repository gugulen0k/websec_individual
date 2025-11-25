class CreateGuests < ActiveRecord::Migration[8.0]
  def change
    create_table :guests do |t|
      t.string :name
      t.text :message
      t.string :email

      t.timestamps
    end
  end
end
