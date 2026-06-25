#include "vanta_output.h"

#include <algorithm>

#include "vanta_decoder.h"

namespace vanta_audio_engine {
bool VantaOutput::Open(const VantaDecoder& decoder, ma_device_data_proc callback,
                       void* user_data) {
  if (!decoder.IsReady()) {
    return false;
  }

  Close();

  ma_device_config device_config = ma_device_config_init(ma_device_type_playback);
  device_config.playback.format = decoder.OutputFormat();
  device_config.playback.channels = decoder.OutputChannels();
  device_config.sampleRate = decoder.SampleRate();
  device_config.dataCallback = callback;
  device_config.pUserData = user_data;

  if (ma_device_init(nullptr, &device_config, &device_) != MA_SUCCESS) {
    Close();
    return false;
  }

  ready_ = true;
  return true;
}

bool VantaOutput::Start() { return ready_ && ma_device_start(&device_) == MA_SUCCESS; }

bool VantaOutput::Stop() { return ready_ && ma_device_stop(&device_) == MA_SUCCESS; }

bool VantaOutput::SetVolume(float volume) {
  if (!ready_) {
    return false;
  }
  ma_device_set_master_volume(&device_, std::clamp(volume, 0.0f, 1.0f));
  return true;
}

void VantaOutput::Close() {
  if (ready_) {
    ma_device_uninit(&device_);
    ready_ = false;
  }
}

bool VantaOutput::IsReady() const { return ready_; }
}  // namespace vanta_audio_engine
