# frozen_string_literal: true

require "time"

module XXXDownload
  module Data
    class JaxSlayherApiScene < Base
      class NoVideosError < StandardError; end

      BASE_URL = "https://jaxslayher.com"
      DOWNLOAD_URL = "#{BASE_URL}/m_a/dl/%<folder>s/%<file_name>s".freeze
      NETWORK_NAME = "Jax Slayher"
      COLLECTION_TAG = "JAX"

      # Maps the quality prefix of a video file name to a StreamingLinks resolution key
      QUALITY_KEY_MAP = {
        "4k" => "res_2160p",
        "hd" => "res_1080p",
        "sd" => "res_720p",
        "mobile" => "res_360p"
      }.freeze

      # Maps the quality prefix of a video file name to a human-readable resolution
      RESOLUTION_MAP = {
        "4k" => "2160",
        "hd" => "1080",
        "sd" => "720",
        "mobile" => "360"
      }.freeze

      attribute :id, Types::Integer
      attribute :title, Types::String
      attribute :folder, Types::String
      attribute :release_date, Types::String
      attribute :performers, Types::Array.of(Types::Hash.schema(name: Types::String))
      attribute? :tags, Types::CustomSet
      attribute :videos, Types::Array.of(
        Types::Hash.schema(
          file_name: Types::String,
          quality_rank: Types::Integer
        )
      )

      def initialize(attributes)
        super
        validate!
      end

      # @return [Data::Scene]
      def to_scene
        Scene.new(
          {
            video_link:,
            clip_id: id,
            title:,
            actors:,
            network_name: NETWORK_NAME,
            collection_tag: COLLECTION_TAG,
            tags: tags.to_a,
            release_date: formatted_release_date,
            download_sizes:,
            downloading_links:
          }.merge(Scene::NOT_LAZY)
        )
      end

      private

      def actors = performers.map { |performer| Actor.unknown(performer[:name]) }

      def video_link = "#{BASE_URL}/members/video/#{folder}"

      def formatted_release_date = Time.parse(release_date).strftime("%Y-%m-%d")

      def sorted_videos = videos.sort_by { |video| video[:quality_rank] }

      def download_sizes = sorted_videos.filter_map { |video| RESOLUTION_MAP[quality_prefix(video)] }

      def downloading_links
        links = {}
        default = []
        sorted_videos.each do |video|
          link = format(DOWNLOAD_URL, folder:, file_name: video[:file_name])
          default.push(link)
          resolution_key = QUALITY_KEY_MAP[quality_prefix(video)]
          links[resolution_key] = link if resolution_key
        end
        links["default"] = default
        links
      end

      def quality_prefix(video) = video[:file_name].split("_").first.downcase

      def validate!
        raise NoVideosError, "Scene #{title} has no downloadable videos" if videos.empty?
      end
    end
  end
end
