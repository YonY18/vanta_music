#pragma once

#include "miniaudio.h"

namespace vanta_audio_engine {
class VantaDecoder;

class VantaOutput {
 public:
  bool Open(const VantaDecoder& decoder, ma_device_data_proc callback, void* user_data);
  bool Start();
  bool Stop();
  bool SetVolume(float volume);
  void Close();
  bool IsReady() const;

 private:
  ma_device device_{};
  bool ready_ = false;
};
}  // namespace vanta_audio_engine
