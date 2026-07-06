class RenameImageResultModelName < ActiveRecord::Migration[7.1]
  def change
    rename_column :image_results, :model_name, :checkpoint_name
    rename_index :image_results, "index_image_results_on_model_name", "index_image_results_on_checkpoint_name"
  end
end
