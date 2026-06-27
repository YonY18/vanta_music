#include "vanta_output.h"

#include <algorithm>
#include <sstream>

#include "vanta_decoder.h"

namespace vanta_audio_engine {
bool VantaOutput::Open(const VantaDecoder& decoder, ma_device_data_proc callback,
                       void* user_data) {
  if (!decoder.IsReady()) {
    lifecycle_status_ = "output=open result=failed reason=decoder-not-ready backend=unknown";
    return false;
  }

  Close();

  ma_device_config device_config = ma_device_config_init(ma_device_type_playback);
  buffer_policy_ = StableMusicOutputBufferPolicy();
  device_config.playback.format = decoder.OutputFormat();
  device_config.playback.channels = decoder.OutputChannels();
  device_config.sampleRate = decoder.SampleRate();
  ApplyOutputBufferPolicy(device_config, buffer_policy_);
  device_config.dataCallback = callback;
  device_config.pUserData = user_data;

  const VantaOutputBackendPreference backend_preference =
      PreferredOutputBackendPreference();
  const std::string backend_order = BackendPreferenceLogName(backend_preference);
  ma_result open_result = MA_ERROR;
  std::ostringstream backend_attempts;
  if (backend_preference.backends == nullptr ||
      backend_preference.backend_count == 0) {
    open_result = ma_device_init_ex(nullptr, 0, nullptr, &device_config, &device_);
  } else {
    for (ma_uint32 i = 0; i < backend_preference.backend_count; ++i) {
      const ma_backend backend = backend_preference.backends[i];
      device_ = ma_device{};
      open_result = ma_device_init_ex(&backend, 1, nullptr, &device_config,
                                      &device_);
      if (backend_attempts.tellp() > 0) {
        backend_attempts << ",";
      }
      backend_attempts << OutputBackendName(backend) << ":" << open_result;
      if (open_result == MA_SUCCESS) {
        break;
      }
    }
  }
  if (open_result != MA_SUCCESS) {
    Close();
    std::ostringstream stream;
    stream << "output=open result=failed code=" << open_result
           << " backend=unknown"
           << " backend_strategy=" << backend_preference.strategy_name
           << " backend_order=" << backend_order
           << " backend_attempts=" << backend_attempts.str();
    lifecycle_status_ = stream.str();
    return false;
  }

  format_ = decoder.OutputFormat();
  channels_ = decoder.OutputChannels();
  sample_rate_ = decoder.SampleRate();
  ready_ = true;
  std::ostringstream stream;
  stream << "output=open result=success backend=" << BackendName()
         << " backend_strategy=" << backend_preference.strategy_name
         << " backend_order=" << backend_order
         << " backend_attempts=" << backend_attempts.str()
         << " sample_rate=" << sample_rate_ << " channels=" << channels_
         << " buffer_policy=stable_music"
         << " period_ms=" << buffer_policy_.period_size_ms
         << " periods=" << buffer_policy_.periods
         << " performance_profile="
         << PerformanceProfileName(buffer_policy_.performance_profile);
  lifecycle_status_ = stream.str();
  return true;
}

bool VantaOutput::IsCompatibleWith(const VantaDecoder& decoder) const {
  return ready_ && decoder.IsReady() &&
         IsReusableOutputConfig(
             VantaOutputConfig{format_, channels_, sample_rate_},
             VantaOutputConfig{decoder.OutputFormat(), decoder.OutputChannels(),
                               decoder.SampleRate()});
}

void VantaOutput::MarkReused() {
  const VantaOutputBackendPreference backend_preference =
      PreferredOutputBackendPreference();
  std::ostringstream stream;
  stream << "output=reused result=success backend=" << BackendName()
         << " backend_strategy=" << backend_preference.strategy_name
         << " backend_order=" << BackendPreferenceLogName(backend_preference)
         << " sample_rate=" << sample_rate_ << " channels=" << channels_
         << " buffer_policy=stable_music"
         << " period_ms=" << buffer_policy_.period_size_ms
         << " periods=" << buffer_policy_.periods
         << " performance_profile="
         << PerformanceProfileName(buffer_policy_.performance_profile);
  lifecycle_status_ = stream.str();
}

bool VantaOutput::Start() {
  if (!ready_) {
    lifecycle_status_ = "output=start result=failed reason=not-ready backend=unknown";
    return false;
  }
  const ma_result start_result = ma_device_start(&device_);
  started_ = start_result == MA_SUCCESS;
  std::ostringstream stream;
  stream << "output=start result="
         << (start_result == MA_SUCCESS ? "success" : "failed")
         << " code=" << start_result << " backend=" << BackendName();
  lifecycle_status_ = stream.str();
  return start_result == MA_SUCCESS;
}

bool VantaOutput::Stop() {
  if (!ready_) {
    lifecycle_status_ = "output=stop result=failed reason=not-ready backend=unknown";
    return false;
  }
  const ma_result stop_result = ma_device_stop(&device_);
  if (stop_result == MA_SUCCESS) {
    started_ = false;
  }
  std::ostringstream stream;
  stream << "output=stop result="
         << (stop_result == MA_SUCCESS ? "success" : "failed")
         << " code=" << stop_result << " backend=" << BackendName();
  lifecycle_status_ = stream.str();
  return stop_result == MA_SUCCESS;
}

bool VantaOutput::SetVolume(float volume) {
  if (!ready_) {
    return false;
  }
  ma_device_set_master_volume(&device_, std::clamp(volume, 0.0f, 1.0f));
  return true;
}

void VantaOutput::Close() {
  if (ready_) {
    std::ostringstream stream;
    stream << "output=close result=success backend=" << BackendName();
    ma_device_uninit(&device_);
    lifecycle_status_ = stream.str();
    ready_ = false;
    started_ = false;
  }
  format_ = ma_format_unknown;
  channels_ = 0;
  sample_rate_ = 0;
}

bool VantaOutput::IsReady() const { return ready_; }

bool VantaOutput::IsStarted() const { return ready_ && started_; }

std::string VantaOutput::LifecycleStatus() const { return lifecycle_status_; }

const char* VantaOutput::BackendName() const {
  if (device_.pContext == nullptr) {
    return "unknown";
  }
  const char* backend_name = ma_get_backend_name(device_.pContext->backend);
  return backend_name == nullptr ? "unknown" : backend_name;
}
}  // namespace vanta_audio_engine
