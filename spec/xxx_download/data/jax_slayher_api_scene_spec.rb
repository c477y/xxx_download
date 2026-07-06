# frozen_string_literal: true

require "rspec"

RSpec.describe XXXDownload::Data::JaxSlayherApiScene do
  subject(:jax_slayher_api_scene) { described_class.new(attributes) }

  let(:attributes) do
    {
      id: 214,
      title: "That Legendary Ass",
      folder: "6619f4a3-8ca7-49cc-9f1d-5014e54da6ef",
      release_date: "2025-12-18T11:59:13Z",
      tags: ["ass", "big ass", "milf"],
      performers: [{ name: "Richelle Ryan" }, { name: "Jax Slayher" }],
      videos: [
        { file_name: "sd_that_legendary_ass.mp4", quality_rank: 3 },
        { file_name: "4k_that_legendary_ass.mp4", quality_rank: 1 },
        { file_name: "hd_that_legendary_ass.mp4", quality_rank: 2 },
        { file_name: "mobile_that_legendary_ass.mp4", quality_rank: 5 }
      ]
    }
  end

  describe "#to_scene" do
    subject(:scene) { jax_slayher_api_scene.to_scene }

    it { expect(scene).to be_a(XXXDownload::Data::Scene) }
    it { expect(scene.video_link).to eq("https://jaxslayher.com/members/video/6619f4a3-8ca7-49cc-9f1d-5014e54da6ef") }
    it { expect(scene.clip_id).to eq(214) }
    it { expect(scene.title).to eq("That Legendary Ass") }
    it { expect(scene.actors.map(&:name)).to match_array(["Richelle Ryan", "Jax Slayher"]) }
    it { expect(scene.actors.map(&:gender)).to all(eq("unknown")) }
    it { expect(scene.network_name).to eq("Jax Slayher") }
    it { expect(scene.collection_tag).to eq("JAX") }
    it { expect(scene.tags).to eq(jax_slayher_api_scene.tags) }
    it { expect(scene.release_date).to eq("2025-12-18") }
    it { expect(scene.lazy).to eq(false) }

    it "orders download_sizes best-first by quality rank" do
      expect(scene.download_sizes).to eq(%w[2160 1080 720 360])
    end

    it "builds resolution-keyed download links from the video file names" do
      base = "https://jaxslayher.com/m_a/dl/6619f4a3-8ca7-49cc-9f1d-5014e54da6ef"
      expect(scene.downloading_links.to_h).to eq(
        res_2160p: "#{base}/4k_that_legendary_ass.mp4",
        res_1080p: "#{base}/hd_that_legendary_ass.mp4",
        res_720p: "#{base}/sd_that_legendary_ass.mp4",
        res_360p: "#{base}/mobile_that_legendary_ass.mp4",
        default: [
          "#{base}/4k_that_legendary_ass.mp4",
          "#{base}/hd_that_legendary_ass.mp4",
          "#{base}/sd_that_legendary_ass.mp4",
          "#{base}/mobile_that_legendary_ass.mp4"
        ]
      )
    end

    it "resolves the configured quality through StreamingLinks", :aggregate_failures do
      base = "https://jaxslayher.com/m_a/dl/6619f4a3-8ca7-49cc-9f1d-5014e54da6ef"
      expect(scene.downloading_links.fhd).to eq("#{base}/hd_that_legendary_ass.mp4")
      expect(scene.downloading_links.hd).to eq("#{base}/sd_that_legendary_ass.mp4")
      expect(scene.downloading_links.sd).to eq("#{base}/mobile_that_legendary_ass.mp4")
    end
  end

  describe "validation" do
    context "when the scene has no videos" do
      before { attributes[:videos] = [] }

      it { expect { jax_slayher_api_scene }.to raise_error(described_class::NoVideosError) }
    end
  end
end
