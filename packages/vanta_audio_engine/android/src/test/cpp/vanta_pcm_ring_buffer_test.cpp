#include <cassert>
#include <atomic>
#include <thread>
#include <vector>

#include "vanta_pcm_ring_buffer.h"

using vanta_audio_engine::VantaPcmRingBuffer;

int main() {
  VantaPcmRingBuffer ring;
  assert(ring.Reset(ma_format_f32, 2, 4));
  assert(ring.CapacityFrames() == 4);
  assert(ring.BufferedFrames() == 0);
  assert(ring.AvailableWriteFrames() == 4);

  const std::vector<float> input{1, 2, 3, 4, 5, 6};
  assert(ring.WriteFrames(input.data(), 3) == 3);
  assert(ring.BufferedFrames() == 3);
  assert(ring.AvailableWriteFrames() == 1);

  std::vector<float> first_read(4, 0);
  assert(ring.ReadFrames(first_read.data(), 2) == 2);
  assert(first_read[0] == 1);
  assert(first_read[1] == 2);
  assert(first_read[2] == 3);
  assert(first_read[3] == 4);

  const std::vector<float> wrapped_input{7, 8, 9, 10, 11, 12};
  assert(ring.WriteFrames(wrapped_input.data(), 3) == 3);
  assert(ring.BufferedFrames() == 4);

  std::vector<float> final_read(8, 0);
  assert(ring.ReadFrames(final_read.data(), 4) == 4);
  assert(final_read[0] == 5);
  assert(final_read[1] == 6);
  assert(final_read[2] == 7);
  assert(final_read[3] == 8);
  assert(final_read[4] == 9);
  assert(final_read[5] == 10);
  assert(final_read[6] == 11);
  assert(final_read[7] == 12);
  assert(ring.BufferedFrames() == 0);

  std::vector<float> underrun(4, -1);
  assert(ring.ReadFrames(underrun.data(), 2) == 0);
  assert(underrun[0] == -1);
  assert(underrun[1] == -1);

  assert(ring.WriteFrames(input.data(), 3) == 3);
  assert(ring.WriteFrames(wrapped_input.data(), 3) == 1);
  assert(ring.BufferedFrames() == 4);

  VantaPcmRingBuffer spsc_ring;
  assert(spsc_ring.Reset(ma_format_s16, 1, 128));
  constexpr int frames = 4096;
  std::atomic<bool> writer_done{false};
  std::vector<int16_t> received;
  received.reserve(frames);

  std::thread writer([&] {
    for (int16_t frame = 0; frame < frames;) {
      const int16_t value = frame;
      if (spsc_ring.WriteFrames(&value, 1) == 1) {
        ++frame;
      } else {
        std::this_thread::yield();
      }
    }
    writer_done.store(true);
  });

  std::thread reader([&] {
    while (!writer_done.load() || spsc_ring.BufferedFrames() > 0) {
      int16_t value = -1;
      if (spsc_ring.ReadFrames(&value, 1) == 1) {
        received.push_back(value);
      } else {
        std::this_thread::yield();
      }
    }
  });

  writer.join();
  reader.join();
  assert(received.size() == frames);
  for (int frame = 0; frame < frames; ++frame) {
    assert(received[static_cast<size_t>(frame)] == frame);
  }

  return 0;
}
