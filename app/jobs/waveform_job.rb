# Copyright 2011-2018, The Trustees of Indiana University and Northwestern
#   University.  Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed
#   under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
#   CONDITIONS OF ANY KIND, either express or implied. See the License for the
#   specific language governing permissions and limitations under the License.
# ---  END LICENSE_HEADER BLOCK  ---

class WaveformJob < ActiveJob::Base
  PLAYER_WIDTH_IN_PX = 1200
  FINEST_ZOOM_IN_SEC = 5
  SAMPLES_PER_FRAME = (44_100 * FINEST_ZOOM_IN_SEC) / PLAYER_WIDTH_IN_PX

  def perform(master_file_id, regenerate = false)
    master_file = MasterFile.find(master_file_id)
    return if master_file.waveform.content.present? && !regenerate

    service = WaveformService.new(8, SAMPLES_PER_FRAME)
    uri = file_uri(master_file) || playlist_url(master_file)
    json = service.get_waveform_json(uri)
    return unless json.present?

    master_file.waveform.content = json
    master_file.waveform.mime_type = 'application/json'
    master_file.waveform.content_will_change!
    master_file.save
  end

  private

    def file_uri(master_file)
      path = master_file.file_location
      path_usable = path.present? && File.exist?(path)
      path_usable ? path : nil
    end

    def playlist_url(master_file)
      streams = master_file.hls_streams
      hls_url = nil

      # Find the lowest quality stream
      ['high', 'medium', 'low'].each do |quality|
        quality_details = streams.find { |d| d[:quality] == quality }
        hls_url = quality_details[:url] if quality_details.present? && quality_details[:url]
      end

      hls_url.present? ? SecurityHandler.secure_url(hls_url, target: master_file.id) : nil
    end
end
