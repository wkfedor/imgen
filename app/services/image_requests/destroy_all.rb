# frozen_string_literal: true

module ImageRequests
  class DestroyAll
    def self.call
      new.call
    end

    def call
      deleted = { requests_deleted: 0, local_deleted: 0, remote_deleted: 0 }

      ImageRequest.includes(:image_results).find_each do |request|
        result = request.destroy_with_images!
        deleted[:requests_deleted] += 1
        deleted[:local_deleted] += result[:local_deleted]
        deleted[:remote_deleted] += result[:remote_deleted]
      end

      deleted
    end
  end
end
