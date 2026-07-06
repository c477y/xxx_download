# frozen_string_literal: true

require "rspec"

RSpec.describe XXXDownload::Net::JaxSlayherIndex, type: :file_support do
  subject(:index) { described_class.new }

  include_context "config provider"
  let(:site) { "jaxslayher" }

  describe "#search_by_all_scenes" do
    context "when the scene exists" do
      before do
        VCR.use_cassette("jax_slayher/index_search_by_all_scenes_valid_scene") do
          @result = index.search_by_all_scenes(resource)
        end
      end

      let(:resource) { "https://jaxslayher.com/members/video/6619f4a3-8ca7-49cc-9f1d-5014e54da6ef" }

      it "returns the expected scene", :aggregate_failures do
        expect(@result.length).to eq(1)
        scene = @result.first
        expect(scene).to be_a(XXXDownload::Data::Scene)
        expect(scene.title).to eq("That Legendary Ass")
        expect(scene.network_name).to eq("Jax Slayher")
        expect(scene.actors.map(&:name)).to match_array(["Richelle Ryan", "Jax Slayher"])
        expect(scene.downloading_links).to be_a(XXXDownload::Data::StreamingLinks)
        expect(scene.downloading_links.fhd)
          .to eq("https://jaxslayher.com/m_a/dl/6619f4a3-8ca7-49cc-9f1d-5014e54da6ef/hd_that_legendary_ass.mp4")
      end
    end

    context "when the scene does not exist" do
      before do
        VCR.use_cassette("jax_slayher/index_search_by_all_scenes_invalid_scene") do
          @result = index.search_by_all_scenes(resource)
        end
      end

      let(:resource) { "https://jaxslayher.com/members/video/00000000-0000-0000-0000-000000000000" }

      it { expect(@result).to be_empty }
    end
  end

  describe "#search_by_page" do
    before do
      VCR.use_cassette("jax_slayher/index_search_by_page_valid") do
        @result = index.search_by_page(resource)
      end
    end

    let(:resource) { "https://jaxslayher.com/members/2" }

    it "returns a scene for every listed folder", :aggregate_failures do
      expect(@result.length).to eq(2)
      expect(@result).to all(be_a(XXXDownload::Data::Scene))
      expect(@result).to all(have_attributes(lazy?: false))
      expect(@result.map(&:title)).to match_array(["A True Creampie Lover", "Natural E Cups"])
      expect(@result).to all(have_attributes(downloading_links: be_a(XXXDownload::Data::StreamingLinks)))
    end
  end

  describe "#search_by_actor" do
    context "when the model has scenes" do
      before do
        VCR.use_cassette("jax_slayher/index_search_by_actor_valid") do
          @result = index.search_by_actor(resource)
        end
      end

      let(:resource) { "https://jaxslayher.com/members/model/richelle_ryan/148" }

      it "returns the model's scenes", :aggregate_failures do
        expect(@result.length).to eq(1)
        expect(@result.first.title).to eq("That Legendary Ass")
        expect(@result.first.actors.map(&:name)).to include("Richelle Ryan")
      end
    end

    context "when the model has no scenes" do
      before do
        VCR.use_cassette("jax_slayher/index_search_by_actor_empty") do
          @result = index.search_by_actor(resource)
        end
      end

      let(:resource) { "https://jaxslayher.com/members/model/nobody/99999999" }

      it { expect(@result).to be_empty }
    end
  end

  describe "#actor_name" do
    context "when the resource is a valid model URL" do
      let(:resource) { "https://jaxslayher.com/members/model/richelle_ryan/148" }

      it { expect(index.actor_name(resource)).to eq("Richelle Ryan") }
    end

    context "when the resource has no model slug" do
      let(:resource) { "https://jaxslayher.com/members" }

      it { expect { index.actor_name(resource) }.to raise_error(/Unable to extract performer/) }
    end
  end

  describe "#search_by_movie" do
    it "is not supported" do
      expect { index.search_by_movie("https://jaxslayher.com/movies/1") }.to raise_error(NotImplementedError)
    end
  end

  describe "session expiry" do
    subject(:authenticator) { index.send(:authenticator) }

    let(:resource) { "https://jaxslayher.com/members/video/6619f4a3-8ca7-49cc-9f1d-5014e54da6ef" }

    before { allow(authenticator).to receive(:request_cookie).and_return("jaxxx=refreshed-session") }

    it "refreshes the session via the browser on a 401 and retries", :aggregate_failures do
      result = nil
      VCR.use_cassette("jax_slayher/index_session_refresh") do
        result = index.search_by_all_scenes(resource)
      end

      expect(authenticator).to have_received(:request_cookie).with(force_request: true, cookie_key: "jaxxx")
      expect(result.length).to eq(1)
      expect(result.first.title).to eq("That Legendary Ass")
    end

    it "gives up when the refreshed session is still unauthorized" do
      VCR.use_cassette("jax_slayher/index_session_expired", allow_playback_repeats: true) do
        expect { index.search_by_page("https://jaxslayher.com/members/2") }
          .to raise_error(XXXDownload::UnauthorizedError)
      end

      expect(authenticator).to have_received(:request_cookie).once
    end
  end
end
