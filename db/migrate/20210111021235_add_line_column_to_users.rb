class AddLineColumnToUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :line_image_url, :string
    add_column :users, :line_description, :string
    change_column :users, :email, :string, :null =>  true
  end
end
