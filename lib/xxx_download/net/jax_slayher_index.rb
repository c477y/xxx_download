# frozen_string_literal: true

module XXXDownload
  module Net
    class JaxSlayherIndex < BaseIndex
      TAG = "JAX_SLAYHER_INDEX"
      BASE_URI = "https://jaxslayher.com"
      base_uri BASE_URI

      UPDATES_PATH = "/m_a/updates"
      MODEL_PATH = "/m_a/get_model"
      VIDEO_PATH = "/m_a/get_video"

      # Opening the members area when logged out presents the login form; once the
      # user signs in the session cookie below is set.
      LOGIN_URL = "#{BASE_URI}/members".freeze
      SESSION_COOKIE_KEY = "jaxxx"

      def initialize
        super
        apply_cookie(config.cookie)
      end

      # @param [String] url a link to an individual scene, e.g. /members/video/<folder>
      # @return [Array<Data::Scene>]
      def search_by_all_scenes(url)
        uri = URI.parse(url)
        verify_urls!(uri, %r{/members/video/[\w-]+})

        folder = uri.path.split("/").last
        [fetch_scene(folder)].compact
      end

      # @param [String] url a link to a listing page, e.g. /members/<page>
      # @return [Array<Data::Scene>]
      def search_by_page(url)
        uri = URI.parse(url)
        verify_urls!(uri, %r{/members/\d+})

        page = uri.path.split("/").last
        response = get_json("#{UPDATES_PATH}/#{page}")
        build_scenes(folders_from(response.first))
      end

      # @param [String] url a link to a model page, e.g. /members/model/<slug>/<id>
      # @return [Array<Data::Scene>]
      def search_by_actor(url)
        uri = URI.parse(url)
        verify_urls!(uri, %r{/members/model/[\w-]+/\d+})

        model_id = uri.path.split("/").last
        response = get_json("#{MODEL_PATH}/#{model_id}")
        build_scenes(folders_from(response))
      end

      # @param [String] resource a model page URL, e.g. /members/model/<slug>/<id>
      # @return [String]
      def actor_name(resource)
        uri = URI.parse(resource)
        slug = uri.path.split("/")[-2]
        raise FatalError, "[#{TAG}] Unable to extract performer from #{resource}" if slug.blank?

        slug.gsub(/[_-]/, " ").split.map(&:capitalize).join(" ")
      end

      private

      # Performs the API request and, if the session has expired (401), refreshes the
      # cookies through the browser once before retrying.
      #
      # @param [String] path
      # @return [Array, Hash] the parsed JSON response
      def get_json(path, refreshed: false)
        handle_response! { self.class.get(path) }
      rescue UnauthorizedError => e
        raise e if refreshed

        XXXDownload.logger.warn "[#{TAG}] Session expired. Opening browser to refresh cookies..."
        apply_cookie(authenticator.request_cookie(force_request: true, cookie_key: SESSION_COOKIE_KEY))
        get_json(path, refreshed: true)
      end

      def apply_cookie(cookie) = self.class.headers("Cookie" => cookie)

      def authenticator = @authenticator ||= SiteAuthenticator.new(LOGIN_URL)

      def folders_from(listings)
        return [] if listings.blank?

        listings.filter_map { |listing| listing.deep_symbolize_keys[:folder] }
      end

      def build_scenes(folders)
        folders.filter_map { |folder| fetch_scene(folder) }
      end

      # @param [String] folder
      # @return [Data::Scene, nil]
      def fetch_scene(folder)
        response = get_json("#{VIDEO_PATH}/#{folder}")
        scene = response.is_a?(Array) ? response.first : response
        if scene.blank?
          XXXDownload.logger.warn "[#{TAG}] No scene found for #{folder}. Skipping..."
          return nil
        end

        transform_scene(scene.deep_symbolize_keys)
      rescue Data::JaxSlayherApiScene::NoVideosError => e
        XXXDownload.logger.warn "[#{TAG}] #{e.message}. Skipping..."
        nil
      rescue APIError => e
        XXXDownload.logger.warn "[#{TAG}] Unable to fetch scene #{folder}: #{e.message}. Skipping..."
        nil
      end

      def transform_scene(scene)
        Data::JaxSlayherApiScene.new(
          id: scene[:id],
          title: scene[:title],
          folder: scene[:folder],
          release_date: scene[:release_date],
          performers: scene[:models].map { |model| { name: model[:name] } },
          tags: Array(scene[:tags]).map { |tag| tag[:tag_name] },
          videos: Array(scene[:videos]).map { |video| video.slice(:file_name, :quality_rank) }
        ).to_scene
      end
    end
  end
end
